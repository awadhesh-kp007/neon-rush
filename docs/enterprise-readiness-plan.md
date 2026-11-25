# Enterprise Readiness Plan

## Goal

Raise NEON RUSH from a functional multi-service project to a production-operable system with verifiable security, reliability, delivery, and support controls. This plan is a staged engineering roadmap, not a claim of compliance or certification.

## Reference Baseline

Use OWASP ASVS 5.0.0 as the application security verification checklist and OWASP API Security Top 10 (2023) to prioritize API risks. Spring Security and Spring Boot production documentation are the implementation references for JWT validation, Actuator exposure, health probes, and graceful operation.

- OWASP ASVS 5.0.0: https://asvs.owasp.org/
- OWASP API Security Top 10: https://owasp.org/www-project-api-security/
- OWASP Session Management Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- OWASP HTML5 Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Spring Security JWT resource server: https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html
- Spring Boot Actuator endpoints: https://docs.spring.io/spring-boot/reference/actuator/endpoints.html

## Current Assessment

The repository has a Spring Boot backend, PostgreSQL, Redis, Kafka, player and admin React portals, Docker Compose, Kubernetes manifests, and a backend CI workflow. Existing positives include stateless JWT authentication, password hashing, Flyway-owned schema, request DTO validation, graceful shutdown, health/metrics dependencies, and a Java 21 CI job.

Current assessment after the first implementation slice:

- JWT property names now match, weak/missing JWT secrets fail startup, and PostgreSQL/Redis passwords have no application YAML fallback.
- Prometheus requires a dedicated monitoring identity; local Compose credentials are externalized to an ignored `.env` file and supplied to both backend and Prometheus.
- Auth ping, OpenAPI path access, anonymous logout denial, and metrics authentication have focused regression tests.
- JWT validation currently loads the user for every authenticated request; token/session revocation, key rotation, and abuse controls need explicit design and tests.
- Admin-role, token lifecycle, and object-level authorization tests remain necessary before Phase 1 can exit.
- CORS now uses the configured exact-origin allowlist, with local Compose origins retained as development defaults and negative preflight tests for unconfigured origins. Deployments must set `CORS_ORIGINS` to their actual portal origins.
- Production must use a production profile, managed secrets, TLS, and private networking for backend, metrics, and data services; current Compose is local development only.
- CI builds and tests but has no dependency/security scan, SBOM, or artifact provenance gate in the inspected workflow.

## Phases

### Phase 0: Baseline and Governance

Scope: establish ownership and evidence before large redesigns. Inventory runtime entrypoints, data flows, external dependencies, secrets, environments, and current automated checks. Define release criteria and keep this plan as the working tracker.

Exit criteria:
- Every service has an owner, supported runtime, build/test command, and deployment configuration.
- Threat model and data classification identify player PII, credentials, gameplay submissions, and administrative actions.
- CI validation is repeatable locally and on the default branch.

Status: started in this implementation session.

### Phase 1: Identity, API Security, and Secure Defaults

Scope: close configuration mismatches and insecure defaults; establish JWT lifecycle, role enforcement, object-level authorization, request validation, CORS policy, rate limiting, and protected operational endpoints. Add unit and integration coverage for public/private routes, banned users, expired/wrong-type tokens, refresh rotation/revocation, admin-only operations, and cross-player data access.

Priority order:
1. [x] Align JWT property configuration and reject absent/weak secrets at startup; add Spring bean startup regression tests.
2. Add security tests and verify all controller paths and ownership checks against OWASP API1/API2/API3/API5.
3. [x] Protect Prometheus scraping with dedicated credentials while preserving internal cluster scraping; verify anonymous denial and authenticated success.
4. Add distributed request throttling for authentication and high-cost gameplay operations, with observable 429 behavior.
5. [x] Replace hardcoded permissive CORS patterns with a configurable exact-origin allowlist and negative tests; retain local Compose portal origins as development defaults.

Exit criteria:
- Security tests run on every pull request, including unauthorized, forbidden, and owner-boundary cases.
- No production secret or permissive fallback is stored in source control.
- Management endpoints are reachable only by the intended monitoring/admin network and credentials.

