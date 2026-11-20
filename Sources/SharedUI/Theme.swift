import SwiftUI

/// Hand-drawn paper tokens mirrored from Android `Design.java` / Web `tokens.scss`.
/// Keep colours here; pages must not invent new hex values.
enum Zine {
    static let ink = Color(red: 58 / 255, green: 36 / 255, blue: 24 / 255)
    static let muted = Color(red: 110 / 255, green: 85 / 255, blue: 71 / 255)
    static let red = Color(red: 201 / 255, green: 52 / 255, blue: 30 / 255)
    static let redPressed = Color(red: 171 / 255, green: 31 / 255, blue: 11 / 255)
    static let green = Color(red: 91 / 255, green: 122 / 255, blue: 58 / 255)
    static let blue = Color(red: 63 / 255, green: 114 / 255, blue: 145 / 255)
    static let gold = Color(red: 184 / 255, green: 137 / 255, blue: 36 / 255)
    static let paper = Color(red: 255 / 255, green: 250 / 255, blue: 240 / 255)
    static let alt = Color(red: 247 / 255, green: 239 / 255, blue: 217 / 255)
    static let kraft = Color(red: 216 / 255, green: 192 / 255, blue: 139 / 255)
    static let kraftSoft = Color(red: 234 / 255, green: 219 / 255, blue: 187 / 255)
    static let bar = Color(red: 242 / 255, green: 239 / 255, blue: 230 / 255)
    static let border = Color(red: 213 / 255, green: 204 / 255, blue: 188 / 255)
    static let pressed = Color(red: 241 / 255, green: 236 / 255, blue: 226 / 255)
    static let onRed = Color(red: 255 / 255, green: 245 / 255, blue: 242 / 255)
    static let shadow = Color(red: 58 / 255, green: 36 / 255, blue: 24 / 255).opacity(0.12)

    static let pagePadding: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 16
    static let smallRadius: CGFloat = 10

    static let titleFont = Font.system(.title, design: .serif).weight(.black)
    static let sectionFont = Font.system(.title2, design: .serif).weight(.bold)
    static let bodyFont = Font.system(.body)
    static let noteFont = Font.system(.callout, design: .serif).italic()
}
