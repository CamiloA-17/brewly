import BrewlyDomain
import SwiftUI

/// Paleta y componentes básicos de Brewly.
public enum BrewlyTheme {
    public static let espresso = Color(red: 0.24, green: 0.15, blue: 0.11)
    public static let crema = Color(red: 0.83, green: 0.63, blue: 0.42)
    public static let latte = Color(red: 0.96, green: 0.92, blue: 0.86)
    public static let accent = crema

    public static let cornerRadius: CGFloat = 14
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: BrewlyTheme.cornerRadius))
    }
}

extension View {
    func brewlyCard() -> some View { modifier(CardBackground()) }
}

/// Métrica compacta: "15 g", "1:16.7", "94 °C"…
struct MetricPill: View {
    let systemImage: String
    let value: String

    var body: some View {
        Label(value, systemImage: systemImage)
            .font(.footnote.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BrewlyTheme.crema.opacity(0.18), in: Capsule())
    }
}

struct VisibilityBadge: View {
    let visibility: Visibility

    var body: some View {
        Label(visibility.title, systemImage: visibility.systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct VisibilityPicker: View {
    @Binding var selection: Visibility
    var allowed: [Visibility] = Visibility.allCases

    var body: some View {
        Picker("Visibilidad", selection: $selection) {
            ForEach(allowed, id: \.self) { option in
                Label(option.title, systemImage: option.systemImage).tag(option)
            }
        }
    }
}

struct AvatarView: View {
    let url: URL?
    var size: CGFloat = 40

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(BrewlyTheme.crema)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Estado de carga reutilizable por los view models.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

enum Format {
    static func grams(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }

    static func ratio(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return "1:\(value.formatted(.number.precision(.fractionLength(0...1))))"
    }

    static func temperature(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) °C"
    }

    static func duration(_ seconds: Int?) -> String {
        guard let seconds else { return "—" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
