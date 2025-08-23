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
    private var previousSelectedIndex: Int = 0
    
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
        setupUI()
        updateTimeDisplay()
        
        // Update time every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimeDisplay()
        }
    }
    
    // MARK: - Setup
    private func setupAudioGenerator() {
        audioGenerator = JJYAudioGenerator()
        audioGenerator.delegate = self
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        startStopButton?.title = NSLocalizedString("start_generation", comment: "Start button title")
        startStopButton?.bezelStyle = .rounded
        
        statusLabel?.stringValue = NSLocalizedString("ready", comment: "Initial status")
        
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
        
        syncSegmentSelectionFromState()
        updateFrequencyLabel()
        updateDescriptionTextIfNeeded()
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    private func updateDescriptionTextIfNeeded() {
        // View階層から最初のNSTextViewを探し、説明文を現状に合わせて更新
        func findTextView(in view: NSView) -> NSTextView? {
            for sub in view.subviews {
                if let tv = sub as? NSTextView { return tv }
                if let tv = findTextView(in: sub) { return tv }
            }
            return nil
        }
        guard let textView = findTextView(in: self.view) else { return }
        let newText = NSLocalizedString("app_description", comment: "App description text")
        textView.string = newText
        textView.textColor = .secondaryLabelColor
        textView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    
    private func syncSegmentSelectionFromState() {
        guard frequencySegmentedControl != nil else { return }
        // 現在状態から選択インデックスを決定
        let idx: Int
        if audioGenerator.isTestModeEnabled {
            let tf = audioGenerator.testFrequency
            if abs(tf - 13333) < 0.5 { idx = 0 }
            else if abs(tf - 15000) < 0.5 { idx = 1 }
            else if abs(tf - 20000) < 0.5 { idx = 2 }
            else { idx = 0 }
        } else {
            idx = (audioGenerator.band == .jjy60) ? 4 : 3
        }
        frequencySegmentedControl.selectedSegment = idx
        previousSelectedIndex = idx
    }
    
    private func formatTestFreqKHz() -> String {
        let khz = audioGenerator.testFrequency / 1000.0
        return String(format: "%.3f", khz)
    }
    
    private func updateFrequencyLabel() {
        let freqText: String
        if audioGenerator.isTestModeEnabled {
            let suffix = NSLocalizedString("test_mode_suffix", comment: "Test mode suffix")
            freqText = "\(formatTestFreqKHz()) kHz (\(suffix))"
        } else {
            let jjy60 = NSLocalizedString("jjy60_label", comment: "JJY60 label")
            let jjy40 = NSLocalizedString("jjy40_label", comment: "JJY40 label")
            freqText = (audioGenerator.band == .jjy60) ? "60.000 kHz (\(jjy60))" : "40.000 kHz (\(jjy40))"
        }
        let srK = Int((audioGenerator.sampleRate / 1000.0).rounded())
        let format = NSLocalizedString("frequency_display_format", comment: "Frequency label format")
        frequencyLabel?.stringValue = String(format: format, freqText, srK)
    }
    
    private func updateTimeDisplay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let format = NSLocalizedString("current_time_format", comment: "Current time label format")
        timeLabel?.stringValue = String(format: format, formatter.string(from: Date()))
    }
    
    // MARK: - JJY40 Signal Generation
    @IBAction func startStopButtonTapped(_ sender: NSButton) {
        if audioGenerator.isActive {
            audioGenerator.stopGeneration()
        } else {
            audioGenerator.startGeneration()
        }
    }
    
    // MARK: - Frequency Segmented Control
    @IBAction func frequencySegmentChanged(_ sender: NSSegmentedControl) {
        let idx = sender.selectedSegment
        switch idx {
        case 0: // 13.333 kHz Test
            audioGenerator.isTestModeEnabled = true
            audioGenerator.updateTestFrequency(13333)
        case 1: // 15.000 kHz Test
            audioGenerator.isTestModeEnabled = true
            audioGenerator.updateTestFrequency(15000)
        case 2: // 20.000 kHz Test
            audioGenerator.isTestModeEnabled = true
            audioGenerator.updateTestFrequency(20000)
        case 3: // JJY40 40 kHz
            if audioGenerator.isActive {
                statusLabel?.stringValue = NSLocalizedString("change_to_jjy40_blocked", comment: "Block switching to 40 kHz while active")
                sender.selectedSegment = previousSelectedIndex
                return
            }
            audioGenerator.isTestModeEnabled = false
            _ = audioGenerator.updateBand(.jjy40)
        case 4: // JJY60 60 kHz
            if audioGenerator.isActive {
                statusLabel?.stringValue = NSLocalizedString("change_to_jjy60_blocked", comment: "Block switching to 60 kHz while active")
                sender.selectedSegment = previousSelectedIndex
                return
            }
            audioGenerator.isTestModeEnabled = false
            _ = audioGenerator.updateBand(.jjy60)
        default:
            break
        }
        previousSelectedIndex = sender.selectedSegment
        updateFrequencyLabel()
    }
    
    // Storyboardの不要Outlet接続を無視（bandButton/testModeButton）
    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        if key == "bandButton" || key == "testModeButton" { return }
        super.setValue(value, forUndefinedKey: key)
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // 説明欄スクロールビューの高さを拡大（最小120）
        adjustDescriptionScrollViewHeight(minHeight: 120)
    }
    
    private func adjustDescriptionScrollViewHeight(minHeight: CGFloat) {
        func findScrollView(in view: NSView) -> NSScrollView? {
            for sub in view.subviews {
                if let sv = sub as? NSScrollView { return sv }
                if let sv = findScrollView(in: sub) { return sv }
            }
            return nil
        }
        guard let scrollView = findScrollView(in: self.view) else { return }
        // 高さ制約を検索して更新、なければ追加
        if let heightConstraint = scrollView.constraints.first(where: { $0.firstAttribute == .height }) {
            if heightConstraint.constant < minHeight { heightConstraint.constant = minHeight }
        } else {
            let c = scrollView.heightAnchor.constraint(equalToConstant: minHeight)
            c.priority = .required
            c.isActive = true
        }
        scrollView.needsLayout = true
    }
}

// MARK: - JJYAudioGeneratorDelegate
extension ViewController: JJYAudioGeneratorDelegate {
    func audioGeneratorDidStart() {
        DispatchQueue.main.async {
            self.startStopButton?.title = NSLocalizedString("stop_generation", comment: "Stop button title")
            self.statusLabel?.stringValue = NSLocalizedString("generating", comment: "Generating status")
        }
    }
    
    func audioGeneratorDidStop() {
        DispatchQueue.main.async {
            self.startStopButton?.title = NSLocalizedString("start_generation", comment: "Start button title")
            self.statusLabel?.stringValue = NSLocalizedString("stopped", comment: "Stopped status")
        }
    }
    
    func audioGeneratorDidEncounterError(_ error: String) {
        DispatchQueue.main.async {
            self.statusLabel?.stringValue = NSLocalizedString("error_failed_to_start", comment: "Generic start error")
        }
    }
}
