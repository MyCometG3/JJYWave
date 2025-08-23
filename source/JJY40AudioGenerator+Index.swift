// 外部から参照されることを前提にトップレベルに分離
// JJYAudioGenerator 内のネスト型を参照しやすくするための型エイリアス
internal typealias JJYSymbol = JJYAudioGenerator.JJYSymbol

struct JJYIndex {
    static let markers: [Int] = [0,9,19,29,39,49]
    static let callsignStart = 40
    static let callsignEnd = 48
}
