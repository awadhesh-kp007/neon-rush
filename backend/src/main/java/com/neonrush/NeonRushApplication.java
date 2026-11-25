package com.neonrush;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * NEON RUSH: CITY ESCAPE — Backend Application Entry Point.
 *
 * <p>Modular Spring Boot monolith. Modules are organized by domain:
 * auth, player, game, inventory, mission, leaderboard, reward, purchase,
 * notification, analytics. Each domain has its own package with clean
 * Controller → Service → Repository layering.
 *
 * <p>Extract individual domains to independent services when scale,
 * team ownership, or deployment cadence justifies it.
 */
@SpringBootApplication
@EnableCaching
@EnableKafka
@EnableScheduling
public class NeonRushApplication {

    public static void main(String[] args) {
        SpringApplication.run(NeonRushApplication.class, args);
    }
}
