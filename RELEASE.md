# Releasing

Cutting a release is: write both changelogs, tag and push. The release workflow does the rest: it runs CI's checks, archives the app, uploads it to App Store Connect when signing is set up, and publishes the GitHub Release.

## What CI checks

`.github/workflows/ci.yml` runs on every push to `main` and every pull request, on a macOS runner with its newest release of Xcode:

- **Review** (`scripts/lint.sh`): swift-format's rules with the house style in `.swift-format`, and code comments in plain ASCII English. Line breaks are left to the author, so swift-format's findings about them do not count. Run it before you push; `swift format format --in-place <file>` fixes most findings, but check how it broke the lines.
- **Build** for the simulator with warnings treated as errors.
- **Strings** (`scripts/check-strings.py`): every string the app or the widget shows has a Simplified Chinese translation in its string catalog, and the catalogs keep no string the code no longer uses.
- **Test**: the unit tests, on an iPhone simulator with the newest iOS the runner has.
- **Release build**: the Release configuration, for a device and unsigned, also with warnings as errors.

## 1. Write the changelogs

In `CHANGELOG.md` and `CHANGELOG.zh-CN.md`, add a `## [<version>] - <date>` section below the `Unreleased` (`未发布`) heading, which stays and is left empty, and move that heading's items into it.

Start the section with a sentence or two on what the release is about, then group the changes under Added, Changed and Fixed (新增、变更、修复). Write for the people who use the app, not in commit subjects.

The release notes are built from these sections by `scripts/release-notes.sh`: the Chinese section is the body of the GitHub Release, the English one is linked from it, and a compare link with the previous tag follows. To see what the release will carry:

```bash
PREVIOUS_TAG=v0.1.0 sh scripts/release-notes.sh v0.1.1
```

A version without a section in both files fails the release before anything is built.

## 2. Tag and push

```bash
git tag -a v<version> -m v<version>
git push origin main v<version>
```

The tag sets the version (`MARKETING_VERSION`), and the workflow's run number sets the build number, so the project's own version only matters for local builds. A tag with a `-` suffix, such as `v0.2.0-rc.1`, ships as `0.2.0` and makes a prerelease on GitHub.

Pushing the tag starts `.github/workflows/release.yml`:

1. CI's checks, as above.
2. The release notes, from the changelogs.
3. An archive of the Release configuration. With signing set up (below), Xcode signs it with cloud-managed certificates and uploads it to App Store Connect, where it appears in TestFlight once Apple has processed it. Without signing, the archive is built unsigned to prove the release builds, and nothing is uploaded; the run's summary says so.
4. The GitHub Release `Kite for iOS v<version>` with the notes. Re-running the workflow updates it instead of failing.

A manual run of the workflow archives without signing or publishing.

## Setting up signing

Once the Apple Developer Program membership is active, this is done once. Uploads use an App Store Connect API key, so no certificate or profile is kept in the repository: Xcode creates what it needs with the key, and Apple keeps the distribution certificate.

1. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), check that `plus.kite.explore` and `plus.kite.explore.widget` can be yours. If another team has them, pick other identifiers and set the `APP_BUNDLE_ID` variable below; the widget's follows as `<APP_BUNDLE_ID>.widget`.
2. In [App Store Connect](https://appstoreconnect.apple.com), create the app under Apps with that bundle identifier, named Kite Explore. Uploads need the app to exist. The store name differs from the Home Screen name, Kite, because Kite alone is taken on the App Store; the two only need to be recognizably the same app.
3. Under Users and Access, Integrations, App Store Connect API, create a team key with the Admin role, which signing needs to create certificates and profiles. Download the key file; Apple offers it once. Note the key ID and the issuer ID shown above the list of keys.
4. In the GitHub repository, under Settings, Secrets and variables, Actions, add:

   | Name | Kind | Value |
   |---|---|---|
   | `ASC_KEY_ID` | secret | the key ID |
   | `ASC_ISSUER_ID` | secret | the issuer ID |
   | `ASC_KEY_P8` | secret | the whole text of the `.p8` key file |
   | `APPLE_TEAM_ID` | variable | the team ID from the membership details |
   | `APP_BUNDLE_ID` | variable | only when it is not `plus.kite.explore` |

5. Push the next tag. The first signed run is the real test of this path: if it fails, the archive or export step's log names what Apple refused.

`Config/Info.plist` already declares that the app uses no non-exempt encryption, so builds do not wait on the export compliance question. Before the first App Store submission, App Store Connect also needs the listing: screenshots, a description, the privacy details and a support address.

To keep `main` green, require the Check and Release build jobs in a branch protection rule for `main`.
