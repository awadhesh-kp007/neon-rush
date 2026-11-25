package com.neonrush.auth.security;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtServiceTest {

    private static final String VALID_SECRET = "01234567890123456789012345678901";
    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(JwtServiceConfiguration.class);

    @Test
    void startsWithPropertiesFromTheJwtConfigurationNamespace() {
        contextRunner
                .withPropertyValues(
                        "neon-rush.security.jwt.secret=" + VALID_SECRET,
                        "neon-rush.security.jwt.access-token-expiry-seconds=900",
                        "neon-rush.security.jwt.refresh-token-expiry-seconds=2592000")
                .run(context -> assertTrue(context.getStartupFailure() == null));
    }

    @Test
    void failsToStartWhenJwtSecretIsMissing() {
        contextRunner
            .withPropertyValues("neon-rush.security.jwt.secret=")
            .run(context -> assertTrue(context.getStartupFailure() != null));
    }

    @Test
    void failsToStartWhenJwtSecretIsTooShort() {
        contextRunner
                .withPropertyValues("neon-rush.security.jwt.secret=" + VALID_SECRET.substring(0, 31))
                .run(context -> assertTrue(context.getStartupFailure() != null));
    }

    @Test
    void acceptsConfiguredSecretAndPositiveTokenLifetimes() {
        JwtService jwtService = configuredService(VALID_SECRET, 900, 2_592_000);

        assertDoesNotThrow(jwtService::validateConfiguration);
    }

    @Test
    void rejectsMissingOrWeakSecret() {
        JwtService jwtService = configuredService("", 900, 2_592_000);

        IllegalStateException error = assertThrows(
                IllegalStateException.class,
                jwtService::validateConfiguration);

        assertTrue(error.getMessage().contains("at least 32 bytes"));
    }

    @Test
    void rejectsNonPositiveTokenLifetime() {
        JwtService jwtService = configuredService(VALID_SECRET, 0, 2_592_000);

        IllegalStateException error = assertThrows(
                IllegalStateException.class,
                jwtService::validateConfiguration);

        assertTrue(error.getMessage().contains("lifetimes must be positive"));
    }

    private JwtService configuredService(String secret, long accessExpiry, long refreshExpiry) {
        JwtService jwtService = new JwtService();
        ReflectionTestUtils.setField(jwtService, "jwtSecret", secret);
        ReflectionTestUtils.setField(jwtService, "accessTokenExpirySeconds", accessExpiry);
        ReflectionTestUtils.setField(jwtService, "refreshTokenExpirySeconds", refreshExpiry);
        return jwtService;
    }

    @Configuration(proxyBeanMethods = false)
    @Import(JwtService.class)
    static class JwtServiceConfiguration {
    }
}