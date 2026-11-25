package com.neonrush.auth.service;

import com.neonrush.auth.domain.User;
import com.neonrush.auth.dto.AuthDtos.*;
import com.neonrush.auth.repository.UserRepository;
import com.neonrush.auth.security.JwtService;
import com.neonrush.shared.exception.NeonRushException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/**
 * AuthService — handles player registration, login, and token refresh.
 *
 * <p>All password handling is delegated to {@link PasswordEncoder}.
 * JWT lifecycle is owned by {@link JwtService}.
 * Never logs passwords or raw tokens.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    // ─────────────────────────────────────────────────────────────
    // Registration
    // ─────────────────────────────────────────────────────────────

    /**
     * Registers a new player account.
     *
     * @param request validated registration payload
     * @return {@link AuthResponse} containing tokens and player summary
     */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw new NeonRushException(HttpStatus.CONFLICT,
                    "An account with this email already exists.");
        }
        if (userRepository.existsByUsernameIgnoreCase(request.displayName())) {
            throw new NeonRushException(HttpStatus.CONFLICT,
                    "This username is already taken.");
        }

        var user = User.builder()
                .id(UUID.randomUUID())
                .email(request.email().toLowerCase().trim())
                .username(request.displayName().trim())
                .passwordHash(passwordEncoder.encode(request.password()))
                .role(User.Role.PLAYER)
                .createdAt(Instant.now())
                .build();

        userRepository.save(user);
        log.info("New player registered: id={} username={}", user.getId(), user.getUsername());

        return buildAuthResponse(user);
    }

    // ─────────────────────────────────────────────────────────────
    // Login
    // ─────────────────────────────────────────────────────────────

    /**
     * Authenticates a player with email + password.
     *
     * @param request login payload
     * @return {@link AuthResponse} with fresh tokens
     */
    @Transactional
    public AuthResponse login(LoginRequest request) {
        var user = userRepository.findByEmailIgnoreCase(request.email())
                .orElseThrow(() -> new NeonRushException(HttpStatus.UNAUTHORIZED,
                        "Invalid email or password."));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new NeonRushException(HttpStatus.UNAUTHORIZED,
                    "Invalid email or password.");
        }
        if (user.isBanned()) {
            throw new NeonRushException(HttpStatus.FORBIDDEN,
                    "Account suspended. Contact support.");
        }

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);
        log.info("Player logged in: id={}", user.getId());

        return buildAuthResponse(user);
    }

    // ─────────────────────────────────────────────────────────────
    // Token Refresh
    // ─────────────────────────────────────────────────────────────

    /**
     * Issues a new access token from a valid refresh token.
     *
     * @param request refresh token payload
     * @return {@link AuthResponse} with new tokens
     */
    @Transactional
    public AuthResponse refresh(RefreshTokenRequest request) {
        var userId = jwtService.extractUserIdFromRefreshToken(request.refreshToken());
        var user = userRepository.findById(userId)
                .orElseThrow(() -> new NeonRushException(HttpStatus.UNAUTHORIZED,
                        "Invalid refresh token."));

        if (!jwtService.isRefreshTokenValid(request.refreshToken(), user)) {
            throw new NeonRushException(HttpStatus.UNAUTHORIZED,
                    "Refresh token expired or revoked. Please log in again.");
        }

        log.debug("Token refreshed for player: id={}", userId);
        return buildAuthResponse(user);
    }

    // ─────────────────────────────────────────────────────────────
    // Logout
    // ─────────────────────────────────────────────────────────────

    /**
     * Revokes the refresh token for the given player (server-side logout).
     *
     * @param playerId authenticated player ID
     */
    @Transactional
    public void logout(UUID playerId) {
        userRepository.findById(playerId).ifPresent(user -> {
            jwtService.revokeRefreshToken(user);
            userRepository.save(user);
            log.info("Player logged out: id={}", playerId);
        });
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────

    private AuthResponse buildAuthResponse(User user) {
        String accessToken  = jwtService.generateAccessToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);

        var summary = new PlayerSummary(
                user.getId().toString(),
                user.getUsername(),
                user.getEmail(),
                user.getRole().name()
        );

        return new AuthResponse(accessToken, refreshToken, summary);
    }
}
