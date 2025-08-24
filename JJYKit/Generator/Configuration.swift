struct Configuration {
    // フォーマットに影響する項目（再セットアップが必要）
    var sampleRate: Double
    var channelCount: UInt32
    // 搬送波関連
    var isTestModeEnabled: Bool
    var testFrequency: Double
    var actualFrequency: Double
    // オプション
    var enableCallsign: Bool
    var enableServiceStatusBits: Bool
    var leapSecondPending: Bool
    var leapSecondInserted: Bool
    var serviceStatusBits: (st1: Bool, st2: Bool, st3: Bool, st4: Bool, st5: Bool, st6: Bool)
    var leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)?
    // 波形
    var waveform: JJYAudioGenerator.Waveform

    init(sampleRate: Double,
                channelCount: UInt32,
                isTestModeEnabled: Bool,
                testFrequency: Double,
                actualFrequency: Double,
                enableCallsign: Bool,
                enableServiceStatusBits: Bool,
                leapSecondPending: Bool,
                leapSecondInserted: Bool,
                serviceStatusBits: (Bool,Bool,Bool,Bool,Bool,Bool),
                leapSecondPlan: (yearUTC: Int, monthUTC: Int, kind: JJYAudioGenerator.LeapKind)? = nil,
                waveform: JJYAudioGenerator.Waveform = .sine) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.isTestModeEnabled = isTestModeEnabled
        self.testFrequency = testFrequency
        self.actualFrequency = actualFrequency
        self.enableCallsign = enableCallsign
        self.enableServiceStatusBits = enableServiceStatusBits
        self.leapSecondPending = leapSecondPending
        self.leapSecondInserted = leapSecondInserted
        self.serviceStatusBits = serviceStatusBits
        self.leapSecondPlan = leapSecondPlan
        self.waveform = waveform
    }
}
