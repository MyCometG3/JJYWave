import XCTest
import AVFoundation
@testable import JJYWave

class AudioEngineProtocolTests: XCTestCase {
    var mockAudioEngine: MockAudioEngine!
    var realAudioEngine: AudioEngine!
    
    override func setUp() {
        super.setUp()
        mockAudioEngine = MockAudioEngine()
        realAudioEngine = AudioEngine()
    }
    
    override func tearDown() {
        mockAudioEngine = nil
        realAudioEngine = nil
        super.tearDown()
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testAudioEngineConformsToProtocol() {
        // Verify that AudioEngine conforms to AudioEngineProtocol
        XCTAssertNotNil(realAudioEngine, "AudioEngine should be initialized")
        XCTAssertTrue(realAudioEngine is AudioEngineProtocol, "AudioEngine should conform to AudioEngineProtocol")
    }
    
    func testMockAudioEngineConformsToProtocol() {
        // Verify that mock also conforms to the protocol
        XCTAssertNotNil(mockAudioEngine, "MockAudioEngine should be initialized")
        XCTAssertTrue(mockAudioEngine is AudioEngineProtocol, "MockAudioEngine should conform to AudioEngineProtocol")
    }
    
    // MARK: - Mock Audio Engine Tests
    
    func testMockAudioEngineInitialState() {
        XCTAssertFalse(mockAudioEngine.isEngineRunning, "Mock engine should not be running initially")
        XCTAssertFalse(mockAudioEngine.isPlayerPlaying, "Mock player should not be playing initially")
    }
    
    func testMockAudioEngineSetup() {
        mockAudioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        XCTAssertTrue(mockAudioEngine.setupWasCalled, "Setup should be called")
        XCTAssertEqual(mockAudioEngine.lastSampleRate, 96000, "Should record sample rate")
        XCTAssertEqual(mockAudioEngine.lastChannelCount, 2, "Should record channel count")
    }
    
    func testMockAudioEngineStartStop() {
        let success = mockAudioEngine.startEngine()
        XCTAssertTrue(success, "Start engine should succeed")
        XCTAssertTrue(mockAudioEngine.startEngineWasCalled, "Start engine should be called")
        
        mockAudioEngine.startPlayer()
        XCTAssertTrue(mockAudioEngine.startPlayerWasCalled, "Start player should be called")
        
        mockAudioEngine.stopPlayer()
        XCTAssertTrue(mockAudioEngine.stopPlayerWasCalled, "Stop player should be called")
        
        mockAudioEngine.stopEngine()
        XCTAssertTrue(mockAudioEngine.stopEngineWasCalled, "Stop engine should be called")
    }
    
    func testMockAudioEngineScheduleBuffer() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        
        mockAudioEngine.scheduleBuffer(buffer, at: nil, completionHandler: nil)
        
        XCTAssertTrue(mockAudioEngine.scheduleBufferWasCalled, "Schedule buffer should be called")
    }
    
    // MARK: - Dependency Injection Tests
    
    func testJJYAudioGeneratorWithMockAudioEngine() {
        // Test that JJYAudioGenerator can accept a mock audio engine
        let generator = JJYAudioGenerator(audioEngine: mockAudioEngine)
        
        XCTAssertNotNil(generator, "Should be able to create audio generator with mock engine")
        
        // Test that setup is called during initialization
        XCTAssertTrue(mockAudioEngine.setupWasCalled, "Audio engine setup should be called during generator initialization")
    }
}

// MARK: - Mock Audio Engine Implementation
class MockAudioEngine: AudioEngineProtocol {
    // State tracking
    private var _isEngineRunning = false
    private var _isPlayerPlaying = false
    
    // Call tracking
    var setupWasCalled = false
    var startEngineWasCalled = false
    var stopEngineWasCalled = false
    var startPlayerWasCalled = false
    var stopPlayerWasCalled = false
    var scheduleBufferWasCalled = false
    
    // Parameter tracking
    var lastSampleRate: Double?
    var lastChannelCount: AVAudioChannelCount?
    
    // MARK: - AudioEngineProtocol Implementation
    
    var isEngineRunning: Bool {
        return _isEngineRunning
    }
    
    var isPlayerPlaying: Bool {
        return _isPlayerPlaying
    }
    
    func setupAudioEngine(sampleRate: Double, channelCount: AVAudioChannelCount) {
        setupWasCalled = true
        lastSampleRate = sampleRate
        lastChannelCount = channelCount
    }
    
    func startEngine() -> Bool {
        startEngineWasCalled = true
        _isEngineRunning = true
        return true
    }
    
    func stopEngine() {
        stopEngineWasCalled = true
        _isEngineRunning = false
        _isPlayerPlaying = false
    }
    
    func startPlayer() {
        startPlayerWasCalled = true
        _isPlayerPlaying = true
    }
    
    func stopPlayer() {
        stopPlayerWasCalled = true
        _isPlayerPlaying = false
    }
    
    func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, completionHandler: AVAudioNodeCompletionHandler?) {
        scheduleBufferWasCalled = true
        // Call completion handler immediately for testing
        completionHandler?()
    }
    
    func trySetHardwareSampleRate(_ desired: Double) -> Bool {
        // Mock implementation always succeeds
        return true
    }
    
    func getPlayerFormat() -> AVAudioFormat? {
        // Return a mock format for testing
        return AVAudioFormat(standardFormatWithSampleRate: 96000, channels: 2)
    }
}

// MARK: - Integration Tests with Real AudioEngine
class AudioEngineIntegrationTests: XCTestCase {
    var audioEngine: AudioEngine!
    
    override func setUp() {
        super.setUp()
        audioEngine = AudioEngine()
    }
    
    override func tearDown() {
        audioEngine?.stopEngine()
        audioEngine = nil
        super.tearDown()
    }
    
    func testAudioEngineBasicLifecycle() {
        // Initial state
        XCTAssertFalse(audioEngine.isEngineRunning, "Engine should not be running initially")
        XCTAssertFalse(audioEngine.isPlayerPlaying, "Player should not be playing initially")
        
        // Setup
        audioEngine.setupAudioEngine(sampleRate: 96000, channelCount: 2)
        
        // Note: We don't test actual audio engine start/stop in CI environment
        // as it requires audio hardware access
    }
}