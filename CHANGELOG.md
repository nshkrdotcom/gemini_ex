# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-07-20

### 🎉 Major Release - Production Ready Multi-Auth Implementation

This is a significant milestone release featuring a complete unified implementation with concurrent multi-authentication support, enhanced examples, and production-ready telemetry system.

### Added

#### 🔐 Multi-Authentication Coordinator
- **Concurrent Auth Support**: Enable simultaneous usage of Gemini API and Vertex AI authentication strategies
- **Per-request Auth Selection**: Choose authentication method on a per-request basis
- **Authentication Strategy Routing**: Automatic credential resolution and header generation
- **Enhanced Configuration**: Improved config system with better environment variable detection

#### 🌊 Unified Streaming Manager  
- **Multi-auth Streaming**: Streaming support across both authentication strategies
- **Advanced Stream Management**: Preserve excellent SSE parsing while adding auth routing
- **Stream Lifecycle Control**: Complete stream state management (start, pause, resume, stop)
- **Event Subscription System**: Enhanced event handling with proper filtering

#### 🎯 Comprehensive Examples Suite
- **`telemetry_showcase.exs`**: Complete telemetry system demonstration with 7 event types
- **Enhanced `demo.exs`**: Updated with better chat sessions and API key masking
- **Enhanced `streaming_demo.exs`**: Real-time streaming with authentication detection
- **Enhanced `multi_auth_demo.exs`**: Concurrent authentication strategies with proper error handling
- **Enhanced `demo_unified.exs`**: Multi-auth architecture showcase
- **Enhanced `live_api_test.exs`**: Comprehensive API testing for both auth methods

#### 📊 Advanced Telemetry System
- **7 Event Types**: request start/stop/exception, stream start/chunk/stop/exception  
- **Helper Functions**: Stream ID generation, content classification, metadata building
- **Performance Monitoring**: Live measurement and analysis capabilities
- **Configuration Management**: Telemetry enable/disable controls

#### 🔧 API Enhancements
- **Backward Compatibility Functions**: Added missing functions (`model_exists?`, `stream_generate`, `start_link`)
- **Response Normalization**: Proper key conversion (`totalTokens` → `total_tokens`, `displayName` → `display_name`)
- **Enhanced Error Handling**: Better error formatting and recovery
- **Content Extraction**: Support for both struct and raw streaming data formats

### Changed

#### 🏗️ Architecture Improvements
- **Type System**: Resolved module conflicts and compilation warnings
- **Configuration**: Updated default model to `gemini-2.0-flash-lite` 
- **Code Quality**: Zero compilation warnings achieved across entire codebase
- **Documentation**: Updated model references and improved examples

#### 🔄 Example Organization
- **Removed Legacy Examples**: Cleaned up `simple_test.exs`, `simple_telemetry_test.exs`, `telemetry_demo.exs`
- **Consistent Execution Pattern**: All examples use `mix run examples/[name].exs`
- **Better Error Handling**: Graceful credential failure handling with informative messages
- **Security**: API key masking in output for better security

#### 📝 Documentation Updates
- **README Enhancement**: Added comprehensive examples section with detailed descriptions
- **Model Updates**: Updated all model references to use latest Gemini 2.0 models
- **Configuration Examples**: Improved auth setup documentation
- **Usage Patterns**: Better code examples and patterns

### Fixed

#### 🐛 Critical Fixes
- **Type Module Conflicts**: Resolved duplicate module definitions preventing compilation
- **Chat Session Context**: Fixed `send_message` to properly handle `[Content.t()]` arrays
- **Streaming Debug**: Fixed undefined variables in demo scripts
- **Response Parsing**: Enhanced `build_generate_request` to support multiple content formats

#### 🔧 Minor Improvements
- **Function Coverage**: Implemented all missing backward compatibility functions
- **Token Counting**: Fixed response key normalization for proper token count extraction
- **Stream Management**: Improved stream event collection and display
- **Error Messages**: Better error formatting and user-friendly messages

### Technical Implementation

#### 🏛️ Production Architecture
- **154 Tests Passing**: Complete test coverage with zero failures
- **Multi-auth Foundation**: Robust concurrent authentication system
- **Advanced Streaming**: Real-time SSE with 30-117ms performance
- **Type Safety**: Complete `@spec` annotations and proper error handling
- **Zero Warnings**: Clean compilation across entire codebase

#### 📦 Dependencies
- Maintained stable dependency versions for production reliability
- Enhanced configuration system compatibility
- Improved telemetry integration

### Migration Guide

#### For Existing Users
```elixir
# Old single-auth pattern (still works)
{:ok, response} = Gemini.generate("Hello")

# New multi-auth capability
{:ok, gemini_response} = Gemini.generate("Hello", auth: :gemini)
{:ok, vertex_response} = Gemini.generate("Hello", auth: :vertex_ai)
```

#### Configuration Updates
```elixir
# Enhanced configuration with auto-detection
config :gemini_ex,
  default_model: "gemini-2.0-flash-lite",  # Updated default
  timeout: 30_000,
  telemetry_enabled: true  # New telemetry controls
```

### Performance

