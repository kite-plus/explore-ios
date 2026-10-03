import SwiftUI

/// Discover's streams as tabs with the filter button at the end, as the
/// website's toolbar has them. The current tab is underlined, and the line
/// slides to a new one; a screen too narrow for the tabs scrolls them.
struct StreamBar: View {
    @Binding var stream: DiscoverStream
    /// Whether a blog language or a tag narrows the streams; the button
    /// then carries a dot.
    let filtered: Bool
    let showFilters: () -> Void

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal) {
                HStack(spacing: 22) {
                    ForEach(DiscoverStream.allCases) { option in
                        tab(option)
                    }
                }
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

    private func tab(_ option: DiscoverStream) -> some View {
        let selected = option == stream
        return Button {
            withAnimation(.snappy(duration: 0.3)) { stream = option }
        } label: {
            Text(option.title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if selected {
                        Capsule()
                            .fill(Color.primary)
                            .frame(height: 2.5)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
