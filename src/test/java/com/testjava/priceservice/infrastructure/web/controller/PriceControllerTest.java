package com.testjava.priceservice.infrastructure.web.controller;

import com.testjava.priceservice.application.port.FindPriceUseCasePort;
import com.testjava.priceservice.domain.model.PriceResult;
import com.testjava.priceservice.infrastructure.web.dto.PriceResponse;
import com.testjava.priceservice.infrastructure.web.exception.GlobalExceptionHandler;
import com.testjava.priceservice.infrastructure.web.mapper.PriceResponseMapper;
import com.testjava.priceservice.infrastructure.web.service.HttpRequestLogger;
import com.testjava.priceservice.infrastructure.web.validator.PriceRequestValidator;
import com.testjava.priceservice.infrastructure.web.port.DateParsingServicePort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static com.testjava.priceservice.common.TestDataFactory.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest({PriceController.class, GlobalExceptionHandler.class})
@DisplayName("Controller Tests - Price Controller")
class PriceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private FindPriceUseCasePort findPriceUseCasePort;

    @MockBean
    private PriceRequestValidator validator;

    @MockBean
    private DateParsingServicePort dateParsingService;

    @MockBean
    private PriceResponseMapper responseMapper;

    @MockBean
    private HttpRequestLogger requestLogger;

    private PriceResult mockPriceResult;
    private PriceResponse mockPriceResponse;

    @BeforeEach
    void setUp() {
        mockPriceResult = new PriceResult(
            TEST_PRODUCT_ID, TEST_BRAND_ID, TEST_PRICE_LIST_1,
            TEST_DATE_2020_06_14_16_00, TEST_DATE_2020_06_14_16_00,
            TEST_PRICE_35_50
        );

        mockPriceResponse = new PriceResponse(
            TEST_PRODUCT_ID, TEST_BRAND_ID, TEST_PRICE_LIST_1,
            TEST_DATE_2020_06_14_16_00, TEST_DATE_2020_06_14_16_00,
            TEST_PRICE_35_50
        );
    }

    @Test
    @DisplayName("Should handle missing parameters")
    void shouldHandleMissingParameters() throws Exception {
        // When & Then - Missing productId parameter
        mockMvc.perform(get("/api/prices")
                .param("applicationDate", VALID_DATE_STRING)
                .param("brandId", TEST_BRAND_ID.toString())
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest());
    }
}