import SwiftUI

struct MenuAppearance {
    let canvas: Color
    let input: Color
    let accent: Color
    let softAccent: Color
    let ink: Color
    let muted: Color
    let separator: Color
    let titleFont: Font

    static let classic = MenuAppearance(
        canvas: Brand.paper,
        input: Color(hex: "FAF3F4"),
        accent: Brand.burgundy,
        softAccent: Brand.blush,
        ink: Brand.ink,
        muted: Brand.muted,
        separator: Brand.line,
        titleFont: .system(.largeTitle, design: .serif, weight: .semibold)
    )

    static let blue = MenuAppearance(
        canvas: BlueAppearance.canvas,
        input: Color(hex: "F2F6FD"),
        accent: BlueAppearance.accent,
        softAccent: Color(hex: "E2EBFD"),
        ink: BlueAppearance.ink,
        muted: BlueAppearance.muted,
        separator: BlueAppearance.line,
        titleFont: .largeTitle.bold()
    )
}
