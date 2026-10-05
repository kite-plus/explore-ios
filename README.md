<h1 align="center">Kite for iOS</h1>

<p align="center">Discover what people publish, on iPhone and iPad.</p>

<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a>
</p>

Kite is the native iOS client for [Explore](https://github.com/kite-plus/explore), the stream of new posts from independent blogs. It is written in Swift with SwiftUI for iOS 26 and built around Liquid Glass. Like the website, it shows titles, dates, short excerpts and thumbnails, and every post opens on the author's own site.

## Features

- **Discover**: Explore's three streams as tabs, as on the website: the latest posts from every listed blog, the recommended ones, and the blogs you follow. Posts are grouped by the day they came out and filtered by blog language and tag, with pull to refresh and endless paging. Each post shows Explore's latest link check; posts that were never checked can be checked on the spot.
- **Following**: follow blogs and read their new posts in Discover's Following tab; manage the list under Me and export it as OPML for any feed reader.
- **Blogs**: the directory, most recently updated first, and a page for every blog with its feed, its posts and its language and blog system.
- **Search**: the search button at the top right of Discover opens a page that browses Explore's tags and finds blogs by name, address or description as you type; the directory has its own field at the top of Blogs.
- **Me**: sign in or create an account, change your name or password, delete your account, claim your blog with a DNS record, submit a blog and follow its review, and point the app at another Explore server.
- **Reading**: as on the website, a post first shows a short page naming the blog and the post, which you can turn off, then opens in Safari's view inside the app, or in Safari itself if you prefer, with an optional Reader view. Links get `utm_source` as on the website; nothing else is added.
- **Sharing**: a post or a blog shares as a card with the Kite mark and a QR code, to save to Photos or send on. The code opens a post on its share page on Explore and a blog on its page there. While a post is open, the share button of Safari's view also offers the card, following the blog and the blog's page in the app.
- **Widget**: the latest posts on the Home Screen in three sizes and on the Lock Screen, optionally narrowed to Chinese or English blogs. Tapping a post opens it on the author's site.
- **Languages**: English and Simplified Chinese. Titles and excerpts always stay in the language the author wrote them in.

## Liquid Glass

The app uses the system's Liquid Glass throughout rather than imitating it:

- a glass tab bar that keeps all three sections in view;
- Discover's bar in a single row, as feed apps have it: glass Filter and Search buttons at either end and the stream tabs between them, whose underline follows a swipe; the filter opens a sheet with the language switch and the tags as tiles;
- glass actions on blog pages, zoom transitions from directory cards and tag tiles, and glass popovers for link checks;
- a layered app icon made with Icon Composer, with light, dark and tinted variants.

## Privacy

The app has no analytics and makes no requests to third parties: post thumbnails and blog icons come from the Explore server. Reading needs no account and sends no cookie. Once you sign in, the session token is kept in the keychain and sent only to the server it came from. Links to posts never go through a redirect.

## Build

You need Xcode 26 or later. Open `Explore.xcodeproj`, choose the `Explore` scheme and run it on an iPhone or iPad simulator with iOS 26 or later. To run on a device, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` to your team; change `APP_BUNDLE_ID` as well if `plus.kite.explore` is not yours to use. The widget's identifier follows it. Git ignores that file, so the project itself stays unchanged.

The project has no third-party dependencies. The app lives in `Explore/`, the widget in `ExploreWidget/`, and what both use in `Shared/`:

| Folder | What it holds |
|---|---|
| `Explore/App` | the app entry point, tabs, navigation, deep links and the shared app model |
| `Explore/Core` | the API client, image loading, keychain, formatting and link handling |
| `Explore/Design` | colors, avatars and the shared glass pieces, including the black and white style of main buttons |
| `Explore/Features` | one folder per area: Discover, Following, Blogs, Search, Account and Submit |
| `Explore/Resources` | the asset catalog, the app icon, the string catalog and the privacy manifest |
| `ExploreWidget` | the Latest Posts widget |
| `Shared` | the API models, timestamps, the interface language and avatar colors |

The widget reads from explore.kite.plus; the server chosen in the app applies to the app only.

The client follows the API described in Explore's [docs/design/api.md](https://github.com/kite-plus/explore/blob/main/docs/design/api.md).

## Tests

The unit tests use Swift Testing and cover decoding, timestamps, day grouping, link tagging, avatar colors, OPML export and deep links:

```bash
xcodebuild test -project Explore.xcodeproj -scheme Explore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

CI runs them on every push and pull request, along with swift-format's rules and the comment check (`sh scripts/lint.sh`), a check that every string is translated, and a Release build. [RELEASE.md](RELEASE.md) describes the checks and how releases are made, including uploads to TestFlight.

## Links into the app

`explore://` links open a screen directly, and accept the same paths as the website: `explore://blogs/{host}`, `explore://topics/{slug}`, `explore://submissions/{id}`, `explore://submit`, `explore://sign-in`, `explore://recommended`, `explore://following`, `explore://search` and `explore://about`.

## License

Kite for iOS is licensed under the [Apache License 2.0](LICENSE).
