package com.testjava.priceservice.infrastructure.web.validator;

import com.testjava.priceservice.domain.common.ValidationMessages;
import com.testjava.priceservice.infrastructure.common.Constants.DateFormats;
import com.testjava.priceservice.infrastructure.common.Constants.DateValidation;
import com.testjava.priceservice.infrastructure.common.Constants.Validation;
import org.springframework.stereotype.Component;

/**
 * Validator responsible for validating web request parameters.
 * This class has the single responsibility of ensuring HTTP request parameters
 * meet the expected format and constraints before domain processing.
 */
@Component
public class PriceRequestValidator {

    /**
     * Validates the application date string format.
     * 
     * @param applicationDate the date string to validate
     * @throws IllegalArgumentException if validation fails
     */
    public void validateApplicationDate(final String applicationDate) {
        if (applicationDate == null || applicationDate.isBlank()) {
            throw new IllegalArgumentException(ValidationMessages.APPLICATION_DATE_REQUIRED);
        }
        
        validateDateFormat(applicationDate);
        validateDateValues(applicationDate);
    }
    
    private void validateDateFormat(final String applicationDate) {
        if (!applicationDate.matches(DateFormats.DATE_REGEX)) {
            throw new IllegalArgumentException("Application date must be in format " + DateFormats.API_DATE_TIME_FORMAT);
        }
    }
    
    private void validateDateValues(final String applicationDate) {
        try {
            final String[] parts = applicationDate.split("-");
            if (parts.length == DateValidation.DATE_PARTS_LENGTH) {
                final int month = Integer.parseInt(parts[DateValidation.PARTS_INDEX_MONTH]);
                final int day = Integer.parseInt(parts[DateValidation.PARTS_INDEX_DAY]);
                final String[] timeParts = parts[DateValidation.PARTS_INDEX_TIME].split(":");
                final int hour = Integer.parseInt(timeParts[DateValidation.TIME_INDEX_HOUR]);
                final int minute = Integer.parseInt(timeParts[DateValidation.TIME_INDEX_MINUTE]);
                final int second = Integer.parseInt(timeParts[DateValidation.TIME_INDEX_SECOND]);
                
                validateDateComponents(month, day, hour, minute, second);
            }
        } catch (NumberFormatException | ArrayIndexOutOfBoundsException ignored) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_DATE_FORMAT_VALUES, ignored);
        }
    }
    
    private void validateDateComponents(final int month, final int day, final int hour, final int minute, final int second) {
        final int minMonth = DateValidation.MIN_MONTH;
        final int maxMonth = DateValidation.MAX_MONTH;
        final int minDay = DateValidation.MIN_DAY;
        final int maxDay = DateValidation.MAX_DAY;
        final int minHour = DateValidation.MIN_HOUR;
        final int maxHour = DateValidation.MAX_HOUR;
        final int minMinute = DateValidation.MIN_MINUTE;
        final int maxMinute = DateValidation.MAX_MINUTE;
        final int minSecond = DateValidation.MIN_SECOND;
        final int maxSecond = DateValidation.MAX_SECOND;
        
        if (month < minMonth || month > maxMonth) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_MONTH_VALUE + month);
        }
        if (day < minDay || day > maxDay) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_DAY_VALUE + day);
        }
        if (hour < minHour || hour > maxHour) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_HOUR_VALUE + hour);
        }
        if (minute < minMinute || minute > maxMinute) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_MINUTE_VALUE + minute);
        }
        if (second < minSecond || second > maxSecond) {
            throw new IllegalArgumentException(ValidationMessages.INVALID_SECOND_VALUE + second);
        }
    }

    /**
     * Validates the product ID parameter.
     * 
     * @param productId the product ID to validate
     * @throws IllegalArgumentException if validation fails
     */
    public void validateProductId(final Long productId) {
        if (productId == null) {
            throw new IllegalArgumentException(ValidationMessages.PRODUCT_ID_CANNOT_BE_NULL);
        }
        
        if (productId <= Validation.MIN_POSITIVE_VALUE) {
            throw new IllegalArgumentException(ValidationMessages.PRODUCT_ID_POSITIVE);
        }
    }

    /**
     * Validates the brand ID parameter.
     * 
     * @param brandId the brand ID to validate
     * @throws IllegalArgumentException if validation fails
     */
    public void validateBrandId(final Long brandId) {
        if (brandId == null) {
            throw new IllegalArgumentException(ValidationMessages.BRAND_ID_CANNOT_BE_NULL);
        }
        
        if (brandId <= Validation.MIN_POSITIVE_VALUE) {
            throw new IllegalArgumentException(ValidationMessages.BRAND_ID_POSITIVE);
        }
    }

    /**
     * Validates all request parameters together.
     * 
     * @param applicationDate the application date string
     * @param productId the product ID
     * @param brandId the brand ID
     * @throws IllegalArgumentException if any validation fails
     */
    public void validateRequest(final String applicationDate, final Long productId, final Long brandId) {
        validateApplicationDate(applicationDate);
        validateProductId(productId);
        validateBrandId(brandId);
    }
}