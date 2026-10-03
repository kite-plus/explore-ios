import SwiftUI

/// The result of Explore's latest check of a post's link: a green check,
/// "Possibly unavailable" for a 404 or 410, or a prompt to check it now.
/// Tapping shows the details in a Liquid Glass popover.
struct LinkStatusBadge: View {
    let entry: Entry

    @Environment(AppModel.self) private var app
    @State private var showsDetails = false

    var body: some View {
        let state = app.linkStatus(of: entry)
        let checking = app.checkingLinks.contains(entry.id)
        Button {
            showsDetails = true
        } label: {
            badge(state.status, checkedAt: state.checkedAt, checking: checking)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsDetails) {
            LinkStatusDetails(entry: entry)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(Text(LinkStatusText.title(state.status, checkedAt: state.checkedAt)))
    }

    @ViewBuilder
    private func badge(_ status: LinkStatus, checkedAt: Date?, checking: Bool) -> some View {
        if checking {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking…")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .transition(.opacity)
        } else {
            switch status {
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            case .unavailable:
                Pill(text: String(localized: "Possibly unavailable"), systemImage: "xmark.circle.fill", tint: .red)
            case .unknown:
                Pill(
                    text: checkedAt == nil ? String(localized: "Awaiting check") : String(localized: "Status uncertain"),
                    systemImage: "questionmark.circle", tint: .orange
                )
            }
        }
    }
}

enum LinkStatusText {
    static func title(_ status: LinkStatus, checkedAt: Date?) -> String {
        switch status {
        case .available: String(localized: "Last check succeeded")
        case .unavailable: String(localized: "Possibly unavailable")
        case .unknown: checkedAt == nil ? String(localized: "Awaiting check") : String(localized: "Status uncertain")
        }
    }
}

private struct LinkStatusDetails: View {
    let entry: Entry

    @Environment(AppModel.self) private var app

    var body: some View {
        let state = app.linkStatus(of: entry)
        let checking = app.checkingLinks.contains(entry.id)
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(LinkStatusText.title(state.status, checkedAt: state.checkedAt))
            } icon: {
                Image(systemName: icon(state.status))
                    .foregroundStyle(color(state.status))
            }
            .font(.headline)

            Group {
                if let checkedAt = state.checkedAt {
                    Text("Checked \(Formatting.relative(checkedAt))")
                } else {
                    Text("Explore hasn't checked this link yet.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if state.status == .unavailable {
                Text("The site answered Explore with 404 or 410. The original link stays here, since readers may get a different result.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Checked by Explore; your visit may get a different result.")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            if state.status == .unknown {
                Button {
                    Task { await app.checkLink(entry) }
                } label: {
                    HStack {
                        if checking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(checking ? "Checking…" : "Check Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(checking)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(width: 300)
        .animation(.snappy, value: state.status)
        .animation(.snappy, value: checking)
    }

    private func icon(_ status: LinkStatus) -> String {
        switch status {
        case .available: "checkmark.circle.fill"
        case .unavailable: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private func color(_ status: LinkStatus) -> Color {
        switch status {
        case .available: .green
        case .unavailable: .red
        case .unknown: .orange
        }
    }
}
