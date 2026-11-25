package com.neonrush.game.controller;

import com.neonrush.game.dto.GameDtos.*;
import com.neonrush.game.service.ScoreValidationService;
import com.neonrush.shared.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * GameController — handles run score submissions and leaderboard queries.
 *
 * <p>All write endpoints require authentication.
 * Leaderboard GET is public.
 */
@Tag(name = "Game", description = "Run submission and leaderboard")
@Slf4j
@RestController
@RequestMapping("/v1/game")
@RequiredArgsConstructor
public class GameController {

    private final ScoreValidationService scoreValidationService;

    // ─────────────────────────────────────────────────────────────
    // Run Submission
    // ─────────────────────────────────────────────────────────────

    /**
     * Submits a completed run for validation and leaderboard recording.
     *
     * @param playerId  authenticated player UUID (from JWT)
     * @param request   run data payload
     * @return run result with anti-cheat verdict
     */
    @Operation(summary = "Submit a completed run", security = @SecurityRequirement(name = "bearerAuth"))
    @PostMapping("/runs")
    public ResponseEntity<ApiResponse<RunSubmitResponse>> submitRun(
            @AuthenticationPrincipal UUID playerId,
            @Valid @RequestBody RunSubmitRequest request) {

        log.info("Run submission: playerId={} score={} distance={}m duration={}s",
                playerId, request.score(), request.distance(), request.duration());

        // Anti-cheat validation
        AntiCheatResult antiCheat = scoreValidationService.validate(request);
        scoreValidationService.enforceHardReject(antiCheat);

        // TODO: Persist run to DB via GameRunRepository (Phase 2)
        String runId = UUID.randomUUID().toString();
        boolean isHighScore = false;        // TODO: compare with player's stored best
        int previousBest = 0;              // TODO: load from player_stats

        var response = new RunSubmitResponse(
                runId,
                request.score(),
                isHighScore,
                previousBest,
                request.coins(),
                antiCheat
        );

        return ResponseEntity.ok(ApiResponse.success("Run recorded.", response));
    }

    // ─────────────────────────────────────────────────────────────
    // Leaderboard
    // ─────────────────────────────────────────────────────────────

    /**
     * Returns the global all-time leaderboard (public).
     *
     * @param limit max entries (default 100, max 500)
     * @return leaderboard entries
     */
    @Operation(summary = "Get global leaderboard (public)")
    @GetMapping("/leaderboard")
    public ResponseEntity<ApiResponse<LeaderboardResponse>> getLeaderboard(
            @RequestParam(defaultValue = "100") int limit) {

        limit = Math.min(limit, 500);

        // TODO: Load from leaderboard table via LeaderboardRepository (Phase 2)
        List<LeaderboardEntry> entries = new ArrayList<>();

        return ResponseEntity.ok(ApiResponse.success(new LeaderboardResponse(entries, 0)));
    }

    /**
     * Returns the weekly leaderboard (public).
     */
    @Operation(summary = "Get weekly leaderboard (public)")
    @GetMapping("/leaderboard/weekly")
    public ResponseEntity<ApiResponse<LeaderboardResponse>> getWeeklyLeaderboard(
            @RequestParam(defaultValue = "100") int limit) {

        limit = Math.min(limit, 500);
        // TODO: filter by week in LeaderboardRepository
        List<LeaderboardEntry> entries = new ArrayList<>();
        return ResponseEntity.ok(ApiResponse.success(new LeaderboardResponse(entries, 0)));
    }

    /**
     * Returns the authenticated player's personal best runs.
     */
    @Operation(summary = "Get personal run history", security = @SecurityRequirement(name = "bearerAuth"))
    @GetMapping("/runs/me")
    public ResponseEntity<ApiResponse<List<RunSubmitResponse>>> getMyRuns(
            @AuthenticationPrincipal UUID playerId,
            @RequestParam(defaultValue = "20") int limit) {

        // TODO: query game_runs table filtered by player_id
        return ResponseEntity.ok(ApiResponse.success(List.of()));
    }
}
