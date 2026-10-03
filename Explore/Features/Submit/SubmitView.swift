import SwiftUI

/// Submits a blog: Explore checks its feed on the spot, the author reviews
/// what was found, and a maintainer reviews the submission.
struct SubmitView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private enum Stage: Equatable {
        case form
        case preview(SubmissionPreview)
        case done(Submission)
    }

    private enum Work {
        case checking, submitting
    }

    private struct Failure: Equatable {
        var message: String
        var report: CheckReport?
        var listed: BlogRef?
        var pendingID: String?
    }

    @State private var stage: Stage = .form
    @State private var siteAddress = ""
    @State private var feedAddress = ""
    @State private var note = ""
    @State private var name = ""
    @State private var summary = ""
    @State private var work: Work?
    @State private var failure: Failure?
    @State private var path = NavigationPath()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch stage {
                case .form:
                    form
                case let .preview(preview):
                    previewForm(preview)
                case let .done(submission):
                    done(submission)
                }
            }
            .navigationTitle("Submit a Blog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .exploreDestinations()
        }
        .environment(\.navigate, NavigateAction { route in path.append(route) })
        .interactiveDismissDisabled(work != nil)
    }

    // MARK: Address

    private var form: some View {
        Form {
            Section {
                Text("Enter your blog's address and Explore checks its feed right away. A maintainer reviews blogs that pass, and approved blogs are listed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                TextField(text: $siteAddress, prompt: Text(verbatim: "https://blog.example.com")) { Text("Blog Address") }
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
            } header: {
                Text("Blog Address")
            }
            Section {
                TextField(text: $feedAddress, prompt: Text(verbatim: "https://blog.example.com/feed.xml")) { Text("Feed Address (Optional)") }
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Feed Address (Optional)")
            } footer: {
                Text("Found automatically when left empty.")
            }
            Section {
                TextField("What the blog is about", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Note (Optional)")
            } footer: {
                Text(verbatim: "\(note.count) / 500")
                    .foregroundStyle(note.count > 500 ? .red : .secondary)
            }
            if let failure {
                failureSection(failure)
            }
        }
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: check) {
                    HStack(spacing: 8) {
                        if work == .checking {
                            ProgressView()
                        }
                        Text(work == .checking ? "Checking the Feed…" : "Check Blog")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .controlSize(.extraLarge)
                .disabled(work != nil || siteAddress.trimmingCharacters(in: .whitespaces).isEmpty || note.count > 500)
                Text("The check can take up to 30 seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onAppear {
            if siteAddress.isEmpty { focused = true }
        }
    }

    // MARK: Preview

    private func previewForm(_ preview: SubmissionPreview) -> some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Text(Palette.initial(of: name.isEmpty ? preview.host : name))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Palette.color(for: preview.host).gradient, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name.isEmpty ? preview.host : name)
                            .font(.headline)
                        Text(preview.host)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                TextField("Blog name", text: $name)
                TextField("Description", text: $summary, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Blog Preview")
            } footer: {
                Text("Explore read these from the blog. Adjust the name or description if needed.")
            }

            Section("Feed") {
                LabeledContent("Feed Address") {
                    Text(preview.feedURL)
                        .font(.footnote)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                }
                if let latest = preview.latestEntryTitle, !latest.isEmpty {
                    LabeledContent("Latest Post", value: latest)
                }
                LabeledContent("Usable Posts", value: "\(preview.itemsValid) / \(preview.itemsTotal)")
                if let generator = Formatting.generatorName(preview.generator) {
                    LabeledContent("Blog System", value: generator)
                }
                if let language = Formatting.languageName(preview.language) {
                    LabeledContent("Language", value: language)
                }
            }

            Section("Check Results") {
                if let problems = preview.checkReport?.problems, !problems.isEmpty {
                    CheckProblemsList(problems: problems)
                } else {
                    Label("The check found no problems.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            if let failure {
                failureSection(failure)
            }
        }
        .safeAreaBar(edge: .bottom) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.snappy) {
                            failure = nil
                            stage = .form
                        }
                    } label: {
                        Text("Edit")
                            .font(.headline)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.glass)
                    .disabled(work != nil)

                    Button {
                        submit(preview)
                    } label: {
                        HStack(spacing: 8) {
                            if work == .submitting {
                                ProgressView()
                            }
                            Text(work == .submitting ? "Submitting…" : "Confirm and Submit")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                    .disabled(work != nil || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .controlSize(.extraLarge)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    // MARK: Done

    private func done(_ submission: Submission) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.white, .green)
                .symbolEffect(.bounce, value: submission.id)
                .frame(width: 128, height: 128)
                .glassEffect(.regular.tint(.green.opacity(0.25)), in: .circle)
            Text("Submitted for Review")
                .font(.title.bold())
            Text("A maintainer will review \(submission.host). Check its status any time under My Submissions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    Button {
                        path.append(Route.submission(submission.id))
                    } label: {
                        Text("View Status")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primaryAction)
                }
                .controlSize(.extraLarge)
            }
        }
        .padding(28)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: submission.id)
    }

    // MARK: Failures

    private func failureSection(_ failure: Failure) -> some View {
        Section {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            if let listed = failure.listed {
                Button("View the Blog") {
                    path.append(Route.blog(listed))
                }
            }
            if let id = failure.pendingID {
                Button("View the Submission") {
                    path.append(Route.submission(id))
                }
            }
            if let problems = failure.report?.problems, !problems.isEmpty {
                CheckProblemsList(problems: problems)
            }
        }
    }

    // MARK: Actions

    private func check() {
        let site = Formatting.normalizedAddress(siteAddress)
        guard let url = URL(string: site), url.host() != nil else {
            withAnimation { failure = Failure(message: String(localized: "Enter a valid http or https address.")) }
            return
        }
        let feed = feedAddress.trimmingCharacters(in: .whitespaces).isEmpty ? "" : Formatting.normalizedAddress(feedAddress)
        focused = false
        work = .checking
        failure = nil
        Task {
            defer { work = nil }
            do {
                let preview = try await app.client.previewSubmission(siteURL: site, feedURL: feed)
                name = preview.title
                summary = preview.description
                withAnimation(.snappy) { stage = .preview(preview) }
            } catch {
                withAnimation { failure = describe(error, site: url) }
            }
        }
    }

    private func submit(_ preview: SubmissionPreview) {
        work = .submitting
        failure = nil
        Task {
            defer { work = nil }
            do {
                let submission = try await app.client.submit(
                    siteURL: preview.siteURL, feedURL: preview.feedURL,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                    title: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: summary.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                app.rememberSubmission(submission.id)
                withAnimation(.bouncy) { stage = .done(submission) }
            } catch {
                withAnimation { failure = describe(error, site: URL(string: preview.siteURL)) }
            }
        }
    }

    private func describe(_ error: Error, site: URL?) -> Failure {
        guard let apiError = error as? APIError else {
            return Failure(message: error.readableMessage)
        }
        let host = site?.host()?.lowercased() ?? ""
        switch apiError.code {
        case "invalid_url":
            return Failure(message: String(localized: "Enter a valid http or https address."))
        case "already_listed":
            let ref = BlogRef(host: host, name: host, siteURL: site?.absoluteString ?? "", language: "")
            return Failure(message: String(localized: "This blog is already listed."), listed: host.isEmpty ? nil : ref)
        case "already_pending":
            return Failure(message: apiError.readableMessage, pendingID: apiError.submissionID)
        case "excluded":
            return Failure(message: String(localized: "This blog has left Explore or was blocked. Contact a maintainer to join again."))
        case "check_failed":
            return Failure(message: String(localized: "The blog did not pass the check. Fix the problems below and try again."), report: apiError.report)
        case "rate_limited":
            return Failure(message: String(localized: "Too many submissions; try again in a while."))
        case "feature_disabled":
            return Failure(message: String(localized: "Submissions are closed on this server right now."))
        default:
            return Failure(message: apiError.readableMessage)
        }
    }
}
