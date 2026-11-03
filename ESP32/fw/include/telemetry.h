#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>

namespace senso {
struct Metrics {
    uint16_t correct = 0, wrong = 0, attempts = 0;
    bool done = false, available = false;
};
struct Note {
    uint8_t raw = 0, pitch = 0, octave = 0;
    bool available = false;
};
enum class Kind : uint8_t { Note, Metrics, Raw };
struct Event {
    uint32_t id = 0, ms = 0;
    Kind kind = Kind::Raw;
    uint8_t source = 0, length = 0;
    uint8_t raw[32] = {};
    Metrics metrics;
    Note note;
};
// Caller synchronizes accesses when used from multiple FreeRTOS tasks.
class Telemetry {
public:
    static constexpr size_t capacity = 128;
    Metrics metrics;
    Note note;
    uint32_t sequence = 0, noteBytes = 0, metricsBytes = 0;
    uint32_t invalidNotes = 0, invalidLines = 0, uartErrors = 0;

    uint32_t oldest() const { return sequence >= capacity ? sequence - capacity + 1 : 1; }
    const Event& get(uint32_t id) const { return events_[(id - 1) % capacity]; }

    void receiveNotes(const uint8_t* data, size_t length, uint32_t ms) {
        for (size_t i = 0; i < length; ++i) {
            ++noteBytes;
            Event event;
            event.ms = ms;
            event.raw[0] = data[i];
            event.length = 1;
            if (!(data[i] & 0x80) && (data[i] & 15) < 12) {
                note.raw = data[i];
                note.pitch = data[i] & 15;
                note.octave = (data[i] >> 4) & 7;
                note.available = true;
                event.kind = Kind::Note;
                event.note = note;
            } else {
                ++invalidNotes;
            }
            push(event);
        }
    }
    void receiveMetrics(const uint8_t* data, size_t length, uint32_t ms) {
        // Preserve every received byte, including partial/invalid frames.
        for (size_t offset = 0; offset < length;) {
            Event raw;
            raw.source = 1;
            raw.ms = ms;
            raw.length = static_cast<uint8_t>(length - offset > 32 ? 32 : length - offset);
            memcpy(raw.raw, data + offset, raw.length);
            push(raw);
            for (size_t i = 0; i < raw.length; ++i) parse(data[offset + i], ms);
            offset += raw.length;
            metricsBytes += raw.length;
        }
    }
private:
    Event events_[capacity];
    char line_[23] = {};
    size_t used_ = 0;
    bool discarding_ = false;
    void push(Event event) {
        event.id = ++sequence;
        events_[(sequence - 1) % capacity] = event;
    }
    bool decode(Metrics& result) const {
        if (used_ != 23 || line_[0] != 'M' || line_[1] != ',' ||
            line_[7] != ',' || line_[13] != ',' || line_[19] != ',' ||
            (line_[20] != '0' && line_[20] != '1') ||
            line_[21] != '\r' || line_[22] != '\n') return false;
        uint16_t* fields[] = {&result.correct, &result.wrong, &result.attempts};
        for (size_t f = 0; f < 3; ++f) {
            uint32_t value = 0;
            for (size_t p = 2 + f * 6; p < 7 + f * 6; ++p) {
                if (line_[p] < '0' || line_[p] > '9') return false;
                value = value * 10 + line_[p] - '0';
            }
            if (value > 65535) return false;
            *fields[f] = static_cast<uint16_t>(value);
        }
        if (static_cast<uint32_t>(result.correct) + result.wrong != result.attempts) return false;
        result.done = line_[20] == '1';
        result.available = true;
        return true;
    }
    void parse(uint8_t byte, uint32_t ms) {
        if (byte == 'M') {
            if (used_ || discarding_) ++invalidLines;
            used_ = 0;
            discarding_ = false;
        }
        if (used_ < sizeof(line_)) line_[used_++] = static_cast<char>(byte);
        else discarding_ = true;
        if (byte != '\n') return;
        Metrics decoded;
        if (!discarding_ && decode(decoded)) {
            metrics = decoded;
            Event event;
            event.kind = Kind::Metrics;
            event.source = 1;
            event.ms = ms;
            event.metrics = metrics;
            push(event);
        } else ++invalidLines;
        used_ = 0;
        discarding_ = false;
    }
};
}
