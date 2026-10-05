# Changelog

All notable changes to Explore for iOS are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[简体中文](CHANGELOG.zh-CN.md)

## [Unreleased]

### Changed

- Discover's bar is now a single row, as feed apps have it: Filter on the left, the stream tabs in the middle and Search on the right, so posts start much higher on the screen. Filter turns solid while a language or tag is on.
- Search opens its own page with the field ready to type in. Following now shows how many blogs you follow above its posts, with the way to manage them.

### Fixed

- A blog's page shows the blog's own icon as its large avatar, as the website does, instead of the first letter with the icon tucked into a corner. An icon too small to fill the circle sits in its middle rather than being blown up.

## [0.1.2] - 2026-10-05

A small update: Discover's streams now follow a swipe, the way most reading apps do.

### Added

- Swipe left or right on Discover to move between Latest, Recommended and Following. The line under the tabs follows your finger, each stream keeps your place, and tapping Discover again still takes the stream you are on back to the top.

## [0.1.1] - 2026-10-04

A small update: posts now open the way they do on the website, by way of a short page that says where you are going.

### Added

- Opening a post first shows a short page, as the website does, naming the blog and the post while a bar fills; then Safari's view opens, or Safari itself if you prefer. Turn off Show Transition Page under Me to open posts straight away.

## [0.1.0] - 2026-10-04

The first release of Explore for iOS: a native client for [Explore](https://github.com/kite-plus/explore) on iPhone and iPad, written in SwiftUI for iOS 26 and built around Liquid Glass. It reads explore.kite.plus by default and can connect to any other Explore server running 0.1.6 or later. It is not on the App Store or TestFlight yet; the README explains how to build it with Xcode.

### Added

- Discover: Latest, Recommended and Following as tabs, as on the website, with posts grouped by the day they came out and filtered by blog language and tag. Every post opens on the author's own site, in Safari's view inside the app or in Safari itself, with only `utm_source` added.
- Blogs: the directory, most recently updated first, a page for every blog, and search over blogs and tags.
- Accounts: sign in or create an account, follow blogs, manage the list and export it as OPML, claim your blog with a DNS record, submit a blog and follow its review, and report a problem.
- Link checks: each post shows Explore's latest check of its link, and a post never checked can be checked on the spot.
- A Latest Posts widget in three sizes for the Home Screen and two for the Lock Screen.
- English and Simplified Chinese. Titles and excerpts stay in the language the author wrote them in.
- No analytics and no requests to third parties; reading needs no account.
