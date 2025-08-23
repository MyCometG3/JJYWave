// JJY の呼出符号（モールス）用 OOK 判定
final class MorseCodeGenerator {
    // timeInWindow: 秒40からの相対時間（[0,9)）。パターンは JJY + 7T + JJY、合計97T。
    func isOnAt(timeInWindow t: Double, dit: Double) -> Bool {
        if t < 0 || t >= 9.0 { return false }
        // ITUモールス定義
        let dot = (1, true)
        let dash = (3, true)
        let elemSpace = (1, false)
        let charSpace = (3, false)
        let wordSpace = (7, false)
        // J: .---, Y: -.--
        let J: [(Int,Bool)] = [dot, elemSpace, dash, elemSpace, dash, elemSpace, dash]
        let Y: [(Int,Bool)] = [dash, elemSpace, dot, elemSpace, dash, elemSpace, dash]
        func letter(_ seq: [(Int,Bool)]) -> [(Int,Bool)] { seq }
        func addSpace(_ units: Int) -> [(Int,Bool)] { return [(units, false)] }
        var pattern: [(Int,Bool)] = []
        // JJY
        pattern += letter(J) + addSpace(charSpace.0) + letter(J) + addSpace(charSpace.0) + letter(Y)
        // 語間
        pattern += addSpace(wordSpace.0)
        // JJY
        pattern += letter(J) + addSpace(charSpace.0) + letter(J) + addSpace(charSpace.0) + letter(Y)
        // ユニット位置
        let unitPos = t / dit
        var acc: Double = 0.0
        for (len, on) in pattern {
            let next = acc + Double(len)
            if unitPos >= acc && unitPos < next { return on }
            acc = next
        }
        return false
    }
}
