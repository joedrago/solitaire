import SwiftUI

// A parametric color treatment applied to every card image. Lets dark mode
// restyle the cards with pure color math (no new assets): invert flips the
// white paper to black, and a hue rotation spins the inverted suits back to
// sensible colors.
struct CardTreatment {
    let invert: Bool
    let hue: Double // degrees of hue rotation, applied after invert
    let saturation: Double
    let brightness: Double
    let multiply: Color

    // No-op: renders the card exactly as authored (light mode).
    static let identity = CardTreatment(
        invert: false, hue: 0, saturation: 1, brightness: 0, multiply: .white
    )

    // Just knock the paper-white down to gray.
    static let dim = CardTreatment(
        invert: false, hue: 0, saturation: 1, brightness: 0, multiply: Color(white: 0.6)
    )

    // Classic dark deck: black background, white black-suits, red stays red.
    // 200° is where SwiftUI's matrix hueRotation lands the inverted suit on a
    // true red (lower reads pink, higher tips orange); the same dim multiply
    // keeps the bright pips off eye-searing.
    static let inverted = CardTreatment(
        invert: true, hue: 200, saturation: 1, brightness: 0, multiply: Color(white: 0.6)
    )
}

// Applies a CardTreatment as a stable view type. Order matters: invert first,
// then spin the hue, then the tonal adjustments.
struct CardFX: ViewModifier {
    let t: CardTreatment

    func body(content: Content) -> some View {
        let base = t.invert ? AnyView(content.colorInvert()) : AnyView(content)
        return base
            .hueRotation(.degrees(t.hue))
            .saturation(t.saturation)
            .brightness(t.brightness)
            .colorMultiply(t.multiply)
    }
}
