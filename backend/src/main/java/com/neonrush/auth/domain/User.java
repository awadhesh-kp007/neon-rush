package com.neonrush.auth.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;
import java.util.UUID;

/**
 * User account entity — stores credentials, role, and account status.
 *
 * <p>Password is stored as a BCrypt hash. The raw password never persists.
 * Economy data, stats, and progression live in separate domain entities.
 * refreshTokenJti is used for server-side refresh token revocation.
 */
@Entity
@Table(
    name = "users",
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_users_email",    columnNames = "email"),
        @UniqueConstraint(name = "uk_users_username", columnNames = "username")
    }
)
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    public enum Role { PLAYER, MODERATOR, ADMIN }

    @Id
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "email", length = 320, nullable = false)
    private String email;

    @Column(name = "username", length = 32, nullable = false)
    private String username;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 16)
    @Builder.Default
    private Role role = Role.PLAYER;

    @Column(name = "email_verified", nullable = false)
    @Builder.Default
    private boolean emailVerified = false;

    @Column(name = "is_banned", nullable = false)
    @Builder.Default
    private boolean banned = false;

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;

    /** jti of the currently valid refresh token; null means logged out. */
    @Column(name = "refresh_token_jti", length = 64)
    private String refreshTokenJti;

    @Column(name = "last_login_at")
    private Instant lastLoginAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    @Builder.Default
    private Instant updatedAt = Instant.now();

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
