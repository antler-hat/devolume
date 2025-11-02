import AppKit

extension NSColor {
    /// Creates a color from a hex string such as `#FF1122` or `#80FF1122`. Returns `nil` when parsing fails.
    /// The optional `alpha` overrides the parsed alpha, making it easy to reuse one hex value with different opacity.
    static func fromHex(_ hexString: String, alpha overrideAlpha: CGFloat? = nil) -> NSColor? {
        var cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        } else if cleaned.hasPrefix("0X") {
            cleaned.removeFirst(2)
        }

        if cleaned.count == 3 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }

        var rgbaValue: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgbaValue) else {
            return nil
        }

        let parsedAlpha: CGFloat
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        switch cleaned.count {
        case 6:
            red = CGFloat((rgbaValue & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgbaValue & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgbaValue & 0x0000FF) / 255.0
            parsedAlpha = 1.0
        case 8:
            red = CGFloat((rgbaValue & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgbaValue & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgbaValue & 0x0000FF00) >> 8) / 255.0
            parsedAlpha = CGFloat(rgbaValue & 0x000000FF) / 255.0
        default:
            return nil
        }

        let finalAlpha = overrideAlpha ?? parsedAlpha
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: finalAlpha)
    }
}
