import SwiftUI

/// What narrows Discover's streams, as the website's filter panel holds it:
/// the blog language as a switch and the tags as tiles with their icons.
/// Picking a tag closes the sheet, as choosing from a menu would; the
/// language can change first.
struct FilterSheet: View {
    @Binding var language: LanguageFilter
    @Binding var tag: String?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section("Blog language") {
                        Picker("Blog language", selection: $language.animation(.snappy)) {
                            ForEach(LanguageFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .labelsHidden()
                    }
                    section("Tags") {
                        if app.topics.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            LazyVGrid(columns: columns, spacing: 8) {
                                TagTile(name: String(localized: "All"), symbol: "square.grid.2x2", selected: tag == nil) {
                                    choose(nil)
                                }
                                ForEach(app.topics) { topic in
                                    TagTile(
                                        name: topic.name(in: .current), symbol: TopicStyle.symbol(for: topic.slug),
                                        selected: tag == topic.slug
                                    ) {
                                        choose(topic.slug)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if language != .all || tag != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Reset") {
                            withAnimation(.snappy) {
                                language = .all
                                tag = nil
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await app.loadTopics()
        }
    }

    private func choose(_ slug: String?) {
        withAnimation(.snappy) { tag = slug }
        // The tile shows the choice before the sheet goes.
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            dismiss()
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// A tag's icon and name; the chosen one takes the brand color, as on the
/// website.
private struct TagTile: View {
    let name: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 20)
                    .opacity(selected ? 1 : 0.7)
                Text(name)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.kite : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                selected ? Color.kite.opacity(0.12) : Color(.tertiarySystemFill),
                in: .rect(cornerRadius: 12, style: .continuous)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
