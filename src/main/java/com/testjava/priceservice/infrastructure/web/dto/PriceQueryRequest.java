package com.testjava.priceservice.infrastructure.web.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.testjava.priceservice.infrastructure.common.Constants.DateFormats;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PriceQueryRequest {
    
    @NotNull
    @JsonFormat(pattern = DateFormats.RESPONSE_DATE_TIME_FORMAT)
    private LocalDateTime applicationDate;
    
    @NotNull
    private Long productId;
    
    @NotNull
    private Long brandId;
}