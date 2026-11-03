#include "telemetry.h"
#include <assert.h>
#include <iostream>
#include <string>

static void send(senso::Telemetry& t, const std::string& s) {
    t.receiveMetrics(reinterpret_cast<const uint8_t*>(s.data()), s.size(), 100);
}
int main() {
    senso::Telemetry t;
    assert(!t.metrics.available && !t.note.available && t.sequence == 0);
    // All legal note/octave combinations, including bytes equal to ASCII delimiters.
    for (int octave = 0; octave < 8; ++octave) {
        for (int pitch = 0; pitch < 12; ++pitch) {
            uint8_t b = (octave << 4) | pitch;
            t.receiveNotes(&b, 1, 1);
            assert(t.note.available && t.note.pitch == pitch && t.note.octave == octave);
        }
    }
    const uint8_t invalid[] = {0x0C, 0x7F, 0x80, 0xFF};
    t.receiveNotes(invalid, sizeof(invalid), 2);
    assert(t.invalidNotes == 4 && t.note.raw == 0x7B);
    assert(t.get(t.sequence).raw[0] == 0xFF);
    // Arbitrary fragmentation: no metrics before the complete CRLF frame.
    const std::string frame = "M,00001,00002,00003,0\r\n";
    for (size_t i = 0; i < frame.size(); ++i) {
        send(t, frame.substr(i, 1));
        assert(t.metrics.available == (i == frame.size() - 1));
    }
    assert(t.metrics.correct == 1 && t.metrics.wrong == 2 && t.metrics.attempts == 3);
    send(t, "M,00006,00001,00007,1\r\nM,00000,00000,00000,0\r\n");
    assert(t.metrics.attempts == 0 && !t.metrics.done);
    // Reset halfway through a frame, noise, oversize frames and invalid counters.
    send(t, "M,0000M,00006,00001,00007,1\r\n");
    assert(t.metrics.done && t.invalidLines == 1);
    send(t, std::string(200, 'x') + "\n");
    send(t, "M,99999,00000,99999,0\r\n");
    send(t, "M,00001,00002,00004,0\r\n");
    send(t, "M,00001,00002,00003,2\r\n");
    send(t, "M,00001,00002,00003,0\n");
    assert(t.invalidLines == 6 && t.metrics.done);
    send(t, "M,32768,32767,65535,1\r\n");
    assert(t.metrics.attempts == 65535);
    // Every raw metrics byte is available in ordered chunks before decoding.
    senso::Telemetry raw;
    send(raw, frame);
    assert(raw.sequence == 2 && raw.get(1).length == frame.size());
    assert(memcmp(raw.get(1).raw, frame.data(), frame.size()) == 0);
    assert(raw.get(2).kind == senso::Kind::Metrics);
    // Bounded history retains the newest complete events with monotonic IDs.
    for (int i = 0; i < 300; ++i) {
        uint8_t b = 0x30;
        raw.receiveNotes(&b, 1, 7);
    }
    assert(raw.oldest() == raw.sequence - senso::Telemetry::capacity + 1);
    for (uint32_t id = raw.oldest(); id <= raw.sequence; ++id) assert(raw.get(id).id == id);
    std::cout << "PASS: notas, metricas, fragmentacao, ressincronizacao, bytes brutos e historico\n";
}
