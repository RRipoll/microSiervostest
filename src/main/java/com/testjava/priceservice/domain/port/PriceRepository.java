package com.testjava.priceservice.domain.port;

import com.testjava.priceservice.domain.model.Price;
import java.time.LocalDateTime;
import java.util.List;

public interface PriceRepository {
    
    List<Price> findApplicablePrices(LocalDateTime applicationDate, Long productId, Long brandId);
}