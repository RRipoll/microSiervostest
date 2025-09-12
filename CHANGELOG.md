# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-09-08

### Added
- Initial SpringBoot 3.2.0 application with Java 17
- Hexagonal architecture implementation with DDD principles
- REST API endpoint for price queries (`GET /api/prices`)
- H2 in-memory database with sample data
- Comprehensive test suite (45+ tests) covering all layers
- Swagger/OpenAPI 3 interactive documentation
- Database configuration with environment variable support
- Gradle build system with proper dependency management
- Enhanced test architecture with comprehensive test organization
- Performance testing framework with concurrent load testing
- Improved test coverage reporting and analysis
- Quality gates and build verification processes
- Test categorization system for better organization
- Database integration tests for data layer validation

### API Endpoints
- `GET /api/prices` - Query prices with parameters:
  - `applicationDate` (yyyy-MM-dd-HH:mm:ss format)
  - `productId` (numeric)
  - `brandId` (numeric)

### Documentation
- Interactive Swagger UI at `/swagger-ui.html`
- OpenAPI specification at `/api-docs`
- H2 console at `/h2-console`

### Configuration
- Environment variables: `TESTJAVA_DB_USERNAME`, `TESTJAVA_DB_PASSWORD`
- Default database credentials: sa/password (development only)
- Application runs on port 8082
- Logging configured at DEBUG level for development

### Technical Details
- **Framework**: Spring Boot 3.2.0
- **Language**: Java 17
- **Database**: H2 in-memory
- **Build Tool**: Gradle 8.4
- **Testing**: JUnit 5 with Mockito
- **Documentation**: Swagger/OpenAPI 3
- **Architecture**: Hexagonal (Ports & Adapters)

### Sample Test Scenarios
1. **Test 1**: 2020-06-14 10:00 → Price 35.50€ (Priority 0)
2. **Test 2**: 2020-06-14 16:00 → Price 25.45€ (Priority 1)
3. **Test 3**: 2020-06-14 21:00 → Price 35.50€ (Priority 0)
4. **Test 4**: 2020-06-15 10:00 → Price 30.50€ (Priority 1)
5. **Test 5**: 2020-06-16 21:00 → Price 38.95€ (Priority 1)

### Enhanced Test Coverage
- **Unit Tests**: 90 tests covering all business logic layers
- **Integration Tests**: 7 focused database integration tests
- **Performance Tests**: Load testing with concurrent request validation
- **Test Categories**: Organized tests by type (unit, integration, performance)
- **Coverage Target**: Maintained 100% test success rate

