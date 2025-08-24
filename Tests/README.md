# JJYWave Architecture Test Suite

This directory contains comprehensive unit and integration tests for the refactored JJYAudioGenerator architecture components.

## Test Coverage

### Unit Tests

#### JJYClockTests.swift
- Tests for `JJYClock` protocol and `SystemClock` implementation
- Tests for `MockClock` functionality and timing control
- Protocol conformance and consistency validation

#### JJYFrameServiceTests.swift
- Frame construction with various configurations
- Time-based frame generation and BCD encoding validation
- Leap second plan handling and service status bits
- Calendar and time zone handling (JST)
- Edge cases and error handling

#### JJYSchedulerTests.swift
- Configuration management and propagation
- Timing coordination and scheduling accuracy
- Minute rollover and drift detection
- Frame symbol sequence validation
- Thread safety and concurrent operations

#### AudioEngineManagerTests.swift
- Audio engine setup and configuration
- Sample rate and channel count handling
- Buffer scheduling and playback control
- Hardware sample rate management
- State consistency and error handling

#### AudioBufferFactoryTests.swift (Golden Tests)
- Audio buffer generation accuracy
- Duty cycle validation for JJY symbols (Mark: 0.2s, Bit1: 0.5s, Bit0: 0.8s)
- Amplitude accuracy and waveform validation
- Carrier frequency accuracy (13.333, 15.000, 20.000, 40.000, 60.000 kHz)
- Phase continuity between buffers
- Multi-channel consistency

### Integration Tests

#### JJYArchitectureIntegrationTests.swift
- Clock and FrameService integration
- Scheduler and FrameService coordination
- Complete pipeline testing (Clock → FrameService → Scheduler → AudioEngine)
- Timing accuracy across components
- Configuration propagation through the system
- Performance and concurrency validation

#### JJYArchitectureTestSuite.swift
- Master test suite organizing all components
- Regression prevention tests
- Configuration validation across all combinations
- Memory management and performance benchmarks
- Edge case handling for all scenarios
- Backward compatibility validation

### Test Utilities

#### MockClock.swift
- Enhanced mock clock for deterministic testing
- Support for time advancement and scenario simulation
- JST time creation and leap second testing
- Debug and state inspection utilities

## Key Test Scenarios

### Configuration Testing
- All combinations of callsign, service status bits, and leap second settings
- Invalid configuration handling
- Configuration changes during operation

### Timing Testing
- Minute boundary handling and rollover
- Hour boundary transitions
- Leap second insertion and pending states
- Clock drift detection and resynchronization
- Time zone consistency (always JST)

### Audio Buffer Golden Tests
- **Mark Symbol**: 200ms high amplitude, 800ms low amplitude
- **Bit1 Symbol**: 500ms high amplitude, 500ms low amplitude  
- **Bit0 Symbol**: 800ms high amplitude, 200ms low amplitude
- **Morse Symbol**: Pattern-based amplitude modulation
- Frequency accuracy validation for all supported carriers
- Phase continuity across buffer boundaries

### Integration Scenarios
- Full system operation from clock to audio output
- Component failure recovery
- Memory management and cleanup
- Performance under load
- Thread safety with concurrent operations

## Running Tests

### In Xcode (macOS)
1. Open `JJYWave.xcodeproj` in Xcode
2. Add the test files to a new test target
3. Configure the test target to include the source files
4. Run tests with ⌘U (Cmd+U)

### Test Organization
- Unit tests focus on individual component functionality
- Integration tests validate component interactions
- Golden tests ensure audio output quality and accuracy
- Performance tests prevent regressions in timing-critical code

## Test Data Validation

### Frame Structure Validation
- 60-second frame length
- Marker positions at seconds 0, 9, 19, 29, 39, 49, 59
- Proper BCD encoding of time information
- Leap second flag encoding in positions 53-54
- Service status bits in positions 41-46

### Audio Quality Validation
- Amplitude accuracy within 0.1% tolerance
- Frequency accuracy within 5% tolerance
- Duty cycle accuracy within 1ms tolerance
- Phase continuity between consecutive buffers
- Multi-channel consistency

## Notes for Developers

### Adding New Tests
1. Create test files following the existing naming pattern
2. Use `MockClock` for deterministic timing
3. Include both positive and negative test cases
4. Add performance tests for timing-critical operations
5. Update this README with new test coverage

### Test Requirements
- All tests must be deterministic (no random failures)
- Tests should run without requiring audio hardware
- Mock dependencies to isolate component behavior
- Include comprehensive edge case coverage
- Validate both success and failure paths

### Performance Expectations
- Frame building: < 10ms per frame
- Configuration updates: < 1ms
- Buffer generation: < 5ms per second of audio
- Component initialization: < 100ms
- Memory usage should remain stable over time

This comprehensive test suite ensures the refactored JJYAudioGenerator architecture is reliable, maintainable, and free from regressions.