Status: active. Item 1 is implemented and tested. Item 2 is in progress; documented public routes are covered, anonymous logout is denied, and the configured OpenAPI path is permitted. Admin-role, token lifecycle, and object-level authorization tests remain. Item 3's application-level metrics authentication and local Prometheus wiring are implemented and tested. Keep metrics behind private network policy and TLS in production. Item 4 and production profile/network validation remain release-critical. Item 5 is implemented and independently QA-reviewed with a pass-with-risks verdict: the configured local player origin is accepted, a configured deployment origin is accepted, an unconfigured localhost port and wildcard-style production subdomain are rejected, and local Compose configuration validates using its example environment. The focused MVC security suite passes 9 tests. Configure `CORS_ORIGINS` explicitly for each deployment; no production origin has been established by this repository check. Next prioritized slice: add admin-role and object-level authorization regression tests under item 2.

### Phase 2: API Contracts and Data Integrity

Scope: versioned API contracts, consistent error envelopes, strict input bounds, pagination limits, idempotency for score/run submissions, migration safety, data retention and deletion workflows, and audit records for privileged changes.

Exit criteria:
- OpenAPI contract is generated and checked for breaking changes.
- Critical write operations have duplicate/replay tests and database constraints.
- Migration upgrade and rollback/restore procedures are documented and exercised.

### Phase 3: Reliability and Operability

Scope: readiness/liveness probes, timeouts, retry budgets, circuit breakers and bulkheads, Kafka delivery/retry/dead-letter behavior, Redis/PostgreSQL pool sizing, graceful degradation, structured logs, trace correlation, and service-level indicators.

Exit criteria:
- SLOs and actionable alerts exist for availability, latency, errors, saturation, and queue lag.
- Liveness does not depend on shared downstream services; readiness includes only required dependencies.
- Failure-mode tests cover database, cache, broker, and third-party outages.

### Phase 4: Secure Delivery and Supply Chain

Scope: dependency pinning and automated vulnerability review, secret scanning, SAST, container/image scanning, SBOM generation, artifact provenance, least-privilege CI permissions, protected environments, non-root images, and immutable release artifacts.

Exit criteria:
- Pull requests fail on defined critical/high findings or missing attestations, with documented exception handling.
- Release artifacts are traceable to source revision and build workflow.
- Container images run non-root with minimal runtime packages and health probes.

### Phase 5: Player and Admin Product Readiness

Scope: admin RBAC and auditability, session expiry/recovery, accessible and resilient auth flows, user-visible API errors, loading/empty/error states, secure browser token storage strategy, dependency hygiene, and end-to-end tests for core journeys.

Exit criteria:
- Admin actions are separately authorized and auditable.
- Authentication, registration, logout, and account recovery pass browser-level tests.
- Accessibility checks and supported browser/mobile breakpoints are part of CI.

Frontend readiness workstream status: active. This workstream tracks the player and admin portals; it does not change the overall phase status or imply enterprise readiness.

Current inventory:
- The player portal package defines Vitest scripts and now has focused API-client regression tests; full journey/accessibility coverage is still missing.
- Login and registration forms now associate visible labels, retain required fields, use native browser constraint validation, and announce rejected submissions with alert semantics; focused DOM tests exist for these behaviors.
- Vitest uses jsdom 26.1.0, whose Node engine range includes the Node 20 CI runtime. The complete player portal test suite passes locally on Node 22; hosted CI execution under Node 20 remains unverified.
- The player portal has an ESLint 9 flat config and its lint command passes locally. The frontend CI workflow now requires lint and tests before the production build.
- Player toolchain audit remediation upgraded Vitest to 4.1.12 with Vite 6.4.6 and jsdom 26.1.0; the player portal now uses React Router 7.18.5. Its latest full/production npm audits report zero vulnerabilities. The admin portal manifest still declares React Router DOM 6.28.0 and has not been validated; repository-wide frontend audit closure therefore remains open.
- Router migration evidence: the app retains declarative `BrowserRouter`/`Routes`/`Route` APIs, and regression tests cover public routes, unauthenticated `/profile` redirect, unknown-path fallback, and successful login/register navigation. The migration is implemented and locally verified; it is no longer a proposed task.
- The admin portal has a package manifest and `src/` directory; app/source readiness remains unverified.
- The player API client's no-refresh and failed-refresh paths now reject queued requests, clear only the player's auth keys, remove stale Axios default authorization, and deduplicate redirects. Focused tests cover these behaviors.

Frontend phases:

