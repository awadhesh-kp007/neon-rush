package com.neonrush.auth.repository;

import com.neonrush.auth.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

/**
 * JPA repository for {@link User} entities.
 */
@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    /** Find by email (case-insensitive). */
    Optional<User> findByEmailIgnoreCase(String email);

    /** Check if email is already registered. */
    boolean existsByEmailIgnoreCase(String email);

    /** Check if username is already taken. */
    boolean existsByUsernameIgnoreCase(String username);
}
