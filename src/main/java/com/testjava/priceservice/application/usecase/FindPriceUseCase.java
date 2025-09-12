package com.testjava.priceservice.application.usecase;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.testjava.priceservice.application.port.FindPriceUseCasePort;
import com.testjava.priceservice.application.service.PriceQueryLogger;
import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import com.testjava.priceservice.domain.port.PriceServicePort;
import com.testjava.priceservice.domain.validator.PriceQueryValidator;
import org.springframework.stereotype.Service;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class FindPriceUseCase implements FindPriceUseCasePort {
    
    private final PriceServicePort priceService;
    private final PriceQueryValidator queryValidator;
    private final PriceQueryLogger queryLogger;

    @Override
    public Optional<PriceResult> execute(final PriceQuery query) {
        // Log query start
        queryLogger.logQueryStart(query);
        
        // Validate domain query
        queryValidator.validate(query);
        
        // Execute domain service
        final Optional<PriceResult> result = priceService.findApplicablePrice(query);
        
        // Log result
        queryLogger.logQueryResult(query, result);
        
        return result;
    }
}