# NEON RUSH: CITY ESCAPE — Project Ledger

> **Tech Stack:** Godot 4.x + GDScript | Java 21 + Spring Boot 3.4.2 | React + JSX | PostgreSQL 17 + Redis | Kafka | Docker + Kubernetes + AWS
> **Last Updated:** 2026-11-17

---

## Phase 1 — Godot Game Client Foundation

### ✅ Core Systems
| File | Status | Notes |
|------|--------|-------|
| `scripts/core/game_constants.gd` | ✅ Done | All constants, lane positions, physics params |
| `scripts/core/event_bus.gd` | ✅ Done | Full decoupled EventBus with all signals |
| `scripts/core/game_manager.gd` | ✅ Done | Full state machine (7 states) |
| `project.godot` | ✅ Done | Autoloads wired (14 autoloads) |
| `export_presets.cfg` | ✅ Done | Android ARM64, min SDK 24, package: com.neonrush.cityescape |

### ✅ Player Scripts
| File | Status | Notes |
|------|--------|-------|
| `scripts/player/runner_controller.gd` | ✅ Done | Full 3-lane CharacterBody3D, jump, slide, hoverboard |
| `scripts/player/player_animation.gd` | ✅ Done | AnimationTree/AnimationPlayer bridge, speed scaling |
| `scripts/player/player_collision.gd` | ✅ Done | Area3D collision, hoverboard immunity, coin/powerup |
| `scripts/input/swipe_input_controller.gd` | ✅ Done | Touch + keyboard, ratio 1.5, 50px min |

### ✅ Camera
| File | Status | Notes |
|------|--------|-------|
| `scripts/camera/follow_camera.gd` | ✅ Done | Smooth follow, FOV transitions |

### ✅ Gameplay Systems
| File | Status | Notes |
|------|--------|-------|
| `scripts/gameplay/score_manager.gd` | ✅ Done | Score, distance, coins, XP, high score, ConfigFile |
| `scripts/gameplay/difficulty_manager.gd` | ✅ Done | Speed ramp, difficulty tiers |
| `scripts/gameplay/run_manager.gd` | ✅ Done | Countdown, run lifecycle, results transition |

### ✅ Environment
| File | Status | Notes |
|------|--------|-------|
| `scripts/environment/object_pool.gd` | ✅ Done | Generic pool, prewarm, get, release |
| `scripts/environment/track_generator.gd` | ✅ Done | Procedural, deterministic seed, ObjectPool |

### ✅ Obstacles
| File | Status | Notes |
|------|--------|-------|
| `scripts/obstacles/obstacle_base.gd` | ✅ Done | Base class with metadata, Area3D |
| `scripts/obstacles/obstacle_spawner.gd` | ✅ Done | 4 difficulty tiers, pattern-based, despawn |

### ✅ Power-ups
| File | Status | Notes |
|------|--------|-------|
| `scripts/powerups/powerup_manager.gd` | ✅ Done | Duration, stacking, mutually exclusive, EventBus |
| `scripts/powerups/coin_magnet.gd` | ✅ Done | Area3D magnet radius, tween attract |
| `scripts/powerups/jetpack.gd` | ✅ Done | Signal-based (RunnerController handles physics) |
| `scripts/powerups/hoverboard.gd` | ✅ Done | Crash immunity, visual board tween |
| `scripts/powerups/score_multiplier.gd` | ✅ Done | UI feedback, multiplier_changed signal |

### ✅ Economy
| File | Status | Notes |
|------|--------|-------|
| `scripts/economy/coin_manager.gd` | ✅ Done | Persistent wallet, session coins, ConfigFile |

### ✅ Characters
| File | Status | Notes |
|------|--------|-------|
| `scripts/characters/character_manager.gd` | ✅ Done | 4 characters, unlock by coins/mission, persistence |

### ✅ Missions
| File | Status | Notes |
|------|--------|-------|
| `scripts/missions/mission_manager.gd` | ✅ Done | Daily missions, UTC reset, progress tracking |

### ✅ Network / Auth (Game Client)
| File | Status | Notes |
|------|--------|-------|
| `scripts/network/api_client.gd` | ✅ Done | Async HTTPRequest, JWT, offline queue, retry |
| `scripts/network/auth_manager.gd` | ✅ Done | Register/login/logout, persistent session |
| `scripts/network/network_manager.gd` | ✅ Done | Connectivity monitoring, run submission |

### ✅ Security
| File | Status | Notes |
|------|--------|-------|
| `scripts/security/replay_recorder.gd` | ✅ Done | Snapshots, SHA-256 run hash |

### ✅ Analytics
| File | Status | Notes |
|------|--------|-------|
| `scripts/analytics/analytics_manager.gd` | ✅ Done | Event batching, session ID, flush on interval |

### ✅ UI Scripts
| File | Status | Notes |
|------|--------|-------|
| `scripts/ui/gameplay_hud.gd` | ✅ Done | Score, distance, coins, multiplier, countdown, pause |

