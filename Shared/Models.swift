import Foundation

// Mirrors docs/design/api.md in the explore repository. Fields the app does
// not need are left out; decoding tolerates fields the server adds later.

nonisolated struct BlogRef: Codable, Hashable, Sendable {
    let host: String
    let name: String
    let siteURL: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case host, name, language
        case siteURL = "site_url"
    }
}

nonisolated enum LinkStatus: String, Codable, Hashable, Sendable {
    case available, unavailable, unknown

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LinkStatus(rawValue: raw) ?? .unknown
    }
}

nonisolated struct Entry: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let url: String
    let excerpt: String?
    /// A path on the Explore server, such as /api/v1/entries/12/image.
    let imagePath: String?
    let publishedAt: Date?
    let tags: [String]
    let linkStatus: LinkStatus
    let linkCheckedAt: Date?
    let blog: BlogRef?

    enum CodingKeys: String, CodingKey {
        case id, title, url, excerpt, tags, blog
        case imagePath = "image_url"
        case publishedAt = "published_at"
        case linkStatus = "link_status"
        case linkCheckedAt = "link_checked_at"
    }

    init(
        id: String, title: String, url: String, excerpt: String?, imagePath: String?,
        publishedAt: Date?, tags: [String], linkStatus: LinkStatus, linkCheckedAt: Date?, blog: BlogRef?
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.excerpt = excerpt
        self.imagePath = imagePath
        self.publishedAt = publishedAt
        self.tags = tags
        self.linkStatus = linkStatus
        self.linkCheckedAt = linkCheckedAt
        self.blog = blog
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        url = try c.decode(String.self, forKey: .url)
        excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt)
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        linkStatus = try c.decodeIfPresent(LinkStatus.self, forKey: .linkStatus) ?? .unknown
        linkCheckedAt = try c.decodeIfPresent(Date.self, forKey: .linkCheckedAt)
        blog = try c.decodeIfPresent(BlogRef.self, forKey: .blog)
    }
}

nonisolated struct Blog: Codable, Hashable, Identifiable, Sendable {
    let host: String
    let name: String
    /// The blog's own description; empty when it has none.
    let about: String
    let siteURL: String
    let feedURL: String
    let language: String
    let generator: String
    let lastPublishedAt: Date?

    var id: String { host }

    var ref: BlogRef { BlogRef(host: host, name: name, siteURL: siteURL, language: language) }

    enum CodingKeys: String, CodingKey {
        case host, name, language, generator
        case about = "description"
        case siteURL = "site_url"
        case feedURL = "feed_url"
        case lastPublishedAt = "last_published_at"
    }

    init(
        host: String, name: String, about: String, siteURL: String, feedURL: String,
        language: String, generator: String, lastPublishedAt: Date?
    ) {
        self.host = host
        self.name = name
        self.about = about
        self.siteURL = siteURL
        self.feedURL = feedURL
        self.language = language
        self.generator = generator
        self.lastPublishedAt = lastPublishedAt
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = try c.decode(String.self, forKey: .host)
        name = try c.decode(String.self, forKey: .name)
        about = try c.decodeIfPresent(String.self, forKey: .about) ?? ""
        siteURL = try c.decode(String.self, forKey: .siteURL)
        feedURL = try c.decodeIfPresent(String.self, forKey: .feedURL) ?? ""
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? ""
        generator = try c.decodeIfPresent(String.self, forKey: .generator) ?? "unknown"
        lastPublishedAt = try c.decodeIfPresent(Date.self, forKey: .lastPublishedAt)
    }
}

nonisolated struct Page<Item: Codable & Sendable>: Codable, Sendable {
    let data: [Item]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextCursor = "next_cursor"
    }
}

nonisolated struct BlogPage: Codable, Sendable {
    let blog: Blog
    let entries: [Entry]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case blog, entries
        case nextCursor = "next_cursor"
    }
}

nonisolated struct DataList<Item: Codable & Sendable>: Codable, Sendable {
    let data: [Item]
}

/// A tag from Explore's fixed list, named in Chinese and English.
nonisolated struct Topic: Codable, Hashable, Identifiable, Sendable {
    let slug: String
    let name: [String: String]

    var id: String { slug }

    func name(in language: AppLanguage) -> String {
        name[language.rawValue] ?? name["en"] ?? slug
    }
}

nonisolated struct LinkState: Codable, Hashable, Sendable {
    let linkStatus: LinkStatus
    let linkCheckedAt: Date?
    let checking: Bool

    enum CodingKeys: String, CodingKey {
        case checking
        case linkStatus = "link_status"
        case linkCheckedAt = "link_checked_at"
    }
}

nonisolated struct SiteConfig: Codable, Sendable {
    let notice: String
    let registrationEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case notice
        case registrationEnabled = "registration_enabled"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notice = try c.decodeIfPresent(String.self, forKey: .notice) ?? ""
        registrationEnabled = try c.decodeIfPresent(Bool.self, forKey: .registrationEnabled) ?? true
    }
}

