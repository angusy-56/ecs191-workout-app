import SwiftUI

/// One place for the app's look: light background, black text, generous spacing.
enum Theme {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let card = Color.white
    static let text = Color.black
    static let secondary = Color.black.opacity(0.5)
    static let line = Color.black.opacity(0.08)
    static let flame = Color(red: 1.0, green: 0.42, blue: 0.1)
    static let done = Color(red: 0.2, green: 0.62, blue: 0.35)

    static let spacing: CGFloat = 20
    static let radius: CGFloat = 14

    static func title() -> Font { .system(size: 30, weight: .bold, design: .rounded) }
    static func headline() -> Font { .system(size: 18, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func caption() -> Font { .system(size: 13, weight: .medium, design: .rounded) }
}

/// White rounded card used for list rows and groups.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.line))
    }
}

/// Full-width black button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.text.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }
}

/// White button with a thin outline, for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.headline())
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.card.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.text.opacity(0.15)))
    }
}
