import SwiftUI

/// The problems a feed check found, worst first. Hints come from the
/// server in the interface language; titles are named here by code.
struct CheckProblemsList: View {
    let problems: [Problem]

    private var sorted: [Problem] {
        problems.sorted { rank($0.severity) < rank($1.severity) }
    }

    var body: some View {
        ForEach(Array(sorted.enumerated()), id: \.offset) { _, problem in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: SeverityStyle.symbol(problem.severity))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SeverityStyle.color(problem.severity))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ProblemText.title(problem.code))
                            .font(.subheadline.weight(.semibold))
                        if let count = problem.count, count > 1 {
                            Text(verbatim: "×\(count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(SeverityStyle.label(problem.severity))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(SeverityStyle.color(problem.severity))
                    }
                    if let hint = problem.hint, !hint.isEmpty {
                        Text(hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let detail = problem.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func rank(_ severity: Severity) -> Int {
        switch severity {
        case .error: 0
        case .warning: 1
        case .info: 2
        }
    }
}

enum SeverityStyle {
    static func symbol(_ severity: Severity) -> String {
        switch severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    static func color(_ severity: Severity) -> Color {
        switch severity {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        }
    }

    static func label(_ severity: Severity) -> String {
        switch severity {
        case .error: String(localized: "Error")
        case .warning: String(localized: "Warning")
        case .info: String(localized: "Note")
        }
    }
}

enum ProblemText {
    static func title(_ code: String) -> String {
        switch code {
        case "feed_not_found": String(localized: "No feed found")
        case "robots_disallowed": String(localized: "Blocked by robots.txt")
        case "http_error": String(localized: "The site returned an error")
        case "too_large": String(localized: "The feed is too large")
        case "parse_error": String(localized: "The feed can't be read")
        case "links_off_domain": String(localized: "Post links point to another domain")
        case "links_elsewhere": String(localized: "Posts link to other sites")
        case "site_moved": String(localized: "The site has moved")
        case "no_valid_items": String(localized: "No usable posts")
        case "stale": String(localized: "No posts in the last 12 months")
        case "some_links_off_domain": String(localized: "Some links point to another domain")
        case "no_dates": String(localized: "Some posts have no date")
        case "dates_untrusted": String(localized: "Post dates look unreliable")
        case "includes_non_posts": String(localized: "The feed lists pages that aren't posts")
        case "no_conditional_get": String(localized: "No conditional requests")
        case "redirected": String(localized: "The feed address redirects")
        default: code
        }
    }
}

enum SubmissionStyle {
    static func title(_ status: SubmissionStatus) -> String {
        switch status {
        case .pending: String(localized: "Waiting for review")
        case .approved: String(localized: "Listed")
        case .rejected: String(localized: "Not accepted")
        }
    }

    static func symbol(_ status: SubmissionStatus) -> String {
        switch status {
        case .pending: "hourglass"
        case .approved: "checkmark.seal.fill"
        case .rejected: "xmark.octagon.fill"
        }
    }

    static func color(_ status: SubmissionStatus) -> Color {
        switch status {
        case .pending: .orange
        case .approved: .green
        case .rejected: .red
        }
    }
}
