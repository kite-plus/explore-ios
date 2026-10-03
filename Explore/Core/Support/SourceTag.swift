import Foundation

nonisolated enum SourceTag {
    /// Adds utm_source so the author's analytics can tell a visit came from
    /// Explore, as the website does. The rest of the address is untouched
    /// and an existing utm_source wins.
    static func tagged(_ url: URL, source: String) -> URL {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        if components.queryItems?.contains(where: { $0.name == "utm_source" }) == true {
            return url
        }
        let value = source.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? source
        let parameter = "utm_source=\(value)"
        if let query = components.percentEncodedQuery, !query.isEmpty {
            components.percentEncodedQuery = query + "&" + parameter
        } else {
            components.percentEncodedQuery = parameter
        }
        return components.url ?? url
    }
}
