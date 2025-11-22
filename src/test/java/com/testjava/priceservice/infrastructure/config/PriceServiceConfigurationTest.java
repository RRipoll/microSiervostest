package com.testjava.priceservice.infrastructure.config;

import com.testjava.priceservice.application.service.PriceQueryLogger;
import com.testjava.priceservice.domain.mapper.PriceDomainMapper;
import com.testjava.priceservice.domain.port.PriceRepository;
import com.testjava.priceservice.domain.port.PriceServicePort;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class PriceServiceConfigurationTest {

    @Test
    void shouldCreatePriceServiceBean() {
        // Given
        PriceServiceConfiguration config = new PriceServiceConfiguration();
        PriceRepository mockRepository = mock(PriceRepository.class);
        PriceDomainMapper mockMapper = mock(PriceDomainMapper.class);
        PriceQueryLogger mockLogger = mock(PriceQueryLogger.class);
        
        // When
        PriceServicePort priceService = config.priceService(mockRepository, mockMapper, mockLogger);
        
        // Then
        assertNotNull(priceService);
    }
}