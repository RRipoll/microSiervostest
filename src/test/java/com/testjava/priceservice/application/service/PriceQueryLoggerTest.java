package com.testjava.priceservice.application.service;

import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static com.testjava.priceservice.common.TestDataFactory.*;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

@ExtendWith(MockitoExtension.class)
@DisplayName("Application Service Tests - Price Query Logger")
class PriceQueryLoggerTest {

    private PriceQueryLogger priceQueryLogger;
    private PriceQuery testQuery;
    private PriceResult testResult;

    @BeforeEach
    void setUp() {
        priceQueryLogger = new PriceQueryLogger();
        
        testQuery = new PriceQuery(
            TEST_DATE_2020_06_14_16_00,
            TEST_PRODUCT_ID,
            TEST_BRAND_ID
        );
        
        testResult = new PriceResult(
            TEST_PRODUCT_ID,
            TEST_BRAND_ID,
            TEST_PRICE_LIST_1,
            TEST_DATE_2020_06_14_16_00,
            TEST_DATE_2020_06_14_16_00,
            TEST_PRICE_35_50
        );
    }

    @Test
    @DisplayName("Should log query start successfully")
    void shouldLogQueryStartSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryStart(testQuery));
    }

    @Test
    @DisplayName("Should log query success successfully")
    void shouldLogQuerySuccessSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQuerySuccess(testResult));
    }

    @Test
    @DisplayName("Should log query not found successfully")
    void shouldLogQueryNotFoundSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryNotFound(testQuery));
    }

    @Test
    @DisplayName("Should log query result with found price successfully")
    void shouldLogQueryResultWithFoundPriceSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryResult(testQuery, Optional.of(testResult)));
    }

    @Test
    @DisplayName("Should log query result with empty result successfully")
    void shouldLogQueryResultWithEmptyResultSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryResult(testQuery, Optional.empty()));
    }

    @Test
    @DisplayName("Should log domain query debug successfully")
    void shouldLogDomainQueryDebugSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logDomainQueryDebug(testQuery));
    }

    @Test
    @DisplayName("Should log domain result debug successfully")
    void shouldLogDomainResultDebugSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logDomainResultDebug(testResult));
    }

    @Test
    @DisplayName("Should log domain no result debug successfully")
    void shouldLogDomainNoResultDebugSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logDomainNoResultDebug());
    }

    @Test
    @DisplayName("Should handle null query gracefully in logQueryStart")
    void shouldHandleNullQueryGracefullyInLogQueryStart() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryStart(null));
    }

    @Test
    @DisplayName("Should handle null result gracefully in logQuerySuccess")
    void shouldHandleNullResultGracefullyInLogQuerySuccess() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQuerySuccess(null));
    }

    @Test
    @DisplayName("Should handle null query gracefully in logQueryNotFound")
    void shouldHandleNullQueryGracefullyInLogQueryNotFound() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryNotFound(null));
    }

    @Test
    @DisplayName("Should handle null parameters gracefully in logQueryResult")
    void shouldHandleNullParametersGracefullyInLogQueryResult() {
        // When & Then
        assertDoesNotThrow(() -> priceQueryLogger.logQueryResult(null, null));
        assertDoesNotThrow(() -> priceQueryLogger.logQueryResult(testQuery, null));
        assertDoesNotThrow(() -> priceQueryLogger.logQueryResult(null, Optional.of(testResult)));
    }
}