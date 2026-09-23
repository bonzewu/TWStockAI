import SwiftUI

/// 全域視覺樣式：對應參考設計的深色主題配色。
enum Theme {

    // MARK: - 基礎色

    static let background = Color(hex: 0x0B0E16)     // 全頁背景
    static let panel = Color(hex: 0x141927)          // 面板底色
    static let panelElevated = Color(hex: 0x1A2133)  // 次階面板
    static let grid = Color(hex: 0x232B3D)           // 格線／分隔線
    static let border = Color(hex: 0x2A3447)         // 面板邊框

    // MARK: - 文字

    static let textPrimary = Color(hex: 0xE6EAF5)
    static let textSecondary = Color(hex: 0x9AA6C1)
    static let textMuted = Color(hex: 0x6B7791)

    // MARK: - 強調色

    static let accent = Color(hex: 0x5B8CFF)         // 主藍
    static let accentSoft = Color(hex: 0x8AB0FF)
    static let bullish = Color(hex: 0xFF5F56)        // 紅：上漲（台股慣例）
    static let bearish = Color(hex: 0x2ECC71)        // 綠：下跌
    static let warning = Color(hex: 0xF5B301)
    static let purple = Color(hex: 0xA78BFA)
    static let cyan = Color(hex: 0x38BDF8)

    // MARK: - 指標線色（對應參考圖圖例）

    static let ma5 = Color(hex: 0xA78BFA)
    static let ma10 = Color(hex: 0x2ECC71)
    static let ma20 = Color(hex: 0xFF5F56)
    static let ma60 = Color(hex: 0x9AA6C1)
    static let kLine = Color(hex: 0xF5B301)
    static let dLine = Color(hex: 0x5B8CFF)
    static let difLine = Color(hex: 0x5B8CFF)
    static let macdLine = Color(hex: 0xF59E0B)

    /// 依漲跌回傳顏色（紅漲綠跌，平盤灰）。
    static func changeColor(_ value: Double) -> Color {
        if value > 0 { return bullish }
        if value < 0 { return bearish }
        return textSecondary
    }

    /// 依 0～100 分數回傳語意色（高分綠、中分黃、低分紅）。
    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 65...: return bearish
        case 45..<65: return warning
        default: return bullish
        }
    }

    /// 熱區圖漸層：低密度深藍 → 高密度黃紅。
    static func heatColor(_ intensity: Double) -> Color {
        let clamped = min(max(intensity, 0), 1)
        switch clamped {
        case ..<0.2: return Color(hex: 0x14204A)
        case ..<0.4: return Color(hex: 0x1D4ED8)
        case ..<0.6: return Color(hex: 0x0EA5E9)
        case ..<0.75: return Color(hex: 0x22C55E)
        case ..<0.9: return Color(hex: 0xFACC15)
        default: return Color(hex: 0xEF4444)
        }
    }
}

extension Color {
    /// 以 0xRRGGBB 形式建立顏色。
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// 數值格式化工具，統一全 App 的顯示風格。
enum Format {

    /// 價格：兩位小數。
    static func price(_ value: Double) -> String { String(format: "%.2f", value) }

    /// 帶正負號的價格。
    static func signedPrice(_ value: Double) -> String { String(format: "%+.2f", value) }

    /// 百分比：兩位小數並附上 %。
    static func percent(_ value: Double, digits: Int = 2) -> String {
        String(format: "%+.\(digits)f%%", value)
    }

    /// 整數百分比（不帶正負號）。
    static func ratio(_ value: Double) -> String { String(format: "%.0f%%", value) }

    /// 整數並加上千分位。
    static func integer(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// 帶正負號的整數（張數用）。
    static func signedInteger(_ value: Double) -> String {
        let text = integer(abs(value))
        if value > 0 { return "+\(text)" }
        if value < 0 { return "-\(text)" }
        return text
    }
}