nonisolated struct User: Codable, Hashable, Sendable {
    let id: String
    let email: String
    let displayName: String
    let isAdmin: Bool
    let csrfToken: String

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case csrfToken = "csrf_token"
    }
}

nonisolated struct ClaimChallenge: Codable, Hashable, Sendable {
    let record: String
    let value: String
    let expiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case record, value
        case expiresInSeconds = "expires_in_seconds"
    }
}

nonisolated enum Severity: String, Codable, Hashable, Sendable {
    case error, warning, info

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Severity(rawValue: raw) ?? .info
    }
}

nonisolated struct Problem: Codable, Hashable, Sendable {
    let code: String
    let severity: Severity
    let count: Int?
    let detail: String?
    let hint: String?
}

nonisolated struct CheckReport: Codable, Hashable, Sendable {
    nonisolated struct HTTP: Codable, Hashable, Sendable {
        let status: Int
        let etag: Bool
        let lastModified: Bool

        enum CodingKeys: String, CodingKey {
            case status, etag
            case lastModified = "last_modified"
        }
    }

    nonisolated struct Items: Codable, Hashable, Sendable {
        let total: Int
        let valid: Int
        let trustedDates: Int
        let latestPublishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case total, valid
            case trustedDates = "trusted_dates"
            case latestPublishedAt = "latest_published_at"
        }
    }

    let inputURL: String
    let feedURL: String?
    let format: String?
    let generator: String?
    let title: String?
    let latestEntryTitle: String?
    let language: String?
    let http: HTTP?
    let items: Items?
    let problems: [Problem]
    let passed: Bool

    enum CodingKeys: String, CodingKey {
        case format, generator, title, language, http, items, problems, passed
        case inputURL = "input_url"
        case feedURL = "feed_url"
        case latestEntryTitle = "latest_entry_title"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inputURL = try c.decodeIfPresent(String.self, forKey: .inputURL) ?? ""
        feedURL = try c.decodeIfPresent(String.self, forKey: .feedURL)
        format = try c.decodeIfPresent(String.self, forKey: .format)
        generator = try c.decodeIfPresent(String.self, forKey: .generator)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        latestEntryTitle = try c.decodeIfPresent(String.self, forKey: .latestEntryTitle)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        http = try c.decodeIfPresent(HTTP.self, forKey: .http)
        items = try c.decodeIfPresent(Items.self, forKey: .items)
        problems = try c.decodeIfPresent([Problem].self, forKey: .problems) ?? []
        passed = try c.decodeIfPresent(Bool.self, forKey: .passed) ?? false
    }
}

nonisolated enum SubmissionStatus: String, Codable, Hashable, Sendable {
    case pending, approved, rejected

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SubmissionStatus(rawValue: raw) ?? .pending
    }
}

nonisolated struct Submission: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let status: SubmissionStatus
    let host: String
    let siteURL: String
    let feedURL: String
    let checkReport: CheckReport?
    let reviewNote: String?
    let createdAt: Date
    let reviewedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status, host
        case siteURL = "site_url"
        case feedURL = "feed_url"
        case checkReport = "check_report"
        case reviewNote = "review_note"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
    }
}

nonisolated struct SubmissionPreview: Codable, Hashable, Sendable {
    let host: String
    let siteURL: String
    let feedURL: String
    let title: String
    let description: String
    let latestEntryTitle: String?
    let generator: String
    let language: String
    let itemsTotal: Int
    let itemsValid: Int
    let latestPublishedAt: Date?
    let checkReport: CheckReport?
    let passed: Bool

    enum CodingKeys: String, CodingKey {
        case host, title, description, generator, language, passed
        case siteURL = "site_url"
        case feedURL = "feed_url"
        case latestEntryTitle = "latest_entry_title"
        case itemsTotal = "items_total"
        case itemsValid = "items_valid"
        case latestPublishedAt = "latest_published_at"
        case checkReport = "check_report"
    }
}

/// The body of every error response.
nonisolated struct ErrorEnvelope: Decodable, Sendable {
    nonisolated struct Body: Decodable, Sendable {
        let code: String
        let message: String
    }

    let error: Body
    let submissionID: String?
    let checkReport: CheckReport?

    enum CodingKeys: String, CodingKey {
        case error
        case submissionID = "submission_id"
        case checkReport = "check_report"
    }
}

/// A notice or ad Explore publishes itself, shown between the latest posts;
/// see docs/design/notices.md in the explore repo.
nonisolated struct Notice: Codable, Hashable, Identifiable, Sendable {
    let id: String
    /// "notice" or "ad". Anything but a notice shows as an ad, so a kind
    /// added later is never left unmarked.
    let kind: String
    let title: String
    let summary: String
    /// Where it opens; empty for one that opens its page on Explore.
    let url: String
    let sourceName: String
    /// 0 before the first post, N after the Nth.
    let position: Int
    let publishedAt: Date?
    /// Plain text, only on a single notice.
    var body: String? = nil

    var isNotice: Bool { kind == "notice" }
    var isPinned: Bool { position == 0 }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, summary, url, position, body
        case sourceName = "source_name"
        case publishedAt = "published_at"
    }
}
