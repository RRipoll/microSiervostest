package com.testjava.priceservice.unit.infrastructure;

import com.testjava.priceservice.common.TestCategories;
import com.testjava.priceservice.infrastructure.web.service.DateParsingService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static com.testjava.priceservice.common.TestDataFactory.*;

@Tag(UNIT_TAG)
@DisplayName("Unit Tests - Date Parsing Service")
class DateParsingServiceUnitTest implements TestCategories.UnitTest {

    private DateParsingService dateParsingService;

    @BeforeEach
    void setUp() {
        dateParsingService = new DateParsingService();
    }

    @Test
    @DisplayName("Should parse valid date string correctly")
    void shouldParseValidDateStringCorrectly() {
        // Given
        String dateString = "2020-06-14-16:00:00";

        // When
        LocalDateTime result = dateParsingService.parseApplicationDate(dateString);

        // Then
        assertThat(result).isEqualTo(LocalDateTime.of(2020, 6, 14, 16, 0, 0));
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "2020-01-01-00:00:00",
        "2020-12-31-23:59:59", 
        "2020-06-15-10:30:45"
    })
    @DisplayName("Should parse various valid date formats")
    void shouldParseVariousValidDateFormats(String dateString) {
        // When & Then
        assertThat(dateParsingService.parseApplicationDate(dateString)).isNotNull();
    }

    @ParameterizedTest
    @ValueSource(strings = {
        "invalid-date",
        "2020-13-01-10:00:00", // Invalid month
        "2020-06-32-10:00:00", // Invalid day
        "2020-06-14-25:00:00", // Invalid hour
        "2020-06-14-10:60:00", // Invalid minute
        "2020-06-14 10:00:00", // Wrong separator
        ""
    })
    @DisplayName("Should throw exception for invalid date formats")
    void shouldThrowExceptionForInvalidDateFormats(String invalidDateString) {
        // When & Then
        assertThatThrownBy(() -> dateParsingService.parseApplicationDate(invalidDateString))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    @DisplayName("Should handle null input gracefully")
    void shouldHandleNullInputGracefully() {
        // When & Then
        assertThatThrownBy(() -> dateParsingService.parseApplicationDate(null))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("Date string cannot be null");
    }

    @Test
    @DisplayName("Should return expected date format")
    void shouldReturnExpectedDateFormat() {
        // When
        String format = dateParsingService.getExpectedDateFormat();

        // Then
        assertThat(format).isEqualTo("yyyy-MM-dd-HH:mm:ss");
    }

    @Test
    @DisplayName("Should handle empty string gracefully")
    void shouldHandleEmptyStringGracefully() {
        // When & Then
        assertThatThrownBy(() -> dateParsingService.parseApplicationDate(""))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("Date string cannot be empty");
    }
}