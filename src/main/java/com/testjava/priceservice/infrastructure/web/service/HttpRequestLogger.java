package com.testjava.priceservice.infrastructure.web.service;

import com.testjava.priceservice.infrastructure.web.dto.PriceResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * Service responsible for logging HTTP request and response information.
 * This class has the single responsibility of handling all logging
 * concerns related to web layer operations.
 */
@Slf4j
@Component
public class HttpRequestLogger {

    /**
     * Logs incoming HTTP request parameters.
     * 
     * @param applicationDate the application date parameter
     * @param productId the product ID parameter
     * @param brandId the brand ID parameter
     */
    public void logIncomingRequest(String applicationDate, Long productId, Long brandId) {
        log.info("Received price request - date: {}, productId: {}, brandId: {}", 
                 applicationDate, productId, brandId);
    }

    /**
     * Logs successful HTTP response.
     * 
     * @param response the price response being returned
     */
    public void logSuccessfulResponse(PriceResponse response) {
        if (response != null) {
            log.info("Price request successful - returning price: {}", response.getPrice());
        } else {
            log.info("Price request successful with null response");
        }
    }

    /**
     * Logs when no price is found (404 response).
     */
    public void logNotFoundResponse() {
        log.info("Price request completed - no price found for given criteria");
    }

    /**
     * Logs HTTP request processing errors.
     * 
     * @param error the exception that occurred
     * @param applicationDate the request application date
     * @param productId the request product ID
     * @param brandId the request brand ID
     */
    public void logRequestError(Exception error, String applicationDate, Long productId, Long brandId) {
        if (error != null) {
            log.error("Error processing price request for date: {}, productId: {}, brandId: {} - Error: {}", 
                      applicationDate, productId, brandId, error.getMessage(), error);
        } else {
            log.error("Error processing price request for date: {}, productId: {}, brandId: {} - Error: null", 
                      applicationDate, productId, brandId);
        }
    }

    /**
     * Logs general HTTP processing errors.
     * 
     * @param error the exception that occurred
     */
    public void logProcessingError(Exception error) {
        if (error != null) {
            log.error("Error processing price request: {}", error.getMessage(), error);
        } else {
            log.error("Error processing price request: null error");
        }
    }
}