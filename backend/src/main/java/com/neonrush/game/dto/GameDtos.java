package com.neonrush.game.dto;

import jakarta.validation.constraints.*;

/**
 * GameDtos — DTOs for game session and score submission.
 */
public final class GameDtos {

    private GameDtos() {}

    /**
     * Run submission payload sent by the game client after a run ends.
     */
    public record RunSubmitRequest(
            @NotNull(message = "score is required")
            @Min(value = 0, message = "score must be non-negative")
            @Max(value = 99_999_999, message = "score exceeds maximum")
            Integer score,

            @NotNull(message = "distance is required")
            @DecimalMin(value = "0.0", message = "distance must be non-negative")
            @DecimalMax(value = "999999.9", message = "distance exceeds maximum")
            Double distance,

            @NotNull(message = "coins is required")
            @Min(value = 0, message = "coins must be non-negative")
            @Max(value = 99_999, message = "coins exceed maximum per run")
            Integer coins,

            @NotNull(message = "duration is required")
            @DecimalMin(value = "0.0", message = "duration must be non-negative")
            Double duration,

            @NotBlank(message = "hash is required")
            @Size(max = 128, message = "hash too long")
            String hash,

            @NotNull(message = "clientTs is required")
            Long clientTs
    ) {}

    /**
     * Response after a successful run submission.
     */
    public record RunSubmitResponse(
            String runId,
            int score,
            boolean isHighScore,
            int previousHighScore,
            int coinsAwarded,
            AntiCheatResult antiCheat
    ) {}

    /**
     * Anti-cheat validation summary (returned to client for transparency).
     */
    public record AntiCheatResult(
            boolean passed,
            String verdict   // "CLEAN", "SUSPICIOUS", "FLAGGED"
    ) {}

    /**
     * Leaderboard entry.
     */
    public record LeaderboardEntry(
            int rank,
            String playerId,
            String username,
            int score,
            double distance,
            String achievedAt
    ) {}

    /**
     * Leaderboard response.
     */
    public record LeaderboardResponse(
            java.util.List<LeaderboardEntry> entries,
            int total
    ) {}
}