### ✅ Scene Files
| File | Status | Notes |
|------|--------|-------|
| `scenes/bootstrap/bootstrap.tscn` | ✅ Done | Entry point, loading label |
| `scenes/gameplay/gameplay.tscn` | ✅ Done | Full scene tree: Player, Camera, HUD, ObstacleSpawner, Lighting |
| `scenes/player/player.tscn` | ✅ Done | Reusable CharacterBody3D with both collision shapes |
| `scenes/main-menu/main_menu.tscn` | ✅ Done | Full main menu with buttons, coins, login |
| `scenes/results/game_over.tscn` | ✅ Done | Score, stats, Revive/Restart/Menu buttons |
| `scenes/obstacles/obstacle_barrier.tscn` | ✅ Done | Barrier obstacle with Area3D |

### ⬜ Scene Files (Remaining)
| File | Status | Priority |
|------|--------|---------|
| `scenes/ui/gameplay_hud.tscn` | ⬜ TODO | High — HUD as standalone scene |
| `scenes/powerups/powerup_base.tscn` | ⬜ TODO | Medium |
| `scenes/obstacles/obstacle_train.tscn` | ⬜ TODO | High |
| `scenes/obstacles/obstacle_overhead.tscn` | ⬜ TODO | High |
| `scenes/environment/track_segment.tscn` | ⬜ TODO | High — needed by TrackGenerator |
| `scenes/shop/shop.tscn` | ⬜ TODO | Low (Phase 2) |

### ⬜ GDScript (Remaining)
| File | Status | Notes |
|------|--------|-------|
| `scripts/environment/track_segment.gd` | ⬜ TODO | Individual segment, poolable |
| `scripts/environment/world_manager.gd` | ⬜ TODO | Biome/world switching |
| `scripts/characters/character_selector.gd` | ⬜ TODO | UI controller for character select |
| `scripts/characters/character_customizer.gd` | ⬜ TODO | Outfit overlay |
| `scripts/economy/gem_manager.gd` | ⬜ TODO | Premium currency |
| `scripts/economy/inventory_manager.gd` | ⬜ TODO | Items/outfits |
| `scripts/ui/main_menu_controller.gd` | ⬜ TODO | Main menu button wiring |
| `scripts/ui/game_over_controller.gd` | ⬜ TODO | Results screen wiring |
| `scripts/ui/shop_controller.gd` | ⬜ TODO | Shop UI |
| `scripts/ui/pause_controller.gd` | ⬜ TODO | Pause screen |

### ✅ Tests
| File | Status | Notes |
|------|--------|-------|
| `tests/unit/test_core_systems.gd` | ✅ Done | GUT suite: ScoreManager, ObjectPool, Swipe, Difficulty |
| `tests/.gutconfig.json` | ✅ Done | Test runner config |

---

## Phase 2 — Backend (Java / Spring Boot 3.4.2)

### ✅ Foundation
| File | Status | Notes |
|------|--------|-------|
| `backend/pom.xml` | ✅ Done | Full Spring Boot 3.4.2 POM |
| `NeonRushApplication.java` | ✅ Done | Entry point |
| `shared/response/ApiResponse.java` | ✅ Done | Unified envelope with success/error factories |
| `shared/exception/NeonRushException.java` | ✅ Done | Domain exception with HTTP status |
| `shared/exception/GlobalExceptionHandler.java` | ✅ Done | Maps all exceptions to structured responses |
| `db/migration/V1__initial_schema.sql` | ✅ Done | Full PostgreSQL schema |
| `resources/application.yml` | ✅ Done | Full config: DB, Redis, Kafka, JWT, anti-cheat |

### ✅ Auth Module
| File | Status | Notes |
|------|--------|-------|
| `auth/domain/User.java` | ✅ Done | Lombok builder, Role enum, refreshTokenJti, banned |
| `auth/dto/AuthDtos.java` | ✅ Done | Sealed interface with 5 records, Bean Validation |
| `auth/repository/UserRepository.java` | ✅ Done | JPA repo |
| `auth/service/AuthService.java` | ✅ Done | Register, login, refresh, logout |
| `auth/security/JwtService.java` | ✅ Done | HS256 access+refresh tokens, server-side revocation |
| `auth/security/JwtAuthFilter.java` | ✅ Done | OncePerRequestFilter, sets SecurityContext |
| `auth/security/SecurityConfig.java` | ✅ Done | Stateless, CORS, public/protected endpoints |
| `auth/controller/AuthController.java` | ✅ Done | Register/Login/Refresh/Logout endpoints |

### ✅ Game Module
| File | Status | Notes |
|------|--------|-------|
| `game/dto/GameDtos.java` | ✅ Done | RunSubmitRequest/Response, Leaderboard DTOs |
| `game/service/ScoreValidationService.java` | ✅ Done | Speed, density, clock drift anti-cheat |
| `game/controller/GameController.java` | ✅ Done | /runs, /leaderboard, /leaderboard/weekly, /runs/me |

### ⬜ Backend (Remaining)
| Component | Status | Priority |
|-----------|--------|---------|
| Player module (profile, stats, wallet) | ⬜ TODO | High |
| GameRunRepository + GameRun entity | ⬜ TODO | High |
| Leaderboard repository + caching (Redis) | ⬜ TODO | High |
| Rate limiting (Bucket4j) | ⬜ TODO | High |
| Kafka producers (run events) | ⬜ TODO | Medium |
| Admin module | ⬜ TODO | Medium |
| OpenAPI/Swagger config | ⬜ TODO | Low |
| Integration tests (Testcontainers) | ⬜ TODO | Medium |

