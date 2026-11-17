#pragma once
#include <stdint.h>
#include <math.h>

namespace senso {
struct Activity {
    uint32_t sequence = 0, fpgaMs = 0, session = 0, dropped = 0, epoch = 0;
    uint16_t keys = 0, pressed = 0, released = 0;
    uint8_t mode = 0, state = 0, expected = 0, flags = 0;
    bool available = false, continuous = false;
};
struct Timing {
    uint32_t count = 0, minimum = 0, maximum = 0;
    double mean = 0, m2 = 0;
    void add(uint32_t ms) {
        if (!count || ms < minimum) minimum = ms;
        if (!count || ms > maximum) maximum = ms;
        ++count;
        const double delta = ms - mean;
        mean += delta / count;
        m2 += delta * (ms - mean);
    }
    double deviation() const { return count ? sqrt(m2 / count) : 0; }
};
struct Performance {
    uint32_t presses = 0, chords = 0, streak = 0, bestStreak = 0;
    uint32_t startedMs = 0, elapsedMs = 0, activeMs = 0, perKey[12] = {};
    Timing hold, interval, response, solve;
    bool incomplete = false, finished = false;
};
// Timings use FPGA timestamps only; never network/ESP arrival time.
// A missing observation breaks all pending measurements, avoiding invented holds.
class ActivityTracker {
public:
    Activity latest;
    Performance stats;
    uint32_t missing = 0;

    bool receive(Activity value) {
        const bool first = !latest.available;
        const uint32_t step = value.sequence - latest.sequence;
        const bool restarted = !first && ((value.flags & 8) || static_cast<int32_t>(step) < 0 ||
            static_cast<int32_t>(value.fpgaMs - latest.fpgaMs) < 0);
        if (!first && !restarted && step == 0) return false;
        const bool gap = !first && !restarted && step != 1;
        if (gap) missing += step - 1;
        value.epoch = first ? 1 : latest.epoch + (restarted ? 1 : 0);
        value.available = true;
        value.continuous = !first && !restarted && !gap;
        const bool segment = first || restarted || value.mode != latest.mode || value.session != latest.session;
        if (segment) {
            stats = Performance{};
            started_ = value.fpgaMs;
            stats.startedMs = started_;
            tracked_ = 0;
            havePress_ = haveCue_ = false;
            stats.incomplete = !(value.flags & (1 | 8)) && value.mode != 0;
            if (first && value.sequence != 1) stats.incomplete = true;
        }
        if (gap) {
            stats.incomplete = true;
            stats.streak = 0;
            tracked_ = 0;
            havePress_ = haveCue_ = false;
        }
        if (value.continuous && !segment) {
            value.pressed = value.keys & ~latest.keys;
            value.released = latest.keys & ~value.keys;
            if (!stats.finished && latest.keys) stats.activeMs += value.fpgaMs - latest.fpgaMs;
            const bool wasChord = (latest.keys & (latest.keys - 1)) != 0;
            const bool isChord = (value.keys & (value.keys - 1)) != 0;
            if (!stats.finished && isChord && !wasChord) ++stats.chords;
            if (!stats.finished && value.pressed) {
                // Simultaneous presses form one onset for rhythm, one press per key.
                if (havePress_) stats.interval.add(value.fpgaMs - lastPress_);
                lastPress_ = value.fpgaMs;
                havePress_ = true;
            }
            for (unsigned i = 0; i < 12; ++i) {
                const uint16_t bit = 1u << i;
                if (!stats.finished && (value.pressed & bit)) {
                    ++stats.presses; ++stats.perKey[i];
                    downAt_[i] = value.fpgaMs;
                    tracked_ |= bit;
                }
                if (value.released & bit) {
                    if (tracked_ & bit) stats.hold.add(value.fpgaMs - downAt_[i]);
                    tracked_ &= ~bit;
                }
            }
        }
        // SHOW (2) starts a guide. CHECK (4) reports an accepted attempt.
        // Response = first accepted attempt; solve = guide to correct answer,
        // including any wrong attempts. No musical tempo is assumed.
        if (value.mode && value.state == 2 &&
            (segment || !value.continuous || latest.state != 2)) {
            cueAt_ = value.fpgaMs; haveCue_ = true; firstResponse_ = true;
        }
        if (value.mode && (value.flags & (2 | 4))) {
            if (haveCue_) {
                if (firstResponse_) { stats.response.add(value.fpgaMs - cueAt_); firstResponse_ = false; }
                if (value.flags & 2) { stats.solve.add(value.fpgaMs - cueAt_); haveCue_ = false; }
            }
            if (value.flags & 2) {
                ++stats.streak;
                if (stats.streak > stats.bestStreak) stats.bestStreak = stats.streak;
            } else stats.streak = 0;
        }
        if (!stats.finished) stats.elapsedMs = value.fpgaMs - started_;
        if (value.mode && value.state == 5) stats.finished = true;
        latest = value;
        return true;
    }
private:
    uint32_t started_ = 0, lastPress_ = 0, cueAt_ = 0, downAt_[12] = {};
    uint16_t tracked_ = 0;
    bool havePress_ = false, haveCue_ = false, firstResponse_ = false;
};
}
