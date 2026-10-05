# Changelog

All notable changes to Kite for iOS, the iOS client for Explore, are documented in this file. Releases up to 0.1.3 were named Explore for iOS.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[简体中文](CHANGELOG.zh-CN.md)

## [Unreleased]

### Added

- Notices and ads that Explore publishes show on Latest, between the posts, in the same row as a post: where a post gives its time, a notice has a warm "Notice" capsule and an ad an outlined "Ad" one, with a pin when it leads the list. One with a link opens it as a post does, an ad's with `utm_source`; one without is Explore's own text and opens on a page of the app's own, laid out as on the website: who published it, its date and mark, the title and lead, the text with its web addresses linked, a card on Kite Plus (or the advertiser), the latest posts to go on to, and a share button. On a server of your own this needs the Explore release after 0.1.13; older servers simply show none.
- While a post is open, the share button of Safari's view offers Share as Card, Follow (or Unfollow) the blog, and View Blog in Kite. Share as Card brings up the post's card with its QR code, where before only the article's address could be shared; the other ways to share still send the article's link. Once you follow a link elsewhere, only the items that still fit the page stay.

### Changed

- Streams no longer split posts under Today, Yesterday and other day headings: posts run in one list, newest first, and each says when it came out, such as "3 hours ago" or "Oct 4". This applies to Discover, topics and blog pages. Recommended still lists each day's best posts first.
- The app is now called Kite, after the Kite Plus family it belongs to. Its name on the Home Screen, the mark in screenshots, share cards and the widget, and the version under Me say Kite. Explore stays the name of the service it reads: the blog directory, accounts, servers and the website.

## [0.1.3] - 2026-10-06

Discover's bar folds into a single row so posts start higher, and posts and blogs can be shared as cards with a QR code back to Explore.

### Added

- Screenshots and screen recordings carry the Explore mark between the time and the battery. It sits where the Dynamic Island or the notch covers the screen, so it never shows while you use the app.
- Share a post or a blog as a card: the post's title and excerpt, or the blog with its latest posts, under Explore's mark and over a QR code that opens it on Explore. A post opens on its share page there, which names the blog and the post and links straight to the author's site; on a server of your own that needs Explore 0.1.13. Save the card to Photos, send it on, or copy the link the code holds.

### Changed

- Discover's bar is now a single row, as feed apps have it: Filter on the left, the stream tabs in the middle and Search on the right, so posts start much higher on the screen. Filter turns solid while a language or tag is on.
- Search opens its own page with the field ready to type in. Following now shows how many blogs you follow above its posts, with the way to manage them.
- Clearer tab icons: a compass for Discover and a grid for Blogs. Buttons that take you to the author's site now show an outward arrow instead of the compass.
- Blogs' language menu opens from a filter button like Discover's, in place of the globe, and the button fills while a language is chosen.

### Fixed

- Recommended groups its posts by the device's own days. Explore 0.1.11 orders each day's posts best first, so the app now tells it which time zone those days are in; until then a post near midnight could land under the wrong day.
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
