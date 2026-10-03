import SwiftUI

/// One submission's progress through review.
struct SubmissionView: View {
    let id: String

    @Environment(AppModel.self) private var app
    @Environment(\.navigate) private var navigate
    @State private var submission: Submission?
    @State private var error: String?

    var body: some View {
        List {
            if let submission {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: SubmissionStyle.symbol(submission.status))
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(SubmissionStyle.color(submission.status))
                            .frame(width: 76, height: 76)
                            .glassEffect(.regular.tint(SubmissionStyle.color(submission.status).opacity(0.2)), in: .circle)
                        Text(SubmissionStyle.title(submission.status))
                            .font(.title2.bold())
                        Text(submission.host)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    LabeledContent("Blog Address") {
                        Text(submission.siteURL)
                            .font(.footnote)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                    if !submission.feedURL.isEmpty {
                        LabeledContent("Feed Address") {
                            Text(submission.feedURL)
                                .font(.footnote)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("Submitted", value: Formatting.dateTime(submission.createdAt))
                    if let reviewedAt = submission.reviewedAt {
                        LabeledContent("Reviewed", value: Formatting.dateTime(reviewedAt))
                    }
                }

                if let note = submission.reviewNote, !note.isEmpty {
                    Section("Review Note") {
                        Text(note)
                    }
                }

                if submission.status == .approved {
                    Section {
                        Button("View the Blog") {
                            navigate(.blog(BlogRef(
                                host: submission.host,
                                name: submission.checkReport?.title ?? submission.host,
                                siteURL: submission.siteURL,
                                language: submission.checkReport?.language ?? ""
                            )))
                        }
                    }
                }

                Section("Check Results") {
                    if let problems = submission.checkReport?.problems, !problems.isEmpty {
                        CheckProblemsList(problems: problems)
                    } else {
                        Label("The check found no problems.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                }
            } else if let error {
                LoadFailedView(message: error) { await load() }
                    .listRowBackground(Color.clear)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Submission")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            submission = try await app.client.submission(id: id)
            error = nil
        } catch {
            guard !error.isCancellation else { return }
            if submission == nil { self.error = error.readableMessage }
        }
    }
}

/// Submissions made from this device. Explore links them to no account,
/// so the app remembers their ids locally.
struct SubmissionsView: View {
    @Environment(AppModel.self) private var app
    @State private var submissions: [String: Submission] = [:]

    var body: some View {
        List {
            if app.submissionIDs.isEmpty {
                ContentUnavailableView {
                    Label("No Submissions", systemImage: "tray")
                } description: {
                    Text("Blogs you submit from this device show up here with their review status.")
                } actions: {
                    Button("Submit a Blog") { app.sheet = .submit }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(app.submissionIDs, id: \.self) { id in
                    NavigationLink(value: Route.submission(id)) {
                        row(id)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            withAnimation { app.forgetSubmission(id) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("My Submissions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.sheet = .submit
                } label: {
                    Label("Submit a Blog", systemImage: "plus")
                }
            }
        }
        .refreshable { await load() }
        .task(id: app.submissionIDs) { await load() }
    }

    @ViewBuilder
    private func row(_ id: String) -> some View {
        if let submission = submissions[id] {
            HStack(spacing: 12) {
                Image(systemName: SubmissionStyle.symbol(submission.status))
                    .font(.title3)
                    .foregroundStyle(SubmissionStyle.color(submission.status))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(submission.checkReport?.title ?? submission.host)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(SubmissionStyle.title(submission.status)) · \(Formatting.day(submission.createdAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 12) {
                ProgressView()
                    .frame(width: 30)
                Text(id.prefix(8) + "…")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        for id in app.submissionIDs {
            guard !Task.isCancelled else { return }
            if let submission = try? await app.client.submission(id: id) {
                submissions[id] = submission
            }
        }
    }
}
