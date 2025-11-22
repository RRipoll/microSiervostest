package com.testjava.priceservice.application.service;

import com.testjava.priceservice.domain.model.PriceQuery;
import com.testjava.priceservice.domain.model.PriceResult;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Service responsible for logging price query operations.
 * This class has the single responsibility of handling all logging
 * concerns related to price queries and results.
 */
@Slf4j
@Component
public class PriceQueryLogger {

    /**
     * Logs the start of a price query execution.
     * 
     * @param query the price query being executed
     */
    public void logQueryStart(PriceQuery query) {
        if (query != null) {
            log.info("Executing price lookup for productId={}, brandId={}, date={}", 
                     query.getProductId(), query.getBrandId(), query.getApplicationDate());
        } else {
            log.info("Executing price lookup with null query");
        }
    }

    /**
     * Logs a successful price query result.
     * 
     * @param result the successful price result
     */
    public void logQuerySuccess(PriceResult result) {
        if (result != null) {
            log.info("Price lookup successful: found price={} for priceList={}", 
                     result.getPrice(), result.getPriceList());
        } else {
            log.info("Price lookup successful with null result");
        }
    }

    /**
     * Logs when no price is found for a query.
     * 
     * @param query the query that returned no results
     */
    public void logQueryNotFound(PriceQuery query) {
        if (query != null) {
            log.warn("Price lookup failed: no applicable price found for productId={}, brandId={}", 
                     query.getProductId(), query.getBrandId());
        } else {
            log.warn("Price lookup failed with null query");
        }
    }

    /**
     * Logs the complete query execution result.
     * 
     * @param query the executed query
     * @param result the query result (may be empty)
     */
    public void logQueryResult(PriceQuery query, Optional<PriceResult> result) {
        if (result != null && result.isPresent()) {
            logQuerySuccess(result.get());
        } else if (query != null) {
            logQueryNotFound(query);
        } else {
            log.warn("Price lookup completed with null parameters");
        }
    }

    /**
     * Logs debug information about domain price finding.
     * 
     * @param query the price query
     */
    public void logDomainQueryDebug(PriceQuery query) {
        if (query != null) {
            log.debug("Finding applicable price for query: productId={}, brandId={}, applicationDate={}", 
                      query.getProductId(), query.getBrandId(), query.getApplicationDate());
        } else {
            log.debug("Finding applicable price for null query");
        }
    }

    /**
     * Logs debug information about successful price finding.
     * 
     * @param result the found price result
     */
    public void logDomainResultDebug(PriceResult result) {
        if (result != null) {
            log.debug("Found applicable price: priceList={}, price={}", 
                      result.getPriceList(), result.getPrice());
        } else {
            log.debug("Found applicable price: null result");
        }
    }

    /**
     * Logs debug information when no price is found.
     */
    public void logDomainNoResultDebug() {
        log.debug("No applicable price found for the given criteria");
    }
}