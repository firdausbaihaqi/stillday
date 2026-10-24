import SwiftUI

enum Motion {
    static func feedback(_ reduced: Bool) -> Animation { reduced ? .easeOut(duration: 0.1) : .spring(response: 0.24, dampingFraction: 0.78) }
    static func page(_ reduced: Bool) -> Animation? { reduced ? nil : .spring(response: 0.32, dampingFraction: 0.9) }
    static let fade = Animation.easeOut(duration: 0.2)
}

struct InteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { InteractiveButton(configuration: configuration) }
}

private struct InteractiveButton: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var hovered = false

    var body: some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(reducedMotion || !enabled ? 1 : configuration.isPressed ? 0.975 : hovered ? 1.012 : 1)
            .offset(y: reducedMotion || !enabled || configuration.isPressed ? 0 : hovered ? -0.6 : 0)
            .brightness(enabled && hovered ? 0.025 : 0)
            .opacity(enabled ? configuration.isPressed ? 0.84 : 1 : 0.42)
            .animation(Motion.feedback(reducedMotion), value: hovered)
            .animation(Motion.feedback(reducedMotion), value: configuration.isPressed)
            .onHover { hovered = $0 && enabled }
    }
}

struct FieldFeedback: ViewModifier {
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func body(content: Content) -> some View {
        content.focused($focused)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.accent.opacity(focused ? 0.4 : 0), lineWidth: 1))
            .animation(Motion.feedback(reducedMotion), value: focused)
    }
}
