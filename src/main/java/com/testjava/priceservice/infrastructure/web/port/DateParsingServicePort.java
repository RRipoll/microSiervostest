package com.testjava.priceservice.infrastructure.web.port;

import java.time.LocalDateTime;

/**
 * Port interface for date parsing services.
 * Abstracts date parsing logic to allow for different parsing strategies
 * and better error handling without coupling the controller to specific parsing implementations.
 */
public interface DateParsingServicePort {
    
    /**
     * Parses a date string in the expected application format.
     * 
     * @param dateString the date string to parse (expected format: yyyy-MM-dd-HH:mm:ss)
     * @return LocalDateTime representation of the parsed date
     * @throws IllegalArgumentException if the date string cannot be parsed
     */
    LocalDateTime parseApplicationDate(String dateString);
    
    /**
     * Returns the expected date format for client documentation.
     * 
     * @return String describing the expected date format
     */
    String getExpectedDateFormat();
}