1. Session/API failure handling (first slice, completed): fix the player API client's no-refresh-token concurrent-401 queue hang, storage overreach, stale authorization header, and redirect determinism. Reference OWASP Session Management and HTML5 Security guidance.
	Exit criteria:
	- Concurrent 401 requests with no refresh token all reject or otherwise settle; none remain pending.
	- Only the player's auth keys (`accessToken`, `refreshToken`, and `player`) are removed; unrelated `localStorage` entries remain.
	- Redirect behavior is deterministic: the failure produces a single, consistent navigation to `/login` regardless of concurrent response ordering.
	- Focused Vitest coverage passes for these cases.
	Status/evidence: focused suite `npm test -- src/services/apiClient.test.js` passes 3 tests, including actual requests queued while a refresh request is pending and then rejected. `npm run build` passes. Independent test review found no must-fix issues. The ESLint 9 flat config is now in place and `npm run lint` passes.
2. Accessible player journeys (active): continue assessing login, registration, logout, and session-expiry flows against WCAG 2.2, including keyboard operation, focus handling, form errors, and status announcements. Login/register labels are associated, native required validation is enabled, and rejected submission errors use assertive alert semantics.
	Exit criteria:
	- Automated accessibility checks and documented manual keyboard/screen-reader checks cover the core auth journeys.
	- Auth errors and session expiry remain perceivable and operable without pointer input.
	Status/evidence: focused DOM suite passes 2 files / 4 tests for accessible names, required fields, enabled native validation, and rejected-submission alerts; the complete suite passes 3 files / 7 tests. `npm run lint` and `npm run build` pass locally. These checks ran on Node 22; workflow execution under Node 20 remains outstanding. The tests do not simulate browser-native invalid-submit blocking or establish screen-reader behavior/WCAG conformance.
	Status: implemented and focused-tested. `LoginPage.jsx` and `RegisterPage.jsx` now associate visible labels to controls, preserve required constraints, use native browser validation, and expose rejected submissions with assertive alert semantics. Two DOM test files cover labels, required/native-validation settings, and rejected-submission announcements. jsdom is pinned to 26.1.0 to support Node 20. The player portal CI job now requires lint and the complete unit-test suite before its production build. Local lint, tests, and build passed on Node 22; hosted Node 20 execution remains outstanding. The tests do not simulate browser-native invalid-submit blocking or verify screen-reader timing.
	Next: perform and record the manual keyboard and screen-reader review for login, registration, and session-expiry errors.
3. Admin portal readiness: verify the actual app entrypoints, route guards, role enforcement, audit behavior, and test/build coverage before making readiness claims.
	Exit criteria:
	- Admin source and runtime entrypoints are inventoried and admin-only actions have authorization and audit tests.
	- The portal has repeatable build, lint, and focused test commands with evidence recorded here.
4. Continuous frontend verification (player lint/test/build gates implemented): verify hosted Node 20 execution, add the verified admin checks to CI, and assess supported browser/mobile behavior.
	Exit criteria:
	- CI runs the relevant build, lint, unit, accessibility, and browser-level checks for changes to either portal.
	- Supported browser and viewport coverage is explicit and regressions block release.
	Status/evidence: the player portal Node 20 job runs `npm ci`, `npm run lint`, `npm test`, and `npm run build` as required steps. These checks pass locally on Node 22 (4 test files / 15 tests); player full and production audits report zero vulnerabilities after the React Router 7.18.5 migration. Hosted Node 20 execution remains unverified. The admin manifest still uses React Router DOM 6.28.0, and admin portal checks, migration assessment, and accessibility/browser-level coverage remain outstanding.

### Phase 6: Launch Readiness and Continuous Verification

Scope: backup/restore and disaster recovery drills, incident response/runbooks, privacy and retention review, penetration test remediation, capacity/load tests, deployment rollback, canary strategy, and evidence mapped to selected ASVS verification requirements.

Exit criteria:
- A release checklist is signed off by engineering, security, and operations owners.
- Restore, rollback, incident, and credential-rotation exercises have recent evidence.
- Residual risks have an owner, severity, mitigation, and review date.

## Working Agreement

For each phase, the enterprise orchestrator delegates planning and tracking, implementation, test feedback, and independent QA in that order. Test feedback returns concrete reproduction steps and must-fix findings to the developer. The developer reruns focused validation after each repair. QA reviews the final diff and test evidence without editing implementation. The orchestrator records the decision, remaining risks, and phase status here.

## Local Compose Secrets

Copy `infrastructure/docker-compose/.env.example` to `infrastructure/docker-compose/.env` and replace every placeholder with unique local-only values before starting the stack. The local `.env` supplies JWT, monitoring, PostgreSQL, Redis, and Grafana credentials and is ignored by Git. Never reuse these values in shared or production environments; use the deployment secret manager there.
