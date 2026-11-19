import SwiftUI

/// The Language tab: one round flag per language in a 3 × 3 grid, each named in its own language.
/// Picking one switches Dayloom at once; until then it follows the Mac's language.
struct LanguageSettingsSection: View {
    private let store = LanguageStore.shared

    var body: some View {
        PanelSection("Language") {
            Text("Dayloom follows your Mac's language until you pick one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    LanguageFlag(language: language, isSelected: language == store.language) {
                        store.select(language)
                    }
                }
            }
            Text("Menus drawn by macOS switch the next time Dayloom opens.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One round flag with its native name; the selected one gets a ring and a checkmark.
private struct LanguageFlag: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    private static let size: CGFloat = 44

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Image(language.flagAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Self.size, height: Self.size)
                        .clipShape(.circle)
                        .overlay {
                            Circle().strokeBorder(isSelected ? Theme.accent : Color.primary.opacity(0.12),
                                                  lineWidth: isSelected ? 2 : 1)
                        }
                        // The unpicked flags step back without losing which country they are.
                        .opacity(isSelected ? 1 : 0.55)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white, Theme.accent)
                            .offset(x: 3, y: 3)
                    }
                }
                // Verbatim: a language names itself in every language.
                Text(verbatim: language.nativeName)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isHovered && !isSelected ? Theme.cardHover : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: language.nativeName))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    LanguageSettingsSection()
        .padding(24)
        .frame(width: 600)
}
