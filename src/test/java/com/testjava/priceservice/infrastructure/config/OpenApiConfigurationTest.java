package com.testjava.priceservice.infrastructure.config;

import io.swagger.v3.oas.models.OpenAPI;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class OpenApiConfigurationTest {

    @Autowired
    private OpenAPI openAPI;

    @Test
    void shouldCreateOpenApiBean() {
        // Given/When/Then
        assertNotNull(openAPI);
        assertNotNull(openAPI.getInfo());
        assertEquals("Price Service API", openAPI.getInfo().getTitle());
        assertEquals("1.0.0", openAPI.getInfo().getVersion());
        assertNotNull(openAPI.getServers());
        assertFalse(openAPI.getServers().isEmpty());
    }
}