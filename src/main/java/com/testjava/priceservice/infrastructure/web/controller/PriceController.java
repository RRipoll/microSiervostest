package com.testjava.priceservice.infrastructure.web.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import com.testjava.priceservice.application.port.FindPriceUseCasePort;
import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import com.testjava.priceservice.infrastructure.web.dto.PriceResponse;
import com.testjava.priceservice.infrastructure.web.port.DateParsingServicePort;
import com.testjava.priceservice.infrastructure.web.mapper.PriceResponseMapper;
import com.testjava.priceservice.infrastructure.web.validator.PriceRequestValidator;
import com.testjava.priceservice.infrastructure.web.service.HttpRequestLogger;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

import java.time.LocalDateTime;
import java.util.Optional;

@Slf4j
@RestController
@RequestMapping("/api/prices")
@RequiredArgsConstructor
@Tag(name = "Price API", description = "API for e-commerce price consultation with time-based validity and priority rules")
public class PriceController {
    
    private final FindPriceUseCasePort findPriceUseCase;
    private final DateParsingServicePort dateParsingService;
    private final PriceResponseMapper responseMapper;
    private final PriceRequestValidator requestValidator;
    private final HttpRequestLogger requestLogger;

    @GetMapping
    @Operation(
        summary = "Get applicable price for a product",
        description = "Returns the applicable price for a specific product of a brand at a given date. " +
                     "Automatically selects the price with the highest priority when multiple prices are valid."
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200", 
            description = "Price found successfully",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = PriceResponse.class))
        ),
        @ApiResponse(
            responseCode = "404", 
            description = "No applicable price found for the given criteria",
            content = @Content
        ),
        @ApiResponse(
            responseCode = "400", 
            description = "Invalid request parameters (e.g., invalid date format)",
            content = @Content
        )
    })
    public ResponseEntity<PriceResponse> getPrice(
            @Parameter(
                name = "applicationDate", 
                description = "Date and time for price application in format yyyy-MM-dd-HH:mm:ss", 
                example = "2020-06-14-16:00:00",
                required = true
            )
            @RequestParam("applicationDate") String applicationDate,
            
            @Parameter(
                name = "productId", 
                description = "Product identifier", 
                example = "35455",
                required = true
            )
            @RequestParam("productId") Long productId,
            
            @Parameter(
                name = "brandId", 
                description = "Brand identifier (1 = ZARA)", 
                example = "1",
                required = true
            )
            @RequestParam("brandId") Long brandId) {
        
        requestLogger.logIncomingRequest(applicationDate, productId, brandId);
        
        try {
            // Validate request parameters
            requestValidator.validateRequest(applicationDate, productId, brandId);
            
            // Parse and create query
            LocalDateTime date = dateParsingService.parseApplicationDate(applicationDate);
            PriceQuery query = new PriceQuery(date, productId, brandId);
            
            // Execute use case
            Optional<PriceResult> result = findPriceUseCase.execute(query);
            
            // Handle response
            return result
                .map(responseMapper::mapToResponse)
                .map(response -> {
                    requestLogger.logSuccessfulResponse(response);
                    return ResponseEntity.ok(response);
                })
                .orElseGet(() -> {
                    requestLogger.logNotFoundResponse();
                    return ResponseEntity.notFound().build();
                });
        } catch (Exception e) {
            requestLogger.logProcessingError(e);
            throw e;
        }
    }

}