package com.neonrush.auth.controller;

import com.neonrush.auth.dto.AuthDtos.*;
import com.neonrush.auth.service.AuthService;
import com.neonrush.auth.security.JwtService;
import com.neonrush.shared.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * AuthController — handles player registration, login, logout, and token refresh.
 *
 * <p>All endpoints under {@code /v1/auth/} except {@code /logout} are public.
 */
@Tag(name = "Auth", description = "Player authentication and token management")
@RestController
@RequestMapping("/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final JwtService jwtService;

    // ─────────────────────────────────────────────────────────────
    // Register
    // ─────────────────────────────────────────────────────────────

    /**
     * Creates a new player account.
     *
     * @param request validated registration payload
     * @return 201 Created with tokens and player summary
     */
    @Operation(summary = "Register a new player account")
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(
            @Valid @RequestBody RegisterRequest request) {

        AuthResponse auth = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(auth));
    }

    // ─────────────────────────────────────────────────────────────
    // Login
    // ─────────────────────────────────────────────────────────────

    /**
     * Authenticates a player with email and password.
     *
     * @param request login payload
     * @return 200 OK with tokens and player summary
     */
    @Operation(summary = "Login with email and password")
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(
            @Valid @RequestBody LoginRequest request) {

        AuthResponse auth = authService.login(request);
        return ResponseEntity.ok(ApiResponse.success(auth));
    }

    // ─────────────────────────────────────────────────────────────
    // Token Refresh
    // ─────────────────────────────────────────────────────────────

    /**
     * Issues a new access token from a valid refresh token.
     *
     * @param request refresh token payload
     * @return 200 OK with new tokens
     */
    @Operation(summary = "Refresh access token")
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(
            @Valid @RequestBody RefreshTokenRequest request) {

        AuthResponse auth = authService.refresh(request);
        return ResponseEntity.ok(ApiResponse.success(auth));
    }

    // ─────────────────────────────────────────────────────────────
    // Logout
    // ─────────────────────────────────────────────────────────────

    /**
     * Revokes the refresh token (server-side logout).
     *
     * @param playerId injected from JWT filter (authenticated principal)
     * @return 204 No Content
     */
    @Operation(summary = "Logout and revoke refresh token")
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@AuthenticationPrincipal UUID playerId) {
        authService.logout(playerId);
        return ResponseEntity.noContent().build();
    }

    // ─────────────────────────────────────────────────────────────
    // Health check for auth service
    // ─────────────────────────────────────────────────────────────

    @GetMapping("/ping")
    public ResponseEntity<ApiResponse<String>> ping() {
        return ResponseEntity.ok(ApiResponse.success("auth-ok"));
    }
}
