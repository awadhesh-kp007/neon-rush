package com.neonrush.game.service;

import com.neonrush.game.dto.GameDtos.*;
import com.neonrush.shared.exception.NeonRushException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.Instant;

/**
 * ScoreValidationService — server-side anti-cheat for run submissions.
 *
 * <p>Validates that submitted scores are physically possible given:
 * <ul>
 *   <li>Speed bounds (min/max metres per second)</li>
 *   <li>Coin-to-distance density</li>
 *   <li>Score-to-distance ratio</li>
 *   <li>Client timestamp drift</li>
 * </ul>
 *
 * <p>Flagged runs are stored but not shown on leaderboard until human review.
 */
@Slf4j
@Service
public class ScoreValidationService {

    @Value("${neon-rush.anti-cheat.max-speed-mps:35.0}")
    private double maxSpeedMps;                     // m/s at peak difficulty

    @Value("${neon-rush.anti-cheat.min-speed-mps:9.5}")
    private double minSpeedMps;                     // m/s at run start

    @Value("${neon-rush.anti-cheat.max-coins-per-meter:1.5}")
    private double maxCoinsPerMeter;                // density limit

    @Value("${neon-rush.anti-cheat.max-score-per-meter:150.0}")
    private double maxScorePerMeter;                // score density limit

    @Value("${neon-rush.anti-cheat.max-clock-drift-seconds:300}")
    private long maxClockDriftSeconds;              // 5-minute tolerance

    // ─────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────

    /**
     * Validates a run submission. Returns {@link AntiCheatResult}.
     * Never throws — a suspicious run is flagged, not rejected outright.
     *
     * @param request the run payload
     * @return {@link AntiCheatResult} with verdict
     */
    public AntiCheatResult validate(RunSubmitRequest request) {
        int flags = 0;

        // ── 1. Clock drift check ──────────────────────────────────
        long serverNow = Instant.now().getEpochSecond();
        long drift = Math.abs(serverNow - request.clientTs());
        if (drift > maxClockDriftSeconds) {
            log.warn("Anti-cheat: clock drift {}s for run with score={}", drift, request.score());
            flags++;
        }

        // ── 2. Duration sanity ────────────────────────────────────
        if (request.duration() <= 0.5) {
            log.warn("Anti-cheat: impossibly short duration {}s", request.duration());
            flags += 2;  // hard flag
        }

        // ── 3. Speed plausibility ─────────────────────────────────
        double avgSpeed = request.distance() / Math.max(request.duration(), 0.001);
        if (avgSpeed > maxSpeedMps) {
            log.warn("Anti-cheat: avg speed {:.2f} m/s exceeds max {}", avgSpeed, maxSpeedMps);
            flags++;
        }
        if (avgSpeed < minSpeedMps && request.distance() > 100) {
            log.warn("Anti-cheat: avg speed {:.2f} m/s below min {} (distance={})", avgSpeed, minSpeedMps, request.distance());
            flags++;
        }

        // ── 4. Coin density ───────────────────────────────────────
        if (request.distance() > 0) {
            double coinDensity = request.coins() / request.distance();
            if (coinDensity > maxCoinsPerMeter) {
                log.warn("Anti-cheat: coin density {:.3f}/m exceeds max {}", coinDensity, maxCoinsPerMeter);
                flags++;
            }
        }

        // ── 5. Score density ──────────────────────────────────────
        if (request.distance() > 0) {
            double scoreDensity = request.score() / request.distance();
            if (scoreDensity > maxScorePerMeter) {
                log.warn("Anti-cheat: score density {:.1f}/m exceeds max {}", scoreDensity, maxScorePerMeter);
                flags++;
            }
        }

        // ── Verdict ───────────────────────────────────────────────
        if (flags == 0) {
            return new AntiCheatResult(true, "CLEAN");
        } else if (flags <= 1) {
            return new AntiCheatResult(true, "SUSPICIOUS");   // Allow but flag for review
        } else {
            log.warn("Anti-cheat: run FLAGGED with {} violations (score={})", flags, request.score());
            return new AntiCheatResult(false, "FLAGGED");
        }
    }

    /**
     * Throws {@link NeonRushException} if the result is FLAGGED (hard reject).
     *
     * @param result anti-cheat result
     */
    public void enforceHardReject(AntiCheatResult result) {
        if ("FLAGGED".equals(result.verdict())) {
            throw new NeonRushException(HttpStatus.UNPROCESSABLE_ENTITY,
                    "Run rejected: score data failed validation.");
        }
    }
}
