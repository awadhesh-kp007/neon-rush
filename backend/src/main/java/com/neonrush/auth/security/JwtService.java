package com.neonrush.auth.security;

import com.neonrush.auth.domain.User;
import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

/**
 * JwtService — generates and validates HS256-signed JWTs.
 *
 * <p>Access tokens are short-lived (15 min default).
 * Refresh tokens are longer-lived (30 days) and their jti is stored
 * in the User entity for server-side revocation.
 */
@Slf4j
@Service
public class JwtService {

    @Value("${neon-rush.security.jwt.secret}")
    private String jwtSecret;

    @Value("${neon-rush.security.jwt.access-token-expiry-seconds:900}")
    private long accessTokenExpirySeconds;   // 15 minutes

    @Value("${neon-rush.security.jwt.refresh-token-expiry-seconds:2592000}")
    private long refreshTokenExpirySeconds;  // 30 days

    private static final String CLAIM_ROLE      = "role";
    private static final String CLAIM_USERNAME  = "username";
    private static final String TOKEN_TYPE_ACCESS  = "access";
    private static final String TOKEN_TYPE_REFRESH = "refresh";
    private static final String CLAIM_TOKEN_TYPE   = "type";

    @PostConstruct
    void validateConfiguration() {
        if (jwtSecret == null || jwtSecret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("JWT secret must be configured and contain at least 32 bytes");
        }
        if (accessTokenExpirySeconds <= 0 || refreshTokenExpirySeconds <= 0) {
            throw new IllegalStateException("JWT token lifetimes must be positive");
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Token Generation
    // ─────────────────────────────────────────────────────────────

    /**
     * Generates a short-lived access token for the player.
     *
     * @param user authenticated player
     * @return signed JWT string
     */
    public String generateAccessToken(User user) {
        return Jwts.builder()
                .subject(user.getId().toString())
                .claim(CLAIM_USERNAME, user.getUsername())
                .claim(CLAIM_ROLE, user.getRole().name())
                .claim(CLAIM_TOKEN_TYPE, TOKEN_TYPE_ACCESS)
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(accessTokenExpirySeconds)))
                .signWith(signingKey())
                .compact();
    }

    /**
     * Generates a long-lived refresh token and persists its jti to the User entity.
     *
     * @param user authenticated player
     * @return signed refresh JWT string
     */
    public String generateRefreshToken(User user) {
        String jti = UUID.randomUUID().toString();
        // Persist jti for server-side revocation
        user.setRefreshTokenJti(jti);

        return Jwts.builder()
                .subject(user.getId().toString())
                .id(jti)
                .claim(CLAIM_TOKEN_TYPE, TOKEN_TYPE_REFRESH)
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plusSeconds(refreshTokenExpirySeconds)))
                .signWith(signingKey())
                .compact();
    }

    // ─────────────────────────────────────────────────────────────
    // Validation
    // ─────────────────────────────────────────────────────────────

    /**
     * Returns the player UUID from an access token (throws if invalid).
     *
     * @param token raw JWT string
     * @return player UUID
     */
    public UUID extractUserId(String token) {
        return UUID.fromString(parseClaims(token).getSubject());
    }

    /**
     * Extracts player UUID from a refresh token.
     *
     * @param refreshToken raw JWT string
     * @return player UUID
     */
    public UUID extractUserIdFromRefreshToken(String refreshToken) {
        return extractUserId(refreshToken);
    }

    /**
     * Validates that a refresh token is structurally valid, non-expired,
     * and its jti matches the one stored on the user entity.
     *
     * @param refreshToken raw JWT string
     * @param user         player entity
     * @return true if valid
     */
    public boolean isRefreshTokenValid(String refreshToken, User user) {
        try {
            Claims claims = parseClaims(refreshToken);
            String jti = claims.getId();
            return TOKEN_TYPE_REFRESH.equals(claims.get(CLAIM_TOKEN_TYPE)) &&
                   jti != null &&
                   jti.equals(user.getRefreshTokenJti());
        } catch (JwtException e) {
            log.debug("Refresh token validation failed: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Validates an access token and returns true if it is valid and non-expired.
     *
     * @param token raw JWT string
     * @return true if valid
     */
    public boolean isAccessTokenValid(String token) {
        try {
            Claims claims = parseClaims(token);
            return TOKEN_TYPE_ACCESS.equals(claims.get(CLAIM_TOKEN_TYPE));
        } catch (JwtException e) {
            return false;
        }
    }

    /**
     * Revokes a user's refresh token by clearing the stored jti.
     *
     * @param user player entity (caller must save)
     */
    public void revokeRefreshToken(User user) {
        user.setRefreshTokenJti(null);
    }

    /**
     * Extracts the player UUID from a Bearer header value.
     *
     * @param bearerToken "Bearer &lt;token&gt;"
     * @return player UUID
     */
    public UUID extractUserIdFromBearer(String bearerToken) {
        String token = bearerToken.startsWith("Bearer ")
                ? bearerToken.substring(7)
                : bearerToken;
        return extractUserId(token);
    }

    /**
     * Strips "Bearer " prefix and returns the raw token.
     *
     * @param bearerHeader Authorization header value
     * @return raw JWT
     */
    public String stripBearer(String bearerHeader) {
        return bearerHeader != null && bearerHeader.startsWith("Bearer ")
                ? bearerHeader.substring(7)
                : bearerHeader;
    }

    // ─────────────────────────────────────────────────────────────
    // Internals
    // ─────────────────────────────────────────────────────────────

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private SecretKey signingKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8));
    }
}
