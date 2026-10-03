<h1 align="center">Explore for iOS</h1>

<p align="center">Discover what people publish, on iPhone and iPad.</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a>
</p>

A native client for [Explore](https://github.com/kite-plus/explore), the stream of new posts from independent blogs. It is written in Swift with SwiftUI for iOS 26 and built around Liquid Glass. Like the website, it shows titles, dates, short excerpts and thumbnails, and every post opens on the author's own site.

## Features

- **Discover**: the latest posts from every listed blog, filtered by blog language and topic, with pull to refresh and endless paging. Each post shows Explore's latest link check; posts that were never checked can be checked on the spot.
- **Following**: follow blogs and read their new posts in one stream; manage the list and export it as OPML for any feed reader.
- **Blogs**: the directory, most recently updated first, and a page for every blog with its feed, its posts and its language and blog system.
- **Search**: browse Explore's topics, or find blogs by name, address or description as you type.
- **Me**: sign in or create an account, change your name or password, delete your account, claim your blog with a DNS record, submit a blog and follow its review, and point the app at another Explore server.
- **Reading**: posts open in Safari's view inside the app, or in Safari itself if you prefer, with an optional Reader view. Links get `utm_source` as on the website; nothing else is added.
- **Widget**: the latest posts on the Home Screen in three sizes and on the Lock Screen, optionally narrowed to Chinese or English blogs. Tapping a post opens it on the author's site.
- **Languages**: English and Simplified Chinese. Titles and excerpts always stay in the language the author wrote them in.

## Liquid Glass

The app uses the system's Liquid Glass throughout rather than imitating it:

- a tab bar that shrinks while you read, with Search as its own glass tab that turns into the search field;
- a feed filter that floats over the posts, where the language switch and the topic menu share one glass container and the clear button grows out of the topic capsule;
- glass actions on blog pages over a mesh gradient in the blog's own color, zoom transitions from directory cards and topic tiles, and glass popovers for link checks;
- a layered app icon made with Icon Composer, with light, dark and tinted variants.

## Privacy

The app has no analytics and makes no requests to third parties: post thumbnails and blog icons come from the Explore server. Reading needs no account and sends no cookie. Once you sign in, the session token is kept in the keychain and sent only to the server it came from. Links to posts never go through a redirect.

## Build

You need Xcode 26 or later. Open `Explore.xcodeproj`, choose the `Explore` scheme and run it on an iPhone or iPad simulator with iOS 26 or later. To run on a device, pick your team under Signing & Capabilities.

The project has no third-party dependencies. The app lives in `Explore/`, the widget in `ExploreWidget/`, and what both use in `Shared/`:

| Folder | What it holds |
|---|---|
| `Explore/App` | the app entry point, tabs, navigation, deep links and the shared app model |
| `Explore/Core` | the API client, image loading, keychain, formatting and link handling |
| `Explore/Design` | colors, mesh backdrops, avatars and the shared glass pieces |
| `Explore/Features` | one folder per area: Discover, Following, Blogs, Search, Account and Submit |
| `Explore/Resources` | the asset catalog, the app icon, the string catalog and the privacy manifest |
| `ExploreWidget` | the Latest Posts widget |
| `Shared` | the API models, timestamps, the interface language and avatar colors |

The widget reads from explore.kite.plus; the server chosen in the app applies to the app only.

The client follows the API described in Explore's [docs/design/api.md](https://github.com/kite-plus/explore/blob/main/docs/design/api.md).

## Tests

The unit tests use Swift Testing and cover decoding, timestamps, link tagging, avatar colors, OPML export and deep links:

```bash
xcodebuild test -project Explore.xcodeproj -scheme Explore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Links into the app

`explore://` links open a screen directly, and accept the same paths as the website: `explore://blogs/{host}`, `explore://topics/{slug}`, `explore://submissions/{id}`, `explore://submit`, `explore://sign-in`, `explore://following`, `explore://search` and `explore://about`.

## License

Explore for iOS is licensed under the [Apache License 2.0](LICENSE).
