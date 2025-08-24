import XCTest
@testable import JJYWave

class FrequencyManagementServiceTests: XCTestCase {
    var frequencyService: FrequencyManagementService!
    var mockAudioGenerator: MockJJYAudioGenerator!
    
    override func setUp() {
        super.setUp()
        frequencyService = FrequencyManagementService()
        mockAudioGenerator = MockJJYAudioGenerator()
    }
    
    override func tearDown() {
        frequencyService = nil
        mockAudioGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Segment Index Tests
    
    func testGetSegmentIndexForTestMode13kHz() {
        mockAudioGenerator.isTestModeEnabled = true
        mockAudioGenerator.testFrequency = 13333
        
        let index = frequencyService.getSegmentIndex(for: mockAudioGenerator)
        
        XCTAssertEqual(index, 0, "13.333 kHz should return segment index 0")
    }
    
    func testGetSegmentIndexForTestMode15kHz() {
        mockAudioGenerator.isTestModeEnabled = true
        mockAudioGenerator.testFrequency = 15000
        
        let index = frequencyService.getSegmentIndex(for: mockAudioGenerator)
        
        XCTAssertEqual(index, 1, "15.000 kHz should return segment index 1")
    }
    
    func testGetSegmentIndexForTestMode20kHz() {
        mockAudioGenerator.isTestModeEnabled = true
        mockAudioGenerator.testFrequency = 20000
        
        let index = frequencyService.getSegmentIndex(for: mockAudioGenerator)
        
        XCTAssertEqual(index, 2, "20.000 kHz should return segment index 2")
    }
    
    func testGetSegmentIndexForJJY40() {
        mockAudioGenerator.isTestModeEnabled = false
        mockAudioGenerator.band = .jjy40
        
        let index = frequencyService.getSegmentIndex(for: mockAudioGenerator)
        
        XCTAssertEqual(index, 3, "JJY40 should return segment index 3")
    }
    
    func testGetSegmentIndexForJJY60() {
        mockAudioGenerator.isTestModeEnabled = false
        mockAudioGenerator.band = .jjy60
        
        let index = frequencyService.getSegmentIndex(for: mockAudioGenerator)
        
        XCTAssertEqual(index, 4, "JJY60 should return segment index 4")
    }
    
    // MARK: - Frequency Change Validation Tests
    
    func testValidateFrequencyChangeAllowedForTestFrequencies() {
        let result1 = frequencyService.validateFrequencyChange(from: 0, to: 1, isGenerating: false)
        let result2 = frequencyService.validateFrequencyChange(from: 1, to: 2, isGenerating: true)
        
        XCTAssertTrue(result1.isAllowed, "Test frequency changes should be allowed when not generating")
        XCTAssertTrue(result2.isAllowed, "Test frequency changes should be allowed even when generating")
    }
    
    func testValidateFrequencyChangeBlockedForJJYWhileGenerating() {
        let result40 = frequencyService.validateFrequencyChange(from: 0, to: 3, isGenerating: true)
        let result60 = frequencyService.validateFrequencyChange(from: 0, to: 4, isGenerating: true)
        
        XCTAssertFalse(result40.isAllowed, "JJY40 change should be blocked while generating")
        XCTAssertFalse(result60.isAllowed, "JJY60 change should be blocked while generating")
        XCTAssertNotNil(result40.errorMessage, "Should provide error message for blocked change")
        XCTAssertNotNil(result60.errorMessage, "Should provide error message for blocked change")
    }
    
    func testValidateFrequencyChangeAllowedForJJYWhileNotGenerating() {
        let result40 = frequencyService.validateFrequencyChange(from: 0, to: 3, isGenerating: false)
        let result60 = frequencyService.validateFrequencyChange(from: 0, to: 4, isGenerating: false)
        
        XCTAssertTrue(result40.isAllowed, "JJY40 change should be allowed when not generating")
        XCTAssertTrue(result60.isAllowed, "JJY60 change should be allowed when not generating")
    }
    
    // MARK: - Frequency Formatting Tests
    
    func testFormatTestFrequency() {
        let formatted13k = frequencyService.formatTestFrequency(13333)
        let formatted15k = frequencyService.formatTestFrequency(15000)
        let formatted20k = frequencyService.formatTestFrequency(20000)
        
        XCTAssertEqual(formatted13k, "13.333 kHz", "13333 Hz should format as 13.333 kHz")
        XCTAssertEqual(formatted15k, "15.000 kHz", "15000 Hz should format as 15.000 kHz")
        XCTAssertEqual(formatted20k, "20.000 kHz", "20000 Hz should format as 20.000 kHz")
    }
    
    func testFormatFrequencyDisplayForTestMode() {
        mockAudioGenerator.isTestModeEnabled = true
        mockAudioGenerator.testFrequency = 13333
        mockAudioGenerator.sampleRate = 96000
        
        let display = frequencyService.formatFrequencyDisplay(for: mockAudioGenerator)
        
        XCTAssertTrue(display.contains("13.333 kHz"), "Should contain test frequency")
        XCTAssertTrue(display.contains("96"), "Should contain sample rate in kHz")
    }
    
    func testFormatFrequencyDisplayForJJYMode() {
        mockAudioGenerator.isTestModeEnabled = false
        mockAudioGenerator.band = .jjy40
        mockAudioGenerator.sampleRate = 96000
        
        let display = frequencyService.formatFrequencyDisplay(for: mockAudioGenerator)
        
        XCTAssertTrue(display.contains("40.000 kHz"), "Should contain JJY40 frequency")
        XCTAssertTrue(display.contains("96"), "Should contain sample rate in kHz")
    }
}

// MARK: - Mock JJYAudioGenerator
class MockJJYAudioGenerator {
    var isTestModeEnabled: Bool = true
    var testFrequency: Double = 13333
    var band: JJYAudioGenerator.CarrierBand = .jjy40
    var sampleRate: Double = 96000
    var isActive: Bool = false
    
    func updateTestFrequency(_ frequency: Double) {
        testFrequency = frequency
    }
    
    func updateBand(_ newBand: JJYAudioGenerator.CarrierBand) -> Bool {
        band = newBand
        return true
    }
}