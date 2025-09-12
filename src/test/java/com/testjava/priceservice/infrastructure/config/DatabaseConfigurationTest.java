package com.testjava.priceservice.infrastructure.config;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class DatabaseConfigurationTest {

    @Autowired
    private DatabaseConfiguration databaseConfiguration;

    @Test
    void shouldCreateDatabaseConfigurationBean() {
        // Given/When/Then
        assertNotNull(databaseConfiguration);
    }
}