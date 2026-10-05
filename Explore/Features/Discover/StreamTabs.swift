import SwiftUI

/// Discover's streams as tabs in the middle of the bar, as feed apps carry
/// them. The current tab is underlined, and the line follows the streams
/// as they slide.
struct StreamTabs: View {
    @Binding var stream: DiscoverStream
    /// Where the streams have slid to, in tabs from the first.
    let position: CGFloat

    @State private var frames: [DiscoverStream: CGRect] = [:]

    var body: some View {
        // Longer labels, as in English, step down a size to fit the bar.
        ViewThatFits(in: .horizontal) {
            row(font: .body, spacing: 20)
            row(font: .subheadline, spacing: 14)
        }
        // The bar has room for three short labels, not for the largest sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Post feeds"))
    }

    private func row(font: Font, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(DiscoverStream.allCases) { option in
                tab(option, font: font)
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .named(Self.tabs))
                    } action: { frame in
                        frames[option] = frame
                    }
            }
        }
        .overlay(alignment: .bottomLeading) {
            underline
        }
        .coordinateSpace(.named(Self.tabs))
    }

    nonisolated private static let tabs = "StreamTabs.tabs"

    /// The tab nearest to where the streams have slid, so the bold label
    /// moves halfway through a swipe.
    private var nearest: DiscoverStream {
        let cases = DiscoverStream.allCases
        let index = Int(position.rounded())
        return cases[min(max(index, 0), cases.count - 1)]
    }

    /// The line under the tabs, between two of them while the streams slide.
    @ViewBuilder
    private var underline: some View {
        let cases = DiscoverStream.allCases
        let clamped = min(max(position, 0), CGFloat(cases.count - 1))
        let lower = Int(clamped.rounded(.down))
        let upper = min(lower + 1, cases.count - 1)
        let progress = clamped - CGFloat(lower)
        if let from = frames[cases[lower]], let to = frames[cases[upper]] {
            Capsule()
                .fill(Color.primary)
                .frame(width: from.width + (to.width - from.width) * progress, height: 2.5)
                .offset(x: from.minX + (to.minX - from.minX) * progress)
                .accessibilityHidden(true)
        }
    }

    private func tab(_ option: DiscoverStream, font: Font) -> some View {
        let highlighted = option == nearest
        return Button {
            stream = option
        } label: {
            Text(option.title)
                .font(font.weight(highlighted ? .semibold : .regular))
                .foregroundStyle(highlighted ? Color.primary : Color.secondary)
                .lineLimit(1)
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option == stream ? .isSelected : [])
    }
}

/// Opens the filter sheet. While a blog language or a tag narrows the
/// streams, the button is filled with the app's color.
struct FilterButton: View {
    let filtered: Bool
    let action: () -> Void

    var body: some View {
        if filtered {
            button.buttonStyle(.glassProminent)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Label("Filter", systemImage: "line.3.horizontal.decrease")
        }
        .accessibilityValue(filtered ? Text("In use") : Text(verbatim: ""))
    }
}
