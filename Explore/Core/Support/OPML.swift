import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// An OPML 2.0 list of followed blogs, the format every feed reader imports.
nonisolated struct OPMLDocument: Transferable, Sendable {
    let title: String
    let blogs: [Blog]
    var created = Date.now

    var xml: String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<opml version="2.0">"#,
            "  <head>",
            "    <title>\(Self.escape(title))</title>",
            "    <dateCreated>\(created.formatted(.iso8601))</dateCreated>",
            "  </head>",
            "  <body>",
        ]
        for blog in blogs {
            let name = Self.escape(blog.name)
            lines.append(
                #"    <outline type="rss" text="\#(name)" title="\#(name)" xmlUrl="\#(Self.escape(blog.feedURL))" htmlUrl="\#(Self.escape(blog.siteURL))"/>"#
            )
        }
        lines.append("  </body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(character)
            }
        }
        return out
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .opml) { document in
            let url = URL.temporaryDirectory.appending(path: "Explore.opml")
            try Data(document.xml.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

extension UTType {
    /// Declared in Info.plist, so the file picker knows .opml files.
    nonisolated static let opml = UTType(importedAs: "org.opml.opml", conformingTo: .xml)
}
