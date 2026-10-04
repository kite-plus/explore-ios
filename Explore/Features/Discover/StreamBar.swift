import SwiftUI

/// Discover's streams as tabs with the filter button at the end, as the
/// website's toolbar has them. The current tab is underlined, and the line
/// follows the streams as they slide; a screen too narrow for the tabs
/// scrolls them.
struct StreamBar: View {
    @Binding var stream: DiscoverStream
    /// Where the streams have slid to, in tabs from the first.
    let position: CGFloat
    /// Whether a blog language or a tag narrows the streams; the button
    /// then carries a dot.
    let filtered: Bool
    let showFilters: () -> Void

    @State private var frames: [DiscoverStream: CGRect] = [:]

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 22) {
                    ForEach(DiscoverStream.allCases) { option in
                        tab(option)
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
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Post feeds"))

            Button(action: showFilters) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .overlay(alignment: .topTrailing) {
                            if filtered {
                                Circle()
                                    .fill(Color.kite)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    Text("Filter")
                }
                .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.glass)
            .accessibilityValue(filtered ? Text("In use") : Text(verbatim: ""))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: filtered)
    }

    nonisolated private static let tabs = "StreamBar.tabs"

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

    private func tab(_ option: DiscoverStream) -> some View {
        let highlighted = option == nearest
        return Button {
            stream = option
        } label: {
            Text(option.title)
                .font(.subheadline.weight(highlighted ? .semibold : .regular))
                .foregroundStyle(highlighted ? Color.primary : Color.secondary)
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option == stream ? .isSelected : [])
    }
}
