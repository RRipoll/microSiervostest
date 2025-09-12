package com.testjava.priceservice.infrastructure.web.service;

import com.testjava.priceservice.infrastructure.common.Constants.DateValidation;
import com.testjava.priceservice.infrastructure.web.port.DateParsingServicePort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * Service for parsing date strings in the application-specific format.
 * Handles the conversion from the expected string format (yyyy-MM-dd-HH:mm:ss)
 * to LocalDateTime objects with proper error handling.
 */
@Slf4j
@Service
public class DateParsingService implements DateParsingServicePort {
    
    private static final String EXPECTED_FORMAT = "yyyy-MM-dd-HH:mm:ss";

    @Override
    public LocalDateTime parseApplicationDate(String dateString) {
        log.debug("Parsing date string: {}", dateString);
        
        if (dateString == null) {
            throw new IllegalArgumentException("Date string cannot be null");
        }
        
        if (dateString.trim().isEmpty()) {
            throw new IllegalArgumentException("Date string cannot be empty");
        }
        
        try {
            // Expected format: 2020-06-14-10:00:00
            String[] parts = dateString.split("-");
            if (parts.length == DateValidation.DATE_PARTS_LENGTH) {
                String year = parts[0];
                String month = parts[1];
                String day = parts[2];
                String time = parts[3];
                String isoDateTime = year + "-" + month + "-" + day + "T" + time;
                
                LocalDateTime result = LocalDateTime.parse(isoDateTime);
                log.debug("Successfully parsed date: {} -> {}", dateString, result);
                return result;
            }
            
            log.error("Invalid date format received: {}. Expected format: {}", dateString, EXPECTED_FORMAT);
            throw new IllegalArgumentException("Invalid date format: " + dateString + ". Expected format: " + EXPECTED_FORMAT);
            
        } catch (Exception e) {
            log.error("Error parsing date string '{}': {}", dateString, e.getMessage());
            throw new IllegalArgumentException("Invalid date format: " + dateString + ". Expected format: " + EXPECTED_FORMAT, e);
        }
    }

    @Override
    public String getExpectedDateFormat() {
        return EXPECTED_FORMAT;
    }
}