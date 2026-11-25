package com.neonrush.auth.security;

import com.neonrush.auth.controller.AuthController;
import com.neonrush.auth.repository.UserRepository;
import com.neonrush.auth.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(AuthController.class)
@Import({SecurityConfig.class, JwtAuthFilter.class, SecurityConfigTest.DocsRouteProbe.class,
    SecurityConfigTest.MetricsRouteProbe.class})
@TestPropertySource(properties = {
    "monitoring.auth.username=test-monitor",
    "monitoring.auth.password=test-monitor-password",
    "CORS_ORIGINS=http://localhost:3000,http://localhost:3001,https://portal.example"
})
class SecurityConfigTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    @MockitoBean
    private JwtService jwtService;

    @MockitoBean
    private UserRepository userRepository;

    @Test
    void authPingIsPublic() throws Exception {
        mockMvc.perform(get("/v1/auth/ping"))
                .andExpect(status().isOk());
    }

    @Test
    void configuredOpenApiPathIsPublic() throws Exception {
        mockMvc.perform(get("/api-docs"))
                .andExpect(status().isOk());
    }

    @Test
    void corsAllowsConfiguredLocalComposeOrigin() throws Exception {
        mockMvc.perform(options("/v1/auth/ping")
                        .header("Origin", "http://localhost:3000")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:3000"));
    }

    @Test
    void corsAllowsConfiguredDeploymentOrigin() throws Exception {
        mockMvc.perform(options("/v1/auth/ping")
                        .header("Origin", "https://portal.example")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "https://portal.example"));
    }

    @Test
    void corsRejectsUnconfiguredLocalhostPort() throws Exception {
        mockMvc.perform(options("/v1/auth/ping")
                        .header("Origin", "http://localhost:9999")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isForbidden());
    }

    @Test
    void corsRejectsUnconfiguredNeonRushSubdomain() throws Exception {
        mockMvc.perform(options("/v1/auth/ping")
                        .header("Origin", "https://preview.neonrush.game")
                        .header("Access-Control-Request-Method", "GET"))
                .andExpect(status().isForbidden());
    }

    @Test
    void logoutRequiresAuthentication() throws Exception {
        mockMvc.perform(post("/v1/auth/logout"))
                .andExpect(status().isForbidden());
    }

    @Test
    void prometheusRequiresMonitoringCredentials() throws Exception {
        mockMvc.perform(get("/actuator/prometheus"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void prometheusAcceptsMonitoringCredentials() throws Exception {
        mockMvc.perform(get("/actuator/prometheus")
                        .with(httpBasic("test-monitor", "test-monitor-password")))
                .andExpect(status().isOk());
    }

    @RestController
    static class DocsRouteProbe {
        @GetMapping("/api-docs")
        String docs() {
            return "public";
        }
    }

    @RestController
    static class MetricsRouteProbe {
        @GetMapping("/actuator/prometheus")
        String metrics() {
            return "neonrush_up 1";
        }
    }
}