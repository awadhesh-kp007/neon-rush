package com.neonrush.auth.dto;

import jakarta.validation.constraints.*;

/**
 * AuthDtos — sealed interface grouping all authentication request/response DTOs.
 *
 * <p>Uses Java 21 sealed interfaces + records for compile-time exhaustiveness.
 */
public sealed interface AuthDtos permits
        AuthDtos.RegisterRequest,
        AuthDtos.LoginRequest,
        AuthDtos.RefreshTokenRequest,
        AuthDtos.AuthResponse,
        AuthDtos.PlayerSummary {

    /**
     * New account registration payload.
     */
    record RegisterRequest(
            @Email(message = "Email must be valid")
            @NotBlank(message = "Email is required")
            @Size(max = 320, message = "Email too long")
            String email,

            @NotBlank(message = "Password is required")
            @Size(min = 8, max = 72, message = "Password must be 8–72 characters")
            @Pattern(
                regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).+$",
                message = "Password must contain at least one uppercase letter, one lowercase letter, and one digit"
            )
            String password,

            @NotBlank(message = "Display name is required")
            @Size(min = 3, max = 32, message = "Display name must be 3–32 characters")
            @Pattern(
                regexp = "^[a-zA-Z0-9_\\-]+$",
                message = "Display name may only contain letters, digits, underscores, and hyphens"
            )
            String displayName
    ) implements AuthDtos {}

    /**
     * Login payload.
     */
    record LoginRequest(
            @Email(message = "Email must be valid")
            @NotBlank(message = "Email is required")
            String email,

            @NotBlank(message = "Password is required")
            String password
    ) implements AuthDtos {}

    /**
     * Token refresh payload.
     */
    record RefreshTokenRequest(
            @NotBlank(message = "refreshToken is required")
            String refreshToken
    ) implements AuthDtos {}

    /**
     * Successful auth response returned to the game client.
     */
    record AuthResponse(
            String accessToken,
            String refreshToken,
            PlayerSummary player
    ) implements AuthDtos {}

    /**
     * Minimal player profile embedded in auth responses.
     */
    record PlayerSummary(
            String playerId,
            String username,
            String email,
            String role
    ) implements AuthDtos {}
}
