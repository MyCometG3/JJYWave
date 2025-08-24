//
//  ViewController.swift
//  JJYWave
//
//  Created by Takashi Mochizuki on 2025/08/19.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    // MARK: - Properties
    private var audioGenerator: JJYAudioGenerator!
    private var audioGeneratorCoordinator: AudioGeneratorCoordinator!
    private var uiDescriptionManager = UIDescriptionManager()
    private var timeUpdateTimer: Timer?
    
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
        setupTimeTimer()
    }
    
    // MARK: - Setup
    private func setupAudioGenerator() {
        audioGenerator = JJYAudioGenerator()
    }
    
    private func setupCoordinator() {
        audioGeneratorCoordinator = AudioGeneratorCoordinator(
            audioGenerator: audioGenerator,
            presentationController: self
        )
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
    }
    
    private func setupTimeTimer() {
        // Update time display immediately
        audioGeneratorCoordinator.refreshUIState()
        
        // Update time every second
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let timeDisplay = self.audioGeneratorCoordinator.uiStateManager.updateTimeDisplay()
            self.updateTimeDisplay(timeDisplay)
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
    }
    
    // MARK: - Lifecycle
    deinit {
        timeUpdateTimer?.invalidate()
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
}

// MARK: - PresentationControllerProtocol
extension ViewController: PresentationControllerProtocol {
    func updateButtonTitle(_ title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.startStopButton?.title = title
        }
    }
    
    func updateStatusMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel?.stringValue = message
        }
    }
    
    func updateTimeDisplay(_ timeString: String) {
        DispatchQueue.main.async { [weak self] in
            self?.timeLabel?.stringValue = timeString
        }
    }
    
    func updateFrequencyDisplay(_ frequencyString: String) {
        DispatchQueue.main.async { [weak self] in
            self?.frequencyLabel?.stringValue = frequencyString
        }
    }
    
    func updateSegmentSelection(_ index: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.frequencySegmentedControl?.selectedSegment = index
        }
    }
    
    func revertSegmentSelection(to index: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.frequencySegmentedControl?.selectedSegment = index
        }
    }
}
