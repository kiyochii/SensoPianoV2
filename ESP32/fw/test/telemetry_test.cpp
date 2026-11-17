#include "telemetry.h"
#include <assert.h>
#include <iostream>
#include <string>
#include <stdio.h>

static void send(senso::Telemetry& t, const std::string& s) {
    t.receiveMetrics(reinterpret_cast<const uint8_t*>(s.data()), s.size(), 100);
}
static std::string observation(uint32_t seq, uint32_t ms, uint32_t session,
        unsigned keys, unsigned mode, unsigned state, unsigned flags = 0, unsigned dropped = 0) {
    char prefix[80];
    snprintf(prefix, sizeof(prefix), "T,1,%08X,%08X,%08X,%03X,%X,%X,30,%02X,%08X,",
        seq, ms, session, keys, mode, state, flags, dropped);
    uint8_t checksum = 0;
    for (const char* p = prefix; *p; ++p) checksum ^= *p;
    char tail[8];
    snprintf(tail, sizeof(tail), "%02X\r\n", checksum);
    return std::string(prefix) + tail;
}
static void activityTests() {
    const std::string frame = observation(1, 0, 0, 0, 0, 0, 8);
    assert(frame.size() == 58);
    // Every possible split, then byte-at-a-time, mixed with legacy M lines.
    for (size_t cut = 0; cut < frame.size(); ++cut) {
        senso::Telemetry t;
        send(t, frame.substr(0, cut));
        assert(!t.activity.latest.available);
        send(t, frame.substr(cut));
        assert(t.activity.latest.available && t.activity.latest.sequence == 1);
    }
    senso::Telemetry t;
    for (char c : frame) send(t, std::string(1, c));
    send(t, "M,00001,00000,00001,0\r\n");
    assert(t.metrics.correct == 1);
    send(t, observation(2, 100, 0, 1, 0, 0));
    send(t, observation(3, 150, 0, 3, 0, 0));
    send(t, observation(4, 250, 0, 0, 0, 0));
    send(t, observation(5, 400, 0, 4, 0, 0));
    send(t, observation(6, 450, 0, 0, 0, 0));
    const auto free = t.activity.stats;
    assert(free.presses == 3 && free.chords == 1);
    assert(free.perKey[0] == 1 && free.perKey[1] == 1 && free.perKey[2] == 1);
    assert(free.hold.count == 3 && free.hold.mean == 100 && free.hold.minimum == 50 && free.hold.maximum == 150);
    assert(free.interval.count == 2 && free.interval.mean == 150 && free.interval.deviation() == 100);
    assert(free.activeMs == 200 && free.elapsedMs == 450);
    assert(t.activity.latest.released == 4 && t.activity.latest.pressed == 0);
    send(t, observation(7, 500, 0, 0, 1, 1));
    send(t, observation(8, 600, 1, 0, 1, 1, 1));
    send(t, observation(9, 610, 1, 0, 1, 2));
    send(t, observation(10, 611, 1, 0, 1, 3));
    send(t, observation(11, 900, 1, 0x200, 1, 3));
    send(t, observation(12, 900, 1, 0x200, 1, 4, 4));
    send(t, observation(13, 901, 1, 0x200, 1, 3));
    send(t, observation(14, 950, 1, 0, 1, 3));
    send(t, observation(15, 1200, 1, 1, 1, 3));
    send(t, observation(16, 1200, 1, 1, 1, 4, 2));
    send(t, observation(17, 1201, 1, 1, 1, 2));
    send(t, observation(18, 1202, 1, 0, 1, 3));
    send(t, observation(19, 1500, 1, 4, 1, 3));
    send(t, observation(20, 1500, 1, 4, 1, 4, 2));
    send(t, observation(21, 1501, 1, 4, 1, 5));
    auto learned = t.activity.stats;
    assert(learned.presses == 3 && learned.streak == 2 && learned.bestStreak == 2);
    assert(learned.response.count == 2 && learned.response.mean == 294.5);
    assert(learned.solve.count == 2 && learned.solve.mean == 444.5);
    assert(learned.finished && learned.elapsedMs == 901 && !learned.incomplete);
    // Heartbeat must not repeat a hold/onset or extend the completed activity.
    send(t, observation(22, 2500, 1, 4, 1, 5, 16));
    assert(t.activity.stats.elapsedMs == 901 && t.activity.stats.presses == 3);
    // Missing a release invalidates pending durations; subsequent observations recover.
    send(t, observation(24, 2600, 1, 0, 1, 5, 0, 1));
    assert(t.activity.missing == 1 && t.activity.stats.incomplete);
    assert(t.activity.stats.streak == 0);
    assert(t.activity.stats.hold.count == 2);
    assert(!t.activity.latest.continuous && !t.activity.latest.released);
    send(t, observation(25, 2650, 1, 2, 1, 5));
    send(t, observation(26, 2670, 1, 0, 1, 5));
    assert(t.activity.stats.presses == 3 && t.activity.stats.hold.count == 2);
    // Bad checksum/version/format do not change the accepted snapshot.
    auto corrupt = observation(27, 2700, 1, 1, 1, 5);
    corrupt[31] = '1'; send(t, corrupt);
    corrupt = observation(27, 2700, 1, 1, 1, 5); corrupt[2] = '2'; send(t, corrupt);
    send(t, "T,1,broken" + observation(27, 2700, 1, 0, 1, 5));
    assert(t.invalidLines == 3 && t.activity.latest.sequence == 27);
    // FPGA-only reset clears stale totals and starts a new epoch, even if ESP stays on.
    send(t, observation(1, 0, 0, 1, 0, 0, 8));
    assert(t.activity.latest.epoch == 2 && !t.metrics.available);
    send(t, observation(2, 100, 0, 0, 0, 0));
    assert(t.activity.stats.hold.count == 0); // held before baseline: unknown onset
    // Millisecond and event counters wrap modulo 32 bits without fake resets.
    senso::Telemetry wrap;
    send(wrap, observation(0xfffffffe, 0xffffffe0, 0, 0, 0, 0));
    send(wrap, observation(0xffffffff, 0xfffffff0, 0, 1, 0, 0));
    send(wrap, observation(0, 0x10, 0, 0, 0, 0));
    assert(wrap.activity.latest.epoch == 1 && wrap.activity.missing == 0);
    assert(wrap.activity.stats.hold.mean == 32);
    // Lost cue/attempt must not produce a fabricated response measurement.
    senso::Telemetry loss;
    send(loss, observation(1, 0, 1, 0, 1, 2, 8));
    send(loss, observation(3, 500, 1, 1, 1, 4, 2));
    assert(loss.activity.stats.response.count == 0 && loss.activity.stats.solve.count == 0);
}
int main() {
    activityTests();
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
    std::cout << "PASS: notas, metricas, tempos FPGA, teclas fisicas, perdas, checksum, fragmentacao, reset, wrap e historico\n";
}
