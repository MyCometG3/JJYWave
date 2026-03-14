//
//  ViewController.swift
//  JJYWave
//
//  Created by Takashi Mochizuki on 2025/08/19.
//

import Cocoa
import AVFoundation

@MainActor
final class ViewController: NSViewController {
    
    // MARK: - Constants
    private enum UserDefaultsKeys {
        static let frequencyIndex = "frequencySelectedIndex"
    }
    
    // MARK: - Properties
    private var audioGenerator: JJYAudioGenerator!
    private var audioGeneratorCoordinator: AudioGeneratorCoordinator!
    private var uiDescriptionManager = UIDescriptionManager()
    private var timeUpdateTimer: Timer?
    private var spaceKeyMonitor: Any?
    private var resourcesCleanedUp = false
    
    // UI Elements
    @IBOutlet weak var startStopButton: NSButton!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var timeLabel: NSTextField!
    @IBOutlet weak var frequencyLabel: NSTextField!
    // Segmented Control は動的に生成
    private var frequencySegmentedControl: NSSegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioGenerator()
        setupCoordinator()
        setupUI()
        setupSpaceKeyMonitor()
        setupTimeTimer()
    }

    private func setupSpaceKeyMonitor() {
        spaceKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49 else { return event }
            let mask = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mask.isEmpty else { return event }
            guard let button = self?.startStopButton, button.isEnabled, button.window?.isKeyWindow == true else { return event }
            button.performClick(nil)
            return nil
        }
    }
    
    // MARK: - Setup
    private func setupAudioGenerator() {
        audioGenerator = JJYAudioGenerator()
    }
    
    private func setupCoordinator() {
        // Initialize coordinator without automatic delegate setup (weak reference pattern)
        audioGeneratorCoordinator = AudioGeneratorCoordinator(audioGenerator: audioGenerator)
        audioGeneratorCoordinator.setPresentationController(self)
        audioGeneratorCoordinator.setupAudioGeneratorDelegate()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        startStopButton?.title = NSLocalizedString("start_generation", comment: "Start button title")
        startStopButton?.bezelStyle = .rounded
        
        statusLabel?.stringValue = NSLocalizedString("ready", comment: "Initial status")
        
        setupFrequencySegmentedControl()
        audioGeneratorCoordinator.refreshUIState()
        uiDescriptionManager.updateDescriptionText(in: view)
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    private func setupFrequencySegmentedControl() {
        // Segmented Control を縦スタックに挿入し、旧水平スタックは非表示
        if let vstack = startStopButton?.superview as? NSStackView {
            // 旧の水平StackViewを非表示
            for sub in vstack.arrangedSubviews {
                if let h = sub as? NSStackView, h.orientation == .horizontal { h.isHidden = true }
            }
            // セグメント生成と挿入（Startボタンの直下に配置）
            let seg = NSSegmentedControl(labels: ["13.333 kHz", "15.000 kHz", "20.000 kHz", "40.000 kHz", "60.000 kHz"], trackingMode: .selectOne, target: self, action: #selector(frequencySegmentChanged(_:)))
            self.frequencySegmentedControl = seg
            seg.setContentHuggingPriority(.required, for: .horizontal)
            seg.setContentCompressionResistancePriority(.required, for: .horizontal)
            let arranged = vstack.arrangedSubviews
            var insertIndex = arranged.firstIndex(of: startStopButton) ?? (arranged.count - 1)
            if insertIndex < arranged.count { insertIndex += 1 }
            vstack.insertArrangedSubview(seg, at: insertIndex)
        } else if let container = startStopButton?.superview {
            // StackView でない場合のフォールバック配置（Auto Layout）
            let seg = NSSegmentedControl(labels: ["13.333 kHz", "15.000 kHz", "20.000 kHz", "40.000 kHz", "60.000 kHz"], trackingMode: .selectOne, target: self, action: #selector(frequencySegmentChanged(_:)))
            self.frequencySegmentedControl = seg
            seg.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(seg)
            NSLayoutConstraint.activate([
                seg.topAnchor.constraint(equalTo: startStopButton.bottomAnchor, constant: 8),
                seg.leadingAnchor.constraint(equalTo: startStopButton.leadingAnchor)
            ])
        }
        // Restore saved frequency selection after control is created
        let storedValue = UserDefaults.standard.object(forKey: UserDefaultsKeys.frequencyIndex)
        if let savedIndex = storedValue as? Int {
            guard (0...4).contains(savedIndex) else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.frequencyIndex)
                return
            }
            let currentIndex = audioGeneratorCoordinator.frequencyManager.getSegmentIndex(for: audioGenerator)
            audioGeneratorCoordinator.handleFrequencyChange(to: savedIndex, currentIndex: currentIndex)
        } else if storedValue != nil {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.frequencyIndex)
        }
    }
    
    private func setupTimeTimer() {
        // Update time display immediately
        audioGeneratorCoordinator.refreshUIState()
        
        // Update time every second
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let timeDisplay = self.audioGeneratorCoordinator.uiStateManager.updateTimeDisplay()
                self.updateTimeDisplay(timeDisplay)
            }
        }
    }
    
    // MARK: - Action Handlers
    @IBAction func startStopButtonTapped(_ sender: NSButton) {
        audioGeneratorCoordinator.handleStartStopAction()
    }
    
    @IBAction func frequencySegmentChanged(_ sender: NSSegmentedControl) {
        let newIndex = sender.selectedSegment
        let currentIndex = audioGeneratorCoordinator.frequencyManager.getSegmentIndex(for: audioGenerator)
        audioGeneratorCoordinator.handleFrequencyChange(to: newIndex, currentIndex: currentIndex)
        // Save only when the change was actually applied
        let appliedIndex = audioGeneratorCoordinator.frequencyManager.getSegmentIndex(for: audioGenerator)
        if appliedIndex == newIndex {
            UserDefaults.standard.set(newIndex, forKey: UserDefaultsKeys.frequencyIndex)
        }
    }
    
    // MARK: - Lifecycle
    @MainActor deinit {
        cleanupResources()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        cleanupResources()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Adjust description scroll view height
        uiDescriptionManager.adjustDescriptionScrollViewHeight(in: view, minHeight: 120)
    }
    
    // Storyboard outlet connection handling (ignore unused connections)
    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        if key == "bandButton" || key == "testModeButton" { return }
        super.setValue(value, forUndefinedKey: key)
    }

    private func cleanupResources() {
        guard !resourcesCleanedUp else { return }
        resourcesCleanedUp = true
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
        if let monitor = spaceKeyMonitor {
            NSEvent.removeMonitor(monitor)
            spaceKeyMonitor = nil
        }
    }
}

// MARK: - PresentationControllerProtocol
@MainActor
extension ViewController: @preconcurrency PresentationControllerProtocol {
    func updateButtonTitle(_ title: String) {
        startStopButton?.title = title
    }
    
    func updateStatusMessage(_ message: String) {
        statusLabel?.stringValue = message
    }
    
    func updateTimeDisplay(_ timeString: String) {
        timeLabel?.stringValue = timeString
    }
    
    func updateFrequencyDisplay(_ frequencyString: String) {
        frequencyLabel?.stringValue = frequencyString
    }
    
    func updateSegmentSelection(_ index: Int) {
        frequencySegmentedControl?.selectedSegment = index
    }
    
    func revertSegmentSelection(to index: Int) {
        frequencySegmentedControl?.selectedSegment = index
    }
}
