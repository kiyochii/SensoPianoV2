#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "activity.h"

namespace senso {
struct Metrics {
    uint16_t correct = 0, wrong = 0, attempts = 0;
    bool done = false, available = false;
};
struct Note {
    uint8_t raw = 0, pitch = 0, octave = 0;
    bool available = false;
};
enum class Kind : uint8_t { Note, Metrics, Raw, Activity };
struct Event {
    uint32_t id = 0, ms = 0;
    Kind kind = Kind::Raw;
    uint8_t source = 0, length = 0;
    uint8_t raw[32] = {};
    Metrics metrics;
    Note note;
    Activity activity;
};
// Caller synchronizes accesses when used from multiple FreeRTOS tasks.
class Telemetry {
public:
    static constexpr size_t capacity = 128;
    Metrics metrics;
    Note note;
    ActivityTracker activity;
    uint32_t activityReceivedMs = 0;
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
    char line_[58] = {};
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
    bool hexField(size_t offset, size_t length, uint32_t& value) const {
        value = 0;
        for (size_t i = offset; i < offset + length; ++i) {
            const char c = line_[i];
            if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F'))) return false;
            value = (value << 4) | (c <= '9' ? c - '0' : c - 'A' + 10);
        }
        return true;
    }
    bool decodeActivity(Activity& result) const {
        if (used_ != 58 || line_[0] != 'T' || line_[2] != '1' ||
            line_[56] != '\r' || line_[57] != '\n') return false;
        const size_t commas[] = {1,3,12,21,30,34,36,38,41,44,53};
        for (size_t offset : commas) if (line_[offset] != ',') return false;
        uint32_t values[10];
        const size_t offsets[] = {4,13,22,31,35,37,39,42,45,54};
        const size_t lengths[] = {8,8,8,3,1,1,2,2,8,2};
        for (size_t i = 0; i < 10; ++i) if (!hexField(offsets[i], lengths[i], values[i])) return false;
        uint8_t checksum = 0;
        for (size_t i = 0; i < 54; ++i) checksum ^= static_cast<uint8_t>(line_[i]);
        if (checksum != values[9] || values[4] > 1 || values[5] > 5 ||
            values[6] > 0x7b || (values[6] & 15) > 11 || values[7] > 31 ||
            (values[7] & 6) == 6) return false;
        result.sequence = values[0]; result.fpgaMs = values[1]; result.session = values[2];
        result.keys = values[3]; result.mode = values[4]; result.state = values[5];
        result.expected = values[6]; result.flags = values[7]; result.dropped = values[8];
        return true;
    }
    void parse(uint8_t byte, uint32_t ms) {
        if (byte == 'M' || byte == 'T') {
            if (used_ || discarding_) ++invalidLines;
            used_ = 0;
            discarding_ = false;
        }
        if (used_ < sizeof(line_)) line_[used_++] = static_cast<char>(byte);
        else discarding_ = true;
        if (byte != '\n') return;
        Metrics decoded;
        Activity observed;
        if (!discarding_ && decode(decoded)) {
            metrics = decoded;
            Event event;
            event.kind = Kind::Metrics;
            event.source = 1;
            event.ms = ms;
            event.metrics = metrics;
            push(event);
        } else if (!discarding_ && decodeActivity(observed)) {
            const uint32_t oldEpoch = activity.latest.epoch;
            if (activity.receive(observed)) {
                activityReceivedMs = ms;
                if (oldEpoch && oldEpoch != activity.latest.epoch) {
                    metrics = Metrics{};
                    note = Note{};
                }
                Event event;
                event.kind = Kind::Activity;
                event.source = 1;
                event.ms = ms;
                event.activity = activity.latest;
                push(event);
            }
        } else ++invalidLines;
        used_ = 0;
        discarding_ = false;
    }
};
}
