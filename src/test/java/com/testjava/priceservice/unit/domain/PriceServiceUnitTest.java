package com.testjava.priceservice.unit.domain;

import com.testjava.priceservice.application.service.PriceQueryLogger;
import com.testjava.priceservice.common.TestCategories;
import com.testjava.priceservice.common.TestDataFactory;
import com.testjava.priceservice.domain.mapper.PriceDomainMapper;
import com.testjava.priceservice.domain.model.Price;
import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import com.testjava.priceservice.domain.port.PriceRepository;
import com.testjava.priceservice.domain.service.PriceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static com.testjava.priceservice.common.TestDataFactory.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@Tag(UNIT_TAG)
@DisplayName("Unit Tests - Price Service")
class PriceServiceUnitTest implements TestCategories.UnitTest {

    @Mock
    private PriceRepository priceRepository;

    @Mock
    private PriceDomainMapper domainMapper;

    @Mock
    private PriceQueryLogger queryLogger;

    private PriceService priceService;

    @BeforeEach
    void setUp() {
        priceService = new PriceService(priceRepository, domainMapper, queryLogger);
    }

    @Test
    @DisplayName("Should return price result when highest priority price found")
    void shouldReturnPriceResultWhenHighestPriorityPriceFound() {
        // Given
        PriceQuery query = TestDataFactory.createTestQuery();
        Price highestPriorityPrice = TestDataFactory.createTestPrice(2, 1, TEST_PRICE_25_45);
        PriceResult expectedResult = TestDataFactory.createTestPriceResult();

        when(priceRepository.findApplicablePrices(
            query.getApplicationDate(), 
            query.getProductId(), 
            query.getBrandId())
        ).thenReturn(Arrays.asList(highestPriorityPrice));

        when(domainMapper.mapToResult(highestPriorityPrice))
            .thenReturn(expectedResult);

        // When
        Optional<PriceResult> result = priceService.findApplicablePrice(query);

        // Then
        assertThat(result).isPresent();
        assertThat(result.get()).isEqualTo(expectedResult);

        verify(queryLogger).logDomainQueryDebug(query);
        verify(queryLogger).logDomainResultDebug(expectedResult);
        verify(priceRepository).findApplicablePrices(
            query.getApplicationDate(), 
            query.getProductId(), 
            query.getBrandId()
        );
        verify(domainMapper).mapToResult(highestPriorityPrice);
    }

    @Test
    @DisplayName("Should return empty when no prices found")
    void shouldReturnEmptyWhenNoPricesFound() {
        // Given
        PriceQuery query = TestDataFactory.createTestQuery();

        when(priceRepository.findApplicablePrices(
            query.getApplicationDate(), 
            query.getProductId(), 
            query.getBrandId())
        ).thenReturn(Collections.emptyList());

        // When
        Optional<PriceResult> result = priceService.findApplicablePrice(query);

        // Then
        assertThat(result).isEmpty();

        verify(queryLogger).logDomainQueryDebug(query);
        verify(queryLogger).logDomainNoResultDebug();
        verify(priceRepository).findApplicablePrices(
            query.getApplicationDate(), 
            query.getProductId(), 
            query.getBrandId()
        );
        verifyNoInteractions(domainMapper);
    }

    @Test
    @DisplayName("Should return first price when database query returns single result")
    void shouldReturnFirstPriceWhenDatabaseQueryReturnsSingleResult() {
        // Given
        PriceQuery query = TestDataFactory.createTestQuery();
        Price price = TestDataFactory.createTestPrice();
        PriceResult expectedResult = TestDataFactory.createTestPriceResult();

        when(priceRepository.findApplicablePrices(
            query.getApplicationDate(), 
            query.getProductId(), 
            query.getBrandId())
        ).thenReturn(Arrays.asList(price));

        when(domainMapper.mapToResult(price)).thenReturn(expectedResult);

        // When
        Optional<PriceResult> result = priceService.findApplicablePrice(query);

        // Then
        assertThat(result).isPresent();
        assertThat(result.get()).isEqualTo(expectedResult);

        verify(queryLogger).logDomainQueryDebug(query);
        verify(queryLogger).logDomainResultDebug(expectedResult);
    }
}