---

## Phase 3 — React Player Portal

### ✅ Done
| File | Status | Notes |
|------|--------|-------|
| `package.json` | ✅ Done | React 18 + Vite + Axios + React Router + Recharts |
| `vite.config.js` | ✅ Done | Proxy to backend, port 3000 |
| `index.html` | ✅ Done | Entry HTML |
| `src/main.jsx` | ✅ Done | React root mount |
| `src/index.css` | ✅ Done | Global dark neon theme |
| `src/app/App.jsx` | ✅ Done | Router, AuthContext, ProtectedRoute |
| `src/services/apiClient.js` | ✅ Done | Axios instance, JWT interceptor, 401 refresh |
| `src/services/authService.js` | ✅ Done | Register/login/logout, localStorage persistence |
| `src/components/Navbar.jsx` | ✅ Done | Neon nav, auth-aware |
| `src/features/auth/LoginPage.jsx` | ✅ Done | Form + error handling |
| `src/features/auth/RegisterPage.jsx` | ✅ Done | Form + error handling |
| `src/features/leaderboard/LeaderboardPage.jsx` | ✅ Done | Global/Weekly tabs |
| `src/features/home/HomePage.jsx` | ✅ Done | Hero, CTA, stats strip |
| `src/features/profile/ProfilePage.jsx` | ✅ Done | Avatar, stats grid, logout |
| `.env.example` | ✅ Done | Environment variable template |

### ⬜ Player Portal (Remaining)
| Component | Status | Priority |
|-----------|--------|---------|
| `features/leaderboard/PersonalBestPage.jsx` | ⬜ TODO | Medium |
| `features/shop/ShopPage.jsx` | ⬜ TODO | Low (Phase 4) |
| `features/missions/MissionsPage.jsx` | ⬜ TODO | Low |
| Recharts score history chart on ProfilePage | ⬜ TODO | Low |

---

## Phase 4 — Admin Portal (React)

| Component | Status | Priority |
|-----------|--------|---------|
| `admin-portal/react-admin/package.json` | ✅ Done | Scaffolded |
| Dashboard.jsx | ⬜ TODO | High |
| PlayersPage.jsx (search, ban) | ⬜ TODO | High |
| RunsPage.jsx (suspicious runs review) | ⬜ TODO | High |
| Anti-cheat queue | ⬜ TODO | Medium |

---

## Phase 5 — Infrastructure & DevOps

| Component | Status | Priority |
|-----------|--------|---------|
| `docker-compose.yml` (dev stack) | ✅ Done | Full stack: PG17, Redis, Kafka, Backend, Portals |
| `backend.Dockerfile` | ✅ Done | Multi-stage Java 21 |
| `.github/workflows/backend-ci.yml` | ✅ Done | Build + test with Postgres/Redis services |
| `.github/workflows/frontend-ci.yml` | ✅ Done | Vite build |
| Kubernetes manifests | ⬜ TODO | Phase 5 |
| Terraform (AWS EKS + RDS) | ⬜ TODO | Phase 5 |
| Prometheus + Grafana dashboards | ⬜ TODO | Phase 5 |

---

## Phase 6 — Python Analytics

| Component | Status |
|-----------|--------|
| Analytics ingest scripts | ⬜ TODO |
| Player retention dashboard | ⬜ TODO |
| Churn prediction model | ⬜ TODO |

---

## Milestone Checklist

- [x] **M1:** Project scaffolded (232 dirs, monorepo structure)
- [x] **M2:** All core GDScript autoloads written (14 autoloads registered)
- [x] **M3:** Godot scene files created (bootstrap, gameplay, player, main menu, game over, barrier)
- [x] **M4:** Backend auth service end-to-end (register → login → JWT → game submit)
- [x] **M5:** Player portal shell live (routing, auth, leaderboard)
- [ ] **M6:** Game playable in Godot editor with placeholder meshes
- [ ] **M7:** Backend connects to real PostgreSQL with Flyway migration
- [ ] **M8:** Player portal talks to live backend
- [ ] **M9:** Android APK builds and runs on device
- [ ] **M10:** Leaderboard populated from real runs

---

## Architecture Notes

- **EventBus pattern:** All Godot systems communicate via signals — never direct node references
- **Autoload order matters:** EventBus → GameConstants → GameManager → ScoreManager → DifficultyManager → PowerupManager → CoinManager → CharacterManager → MissionManager → ApiClient → AuthManager → NetworkManager → ReplayRecorder → AnalyticsManager
- **Backend is authoritative** for scores, currency, and purchases — client score is validated then persisted
- **Offline play** always works — backend sync is best-effort, queued when offline
- **Anti-cheat:** Speed bound 9.5–35 m/s, coin density ≤1.5/m, score density ≤150/m, clock drift ≤5min
- **No TypeScript, No C#, No Rust** anywhere in the project