- **Real-time Streaming**: 30-117ms chunk delivery performance
- **Concurrent Authentication**: Simultaneous multi-strategy usage
- **Zero Compilation Warnings**: Optimized build performance
- **Memory Efficient**: Enhanced streaming with proper backpressure

### Security

- **Credential Masking**: API keys masked in all output for security
- **Multi-auth Isolation**: Secure credential separation between strategies
- **Error Handling**: No sensitive data in error messages

## [0.0.3] - 2025-01-07

### Fixed
- **API Response Parsing**: Fixed issue where `usage_metadata` was always nil on successful `Gemini.generate/2` calls ([#3](https://github.com/nshkrdotcom/gemini_ex/issues/3))
  - The Gemini API returns camelCase keys like `"usageMetadata"` which were not being converted to snake_case atoms
  - Updated `atomize_key` function in coordinator to properly convert camelCase strings to snake_case atoms
  - Now properly populates `usage_metadata` with token count information
- **Chat Sessions**: Fixed conversation context not being maintained between messages
  - The `send_message` function was only sending the new message, not the full conversation history
  - Now builds complete conversation history with proper role assignments before each API call
  - Ensures AI maintains context and remembers information from previous messages

## [0.0.2] - 2025-06-09

### Fixed
- **Documentation Rendering**: Fixed mermaid diagram rendering errors on hex docs by removing emoji characters from diagram labels
- **Package Links**: Removed redundant "Documentation" link in hex package configuration, keeping only "Online documentation"
- **Configuration References**: Updated TELEMETRY_IMPLEMENTATION.md to reference `:gemini_ex` instead of `:gemini` for correct application configuration

### Changed
- Improved hex docs compatibility for better rendering of documentation diagrams
- Enhanced documentation consistency across all markdown files

## [0.0.1] - 2025-06-09

### Added

#### Core Features
- **Dual Authentication System**: Support for both Gemini API keys and Vertex AI OAuth/Service Accounts
- **Advanced Streaming**: Production-grade Server-Sent Events (SSE) streaming with real-time processing
- **Comprehensive API Coverage**: Full support for Gemini API endpoints including content generation, model listing, and token counting
- **Type Safety**: Complete TypeScript-style type definitions with runtime validation
- **Error Handling**: Detailed error types with recovery suggestions and proper HTTP status code mapping
- **Built-in Telemetry**: Comprehensive observability with metrics and event tracking
- **Chat Sessions**: Multi-turn conversation management with state persistence
- **Multimodal Support**: Text, image, audio, and video content processing

#### Authentication
- Multi-strategy authentication coordinator with automatic strategy selection
- Environment variable and application configuration support
- Per-request authentication override capabilities
- Secure credential management with validation
- Support for Google Cloud Service Account JSON files
- OAuth2 Bearer token generation for Vertex AI

#### Streaming Architecture
- Unified streaming manager with state management
- Real-time SSE parsing with event dispatching
- Configurable buffer management and backpressure handling
- Stream lifecycle management (start, pause, resume, stop)
- Event subscription system with filtering capabilities
- Comprehensive error recovery and retry mechanisms

#### HTTP Client
- Dual HTTP client system (standard and streaming)
- Request/response interceptors for middleware support
- Automatic retry logic with exponential backoff
- Connection pooling and timeout management
- Request validation and response parsing
- Content-Type negotiation and encoding support

#### Type System
- Comprehensive type definitions for all API structures
- Runtime type validation with descriptive error messages
- Request and response schema validation
- Content type definitions for multimodal inputs
- Model capability and configuration types
- Error type hierarchy with actionable information

#### Configuration
- Hierarchical configuration system (runtime > environment > application)
- Environment variable detection and parsing
- Application configuration validation
- Default value management
- Configuration hot-reloading support

#### Utilities
- Content extraction helpers
- Response transformation utilities
- Validation helpers
- Debugging and logging utilities
- Performance monitoring tools

### Technical Implementation

#### Architecture
- Layered architecture with clear separation of concerns
- Behavior-driven design for pluggable components
- GenServer-based application supervision tree
- Concurrent request processing with actor model
- Event-driven streaming with backpressure management

#### Dependencies
- `req` ~> 0.4.0 for HTTP client functionality
- `jason` ~> 1.4 for JSON encoding/decoding
- `typed_struct` ~> 0.3.0 for type definitions
- `joken` ~> 2.6 for JWT handling in Vertex AI authentication
- `telemetry` ~> 1.2 for observability and metrics

#### Development Tools
- `ex_doc` for comprehensive documentation generation
- `credo` for code quality analysis
- `dialyxir` for static type analysis

### Documentation
- Complete API reference documentation
- Architecture documentation with Mermaid diagrams
- Authentication system technical specification
- Getting started guide with examples
- Advanced usage patterns and best practices
- Error handling and troubleshooting guide

### Security
- Secure credential storage and transmission
- Input validation and sanitization
- Rate limiting and throttling support
- SSL/TLS enforcement for all communications
- No sensitive data logging

### Performance
- Optimized for high-throughput scenarios
- Memory-efficient streaming implementation
- Connection reuse and pooling
- Minimal latency overhead
- Concurrent request processing

[0.1.0]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.1.0
[0.0.3]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.3
[0.0.2]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.2
[0.0.1]: https://github.com/nshkrdotcom/gemini_ex/releases/tag/v0.0.1
