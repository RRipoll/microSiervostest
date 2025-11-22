package com.testjava.priceservice.infrastructure.web.dto;

import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

class PriceQueryRequestTest {

    @Test
    void shouldCreatePriceQueryRequestWithAllFields() {
        // Given
        LocalDateTime applicationDate = LocalDateTime.of(2020, 6, 14, 16, 0);
        
        // When
        PriceQueryRequest request = new PriceQueryRequest(applicationDate, 35455L, 1L);
        
        // Then
        assertEquals(applicationDate, request.getApplicationDate());
        assertEquals(35455L, request.getProductId());
        assertEquals(1L, request.getBrandId());
    }

    @Test
    void shouldAllowSettingAllFields() {
        // Given
        PriceQueryRequest request = new PriceQueryRequest();
        LocalDateTime applicationDate = LocalDateTime.of(2020, 6, 15, 10, 0);
        
        // When
        request.setApplicationDate(applicationDate);
        request.setProductId(35455L);
        request.setBrandId(1L);
        
        // Then
        assertEquals(applicationDate, request.getApplicationDate());
        assertEquals(35455L, request.getProductId());
        assertEquals(1L, request.getBrandId());
    }
}