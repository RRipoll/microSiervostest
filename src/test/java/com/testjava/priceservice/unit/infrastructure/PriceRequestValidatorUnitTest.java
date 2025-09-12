package com.testjava.priceservice.unit.infrastructure;

import com.testjava.priceservice.common.TestCategories;
import com.testjava.priceservice.common.TestDataFactory;
import com.testjava.priceservice.infrastructure.web.validator.PriceRequestValidator;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static com.testjava.priceservice.common.TestDataFactory.*;

@Tag(UNIT_TAG)
@DisplayName("Unit Tests - Price Request Validator")
class PriceRequestValidatorUnitTest implements TestCategories.UnitTest {

    @Test
    @DisplayName("Should validate correct request parameters successfully")
    void shouldValidateCorrectRequestParametersSuccessfully() {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_DATE_STRING;
        Long productId = TEST_PRODUCT_ID;
        Long brandId = TEST_BRAND_ID;

        // When & Then
        assertThatCode(() -> validator.validateRequest(applicationDate, productId, brandId))
            .doesNotThrowAnyException();
    }

    @ParameterizedTest
    @NullAndEmptySource
    @ValueSource(strings = {" ", "invalid-date"})
    @DisplayName("Should throw exception for invalid application date")
    void shouldThrowExceptionForInvalidApplicationDate(String invalidDate) {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        Long productId = TEST_PRODUCT_ID;
        Long brandId = TEST_BRAND_ID;

        // When & Then
        assertThatThrownBy(() -> validator.validateRequest(invalidDate, productId, brandId))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("Should throw exception for null product ID")
    void shouldThrowExceptionForNullProductId() {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_DATE_STRING;
        Long brandId = TEST_BRAND_ID;

        // When & Then
        assertThatThrownBy(() -> validator.validateRequest(applicationDate, null, brandId))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining(PRODUCT_ID_NULL_ERROR);
    }

    @Test
    @DisplayName("Should throw exception for null brand ID")
    void shouldThrowExceptionForNullBrandId() {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_DATE_STRING;
        Long productId = TEST_PRODUCT_ID;

        // When & Then
        assertThatThrownBy(() -> validator.validateRequest(applicationDate, productId, null))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining(BRAND_ID_NULL_ERROR);
    }

    @ParameterizedTest
    @ValueSource(longs = {0, -1, -999})
    @DisplayName("Should throw exception for invalid product ID values")
    void shouldThrowExceptionForInvalidProductIdValues(Long invalidProductId) {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_DATE_STRING;
        Long brandId = TEST_BRAND_ID;

        // When & Then
        assertThatThrownBy(() -> validator.validateRequest(applicationDate, invalidProductId, brandId))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining(PRODUCT_ID_POSITIVE_ERROR);
    }

    @ParameterizedTest
    @ValueSource(longs = {0, -1, -999})
    @DisplayName("Should throw exception for invalid brand ID values")
    void shouldThrowExceptionForInvalidBrandIdValues(Long invalidBrandId) {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_DATE_STRING;
        Long productId = TEST_PRODUCT_ID;

        // When & Then
        assertThatThrownBy(() -> validator.validateRequest(applicationDate, productId, invalidBrandId))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining(BRAND_ID_POSITIVE_ERROR);
    }

    @Test
    @DisplayName("Should validate edge case values successfully")
    void shouldValidateEdgeCaseValuesSuccessfully() {
        // Given
        PriceRequestValidator validator = new PriceRequestValidator();
        String applicationDate = VALID_EDGE_CASE_DATE;
        Long productId = MIN_VALID_ID; // Minimum valid value
        Long brandId = MAX_VALID_ID; // Maximum valid value

        // When & Then
        assertThatCode(() -> validator.validateRequest(applicationDate, productId, brandId))
            .doesNotThrowAnyException();
    }
}