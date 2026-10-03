import SwiftUI

/// Shown in place of a list that could not load.
struct LoadFailedView: View {
    let message: String
    let retry: () async -> Void

    @State private var retrying = false

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button {
                Task {
                    retrying = true
                    await retry()
                    retrying = false
                }
            } label: {
                if retrying {
                    ProgressView()
                } else {
                    Text("Try Again")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(retrying)
        }
        .padding(.vertical, 40)
    }
}

/// A gray card in the shape of a post, while the first page loads.
struct EntryPlaceholder: View {
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: "A post title that runs over two lines on most phones")
                            .font(.headline)
                        Text(verbatim: "An excerpt of the post as its feed gives it, cut to a hundred and forty characters.")
                            .font(.subheadline)
                    }
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .frame(width: 84, height: 84)
                }
                HStack(spacing: 6) {
                    Circle().frame(width: 20, height: 20)
                    Text(verbatim: "Example Blog · 3 hours ago")
                        .font(.footnote)
                }
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
        .accessibilityHidden(true)
    }
}

/// A soft highlight sweeping across placeholders.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.4)
                        .blendMode(.plusLighter)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// The line under a list that has nothing more to load.
struct ListEndView: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Capsule().frame(width: 18, height: 1)
            Text(text)
            Capsule().frame(width: 18, height: 1)
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Loads the next page when it scrolls into view, or offers a retry.
///
/// The task sits on a container that stays put while a page loads; on a
/// view that the spinner replaced, SwiftUI would cancel the request it
/// had just started.
struct PageFooter: View {
    let isLoading: Bool
    let error: String?
    let hasMore: Bool
    let itemCount: Int
    let endText: LocalizedStringKey?
    let loadMore: () async -> Void

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await loadMore() } }
                        .buttonStyle(.glass)
                }
            } else if !hasMore, let endText {
                ListEndView(text: endText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 8)
        .task(id: itemCount) {
            guard hasMore, !isLoading, error == nil else { return }
            await loadMore()
        }
    }
}
