package com.testjava.priceservice.infrastructure.web.service;

import com.testjava.priceservice.infrastructure.web.dto.PriceResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static com.testjava.priceservice.common.TestDataFactory.*;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

@DisplayName("Infrastructure Service Tests - HTTP Request Logger")
class HttpRequestLoggerTest {

    private HttpRequestLogger httpRequestLogger;
    private PriceResponse testResponse;

    @BeforeEach
    void setUp() {
        httpRequestLogger = new HttpRequestLogger();
        
        testResponse = new PriceResponse(
            TEST_PRODUCT_ID,
            TEST_BRAND_ID,
            TEST_PRICE_LIST_1,
            TEST_DATE_2020_06_14_16_00,
            TEST_DATE_2020_06_14_16_00,
            TEST_PRICE_35_50
        );
    }

    @Test
    @DisplayName("Should log incoming request successfully")
    void shouldLogIncomingRequestSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logIncomingRequest(
            VALID_DATE_STRING, TEST_PRODUCT_ID, TEST_BRAND_ID));
    }

    @Test
    @DisplayName("Should log successful response successfully")
    void shouldLogSuccessfulResponseSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logSuccessfulResponse(testResponse));
    }

    @Test
    @DisplayName("Should log not found response successfully")
    void shouldLogNotFoundResponseSuccessfully() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logNotFoundResponse());
    }

    @Test
    @DisplayName("Should log request error successfully")
    void shouldLogRequestErrorSuccessfully() {
        // Given
        Exception testException = new IllegalArgumentException(PRODUCT_ID_NULL_ERROR);

        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logRequestError(
            testException, VALID_DATE_STRING, TEST_PRODUCT_ID, TEST_BRAND_ID));
    }

    @Test
    @DisplayName("Should log processing error successfully")
    void shouldLogProcessingErrorSuccessfully() {
        // Given
        Exception testException = new RuntimeException("Database connection failed");

        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logProcessingError(testException));
    }

    @Test
    @DisplayName("Should handle null parameters in logIncomingRequest")
    void shouldHandleNullParametersInLogIncomingRequest() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logIncomingRequest(null, null, null));
        assertDoesNotThrow(() -> httpRequestLogger.logIncomingRequest(
            VALID_DATE_STRING, null, TEST_BRAND_ID));
        assertDoesNotThrow(() -> httpRequestLogger.logIncomingRequest(
            null, TEST_PRODUCT_ID, TEST_BRAND_ID));
    }

    @Test
    @DisplayName("Should handle null response in logSuccessfulResponse")
    void shouldHandleNullResponseInLogSuccessfulResponse() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logSuccessfulResponse(null));
    }

    @Test
    @DisplayName("Should handle null exception in logRequestError")
    void shouldHandleNullExceptionInLogRequestError() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logRequestError(
            null, VALID_DATE_STRING, TEST_PRODUCT_ID, TEST_BRAND_ID));
    }

    @Test
    @DisplayName("Should handle null exception in logProcessingError")
    void shouldHandleNullExceptionInLogProcessingError() {
        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logProcessingError(null));
    }

    @Test
    @DisplayName("Should log request error with null parameters")
    void shouldLogRequestErrorWithNullParameters() {
        // Given
        Exception testException = new IllegalArgumentException("Test error");

        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logRequestError(
            testException, null, null, null));
    }

    @Test
    @DisplayName("Should handle complex error scenarios")
    void shouldHandleComplexErrorScenarios() {
        // Given
        Exception complexException = new RuntimeException("Complex error with nested cause", 
            new IllegalStateException("Nested cause"));

        // When & Then
        assertDoesNotThrow(() -> httpRequestLogger.logProcessingError(complexException));
        assertDoesNotThrow(() -> httpRequestLogger.logRequestError(
            complexException, VALID_DATE_STRING, TEST_PRODUCT_ID, TEST_BRAND_ID));
    }
}