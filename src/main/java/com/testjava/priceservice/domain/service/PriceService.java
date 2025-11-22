package com.testjava.priceservice.domain.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.testjava.priceservice.application.service.PriceQueryLogger;
import com.testjava.priceservice.domain.mapper.PriceDomainMapper;
import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import com.testjava.priceservice.domain.port.PriceRepository;
import com.testjava.priceservice.domain.port.PriceServicePort;
import java.util.Optional;

@Slf4j
@RequiredArgsConstructor
public class PriceService implements PriceServicePort {
    
    private final PriceRepository priceRepository;
    private final PriceDomainMapper domainMapper;
    private final PriceQueryLogger queryLogger;

    @Override
    public Optional<PriceResult> findApplicablePrice(final PriceQuery query) {
        queryLogger.logDomainQueryDebug(query);
        
        final Optional<PriceResult> result = priceRepository
            .findApplicablePrices(query.getApplicationDate(), query.getProductId(), query.getBrandId())
            .stream()
            .findFirst()
            .map(domainMapper::mapToResult);
        
        if (result.isPresent()) {
            queryLogger.logDomainResultDebug(result.get());
        } else {
            queryLogger.logDomainNoResultDebug();
        }
        
        return result;
    }
}