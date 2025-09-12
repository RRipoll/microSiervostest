package com.testjava.priceservice.infrastructure.common;

/**
 * Application-wide constants to avoid duplicated literals.
 */
public final class Constants {

    private Constants() {
        // Utility class
    }

    /**
     * Date format constants used across the application.
     */
    public static final class DateFormats {
        public static final String API_DATE_TIME_FORMAT = "yyyy-MM-dd-HH:mm:ss";
        public static final String RESPONSE_DATE_TIME_FORMAT = "yyyy-MM-dd-HH.mm.ss";
        public static final String DATE_REGEX = "\\d{4}-\\d{2}-\\d{2}-\\d{2}:\\d{2}:\\d{2}";
        
        private DateFormats() {
            // Utility class
        }
    }

    /**
     * HTTP response field names.
     */
    public static final class ResponseFields {
        public static final String TIMESTAMP = "timestamp";
        public static final String STATUS = "status";
        public static final String ERROR = "error";
        public static final String MESSAGE = "message";
        public static final String PRODUCT_ID = "productId";
        public static final String BRAND_ID = "brandId";
        public static final String APPLICATION_DATE = "applicationDate";
        public static final String FIELD = "field";
        public static final String VALUE = "value";
        
        private ResponseFields() {
            // Utility class
        }
    }

    /**
     * HTTP error messages.
     */
    public static final class ErrorMessages {
        public static final String PRICE_NOT_FOUND = "Price Not Found";
        public static final String INVALID_REQUEST = "Invalid Request";
        public static final String VALIDATION_ERROR = "Validation Error";
        public static final String BUSINESS_LOGIC_ERROR = "Business Logic Error";
        public static final String INTERNAL_SERVER_ERROR = "Internal Server Error";
        public static final String UNEXPECTED_ERROR_OCCURRED = "An unexpected error occurred";
        
        private ErrorMessages() {
            // Utility class
        }
    }

    /**
     * Date/time validation constants.
     */
    public static final class DateValidation {
        public static final int DATE_PARTS_LENGTH = 4;
        public static final int PARTS_INDEX_MONTH = 1;
        public static final int PARTS_INDEX_DAY = 2;
        public static final int PARTS_INDEX_TIME = 3;
        public static final int TIME_INDEX_HOUR = 0;
        public static final int TIME_INDEX_MINUTE = 1;
        public static final int TIME_INDEX_SECOND = 2;
        
        public static final int MIN_MONTH = 1;
        public static final int MAX_MONTH = 12;
        public static final int MIN_DAY = 1;
        public static final int MAX_DAY = 31;
        public static final int MIN_HOUR = 0;
        public static final int MAX_HOUR = 23;
        public static final int MIN_MINUTE = 0;
        public static final int MAX_MINUTE = 59;
        public static final int MIN_SECOND = 0;
        public static final int MAX_SECOND = 59;
        
        private DateValidation() {
            // Utility class
        }
    }

    /**
     * Validation constants.
     */
    public static final class Validation {
        public static final int MIN_POSITIVE_VALUE = 0;
        
        private Validation() {
            // Utility class
        }
    }
}