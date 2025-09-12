package com.testjava.priceservice.infrastructure.persistence.adapter;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.testjava.priceservice.domain.model.Price;
import com.testjava.priceservice.domain.port.PriceRepository;
import com.testjava.priceservice.infrastructure.persistence.entity.PriceEntity;
import com.testjava.priceservice.infrastructure.persistence.mapper.PriceEntityMapper;
import com.testjava.priceservice.infrastructure.persistence.repository.JpaPriceRepository;
import org.springframework.stereotype.Component;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class PriceRepositoryAdapter implements PriceRepository {
    
    private final JpaPriceRepository jpaPriceRepository;
    private final PriceEntityMapper entityMapper;

    @Override
    public List<Price> findApplicablePrices(LocalDateTime applicationDate, Long productId, Long brandId) {
        log.debug("Searching for applicable prices - date: {}, productId: {}, brandId: {}", 
                  applicationDate, productId, brandId);
        
        List<PriceEntity> entities = jpaPriceRepository.findApplicablePrices(applicationDate, productId, brandId);
        
        log.debug("Found {} price entities with highest priority in database", entities.size());
        
        return entities.stream()
                .map(entityMapper::mapToDomain)
                .collect(Collectors.toList());
    }
}