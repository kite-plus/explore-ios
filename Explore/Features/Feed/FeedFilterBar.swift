import SwiftUI

/// The language switch and topic menu above a feed, in Liquid Glass.
///
/// Both sit in one glass container: picking a topic tints its capsule and
/// grows a clear button out of it; clearing the topic folds it back in.
struct FeedFilterBar: View {
    @Binding var language: LanguageFilter
    @Binding var tag: String?

    @Environment(AppModel.self) private var app
    @Namespace private var glass
    @Namespace private var selection

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                languageSwitch
                Spacer(minLength: 0)
                if let tag {
                    Button {
                        withAnimation(.bouncy) { self.tag = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TopicStyle.of(tag).color)
                            .frame(width: 44, height: 44)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .glassEffectID("clear", in: glass)
                    .accessibilityLabel(Text("Show All Topics"))
                }
                topicMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private var languageSwitch: some View {
        HStack(spacing: 2) {
            ForEach(LanguageFilter.allCases) { option in
                let selected = option == language
                Button {
                    withAnimation(.snappy(duration: 0.3)) { language = option }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.kite : Color.primary)
                        .padding(.horizontal, 13)
                        .frame(height: 36)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.kite.opacity(0.16))
                                    .matchedGeometryEffect(id: "selected", in: selection)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("language", in: glass)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Blog language"))
    }

    private var topicMenu: some View {
        let style = tag.map(TopicStyle.of)
        return Menu {
            Picker(selection: $tag.animation(.bouncy)) {
                Label("All Topics", systemImage: "square.grid.2x2")
                    .tag(String?.none)
                ForEach(app.topics) { topic in
                    Label(topic.name(in: .current), systemImage: TopicStyle.of(topic.slug).symbol)
                        .tag(Optional(topic.slug))
                }
            } label: {
                Text("Topic")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: style?.symbol ?? "number")
                Text(tag.flatMap(app.topicName) ?? String(localized: "Topics"))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.6)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(style.map { AnyShapeStyle($0.color) } ?? AnyShapeStyle(.primary))
            .padding(.horizontal, 16)
            .frame(height: 44)
            .contentShape(.capsule)
        }
        .menuIndicator(.hidden)
        .glassEffect(style.map { .regular.tint($0.color.opacity(0.22)).interactive() } ?? .regular.interactive(), in: .capsule)
        .glassEffectID("topic", in: glass)
        .accessibilityLabel(Text("Topic"))
    }
}
