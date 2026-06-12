import SwiftUI

// A parametric color treatment applied to every card image. Lets dark mode
// restyle the cards with pure color math (no new assets): a multiply darkens
// (and can warm) the paper, while saturation/hue/invert allow more drastic
// restylings if a mode ever wants them.
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

    // Candlelight: same paper-and-ink cards, lit warm and low. The blue cut
    // does most of the perceived dimming (night glare is mostly blue), and
    // the saturation boost keeps the red suits unambiguously red under it.
    static let candlelight = CardTreatment(
        invert: false, hue: 0, saturation: 1.15, brightness: 0,
        multiply: Color(red: 0.45, green: 0.39, blue: 0.28)
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
