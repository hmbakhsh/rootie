# Rootie Updater Release Runbook

Rootie uses Sparkle 2 for updates installed through every distribution channel.
GitHub Releases hosts the signed appcast, embedded Markdown release notes, and
the ad-hoc-signed universal app archive.

## Trust model

Production updates use two checks:

1. macOS verifies the app bundle's ad-hoc code signature for internal integrity.
2. Sparkle EdDSA signatures authenticate the appcast metadata and update archive
   before extraction.

`SUSignedFeedFailureExpirationInterval` is `0`, so a feed-signing failure never
expires into Sparkle's unsigned recovery path.

Ad-hoc signing does not establish an Apple-verified developer identity and the
app is not notarized. Gatekeeper may block a quarantined manual download.
Homebrew's cask removes quarantine during installation; manual users may need to
approve Rootie in **System Settings → Privacy & Security**.

The Sparkle public key is stored in `Resources/Info.plist`. Its private key was
generated under the `io.github.hmbakhsh.rootie` account in the maintainer's macOS
Keychain. Back it up securely; never commit it or print it in CI logs.

## Required GitHub Actions secret

| Secret | Purpose |
|---|---|
| `SPARKLE_PRIVATE_KEY` | Private key exported by Sparkle's `generate_keys` tool |

Repository settings must enable immutable releases before an updater-consumed
release is published.

## Versioning

- Release tags use `vMAJOR.MINOR.PATCH`.
- `CFBundleShortVersionString` is derived from the tag without `v`.
- `CFBundleVersion` is the positive, monotonically increasing GitHub Actions run
  number.
- Never reuse or decrease a build number, even when replacing a failed release.
  Publish a corrected release with a higher version/build instead.

## Release pipeline

A version tag starts `.github/workflows/release.yml`, which:

1. Runs the Swift tests and formatter checks.
2. Generates the GitHub release notes once.
3. Builds the universal app with an ad-hoc signature and nested Sparkle helpers.
4. Uses Sparkle's official tool to embed the Markdown notes, sign the archive,
   and sign `appcast.xml`.
5. Verifies bundle integrity, architectures, versions, appcast URLs, enclosure
   length, and both Sparkle signatures.
6. Uploads `Rootie.zip` and `appcast.xml` before publishing the immutable release.

The app reads the stable feed URL:

```text
https://github.com/hmbakhsh/rootie/releases/latest/download/appcast.xml
```

## Automatic updates

Rootie checks the feed on launch and every 6 hours (`SUScheduledCheckInterval`),
downloads in the background and installs immediately through
`updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)`, since Rootie is
only busy for the instant it routes a link. After relaunch it posts "Rootie
updated to X. Nothing to do on your end." **Check for Updates…** and
`rootie update` remain for updating on demand.

Config changes between releases go in `ConfigMigrations.all`
(`Sources/Rootie/Migrations.swift`). They run on every config load, oldest
first, and record progress in `~/.rootie/migrated-version`. Never remove an old
migration.

Release with `./scripts/release.sh MAJOR.MINOR.PATCH`: it tags, waits for this
workflow, then bumps the Homebrew cask's version and checksum.

## Bootstrap release

Rootie v0.4.0 does not contain Sparkle. The first updater-enabled release must be
installed once by re-running the install line or `brew upgrade --cask rootie`.
Say so in its release notes. Do not advertise `rootie update` until that
bootstrap release is available.

Before announcing it:

- update the Homebrew tap's Rootie cask to the bootstrap version and checksum;
- add `auto_updates true` while retaining its quarantine workaround;
- verify the Caskroom app link and `rootie` command still target the stable app
  in `/Applications` after installation.

## Update smoke test

Use two sequential ad-hoc-signed builds with valid Sparkle signatures. Install
the older one through each supported origin, then publish the newer one to the
test feed. Verify:

- **Check for Updates…** and `rootie update` show the same versions and notes;
- declining leaves the app and `~/.rootie/config.json` unchanged;
- accepting verifies, replaces, and relaunches the app when it was running;
- Homebrew's app and command links still resolve after replacement;
- manual apps update in both `/Applications` and `~/Applications`;
- a broken feed, offline network, invalid archive signature, and denied
  authorization each leave the prior app launchable with an actionable error;
- launching Rootie checks the feed once, then again only after 6 hours.

### Local pre-release evidence (2026-09-14)

A signed local appcast and two ad-hoc development bundles proved the engine and
terminal driver:

- `0.4.0` found `0.5.0`, displayed the embedded Markdown notes, and cancellation
  exited successfully without replacement;
- `0.5.0` reported the installed/latest versions and exited as current;
- a one-byte archive mutation was rejected before replacement as a verification
  failure with a non-zero status;
- the valid archive replaced the temporary `0.4.0` bundle, reported success,
  and the resulting app reported version `0.5.0`.

Repeat this matrix with the actual immutable GitHub release assets before
advertising the updater-enabled bootstrap release.

## Recovery and key rotation

Do not mutate an immutable bad release. Remove it from latest selection if
necessary and publish a corrected higher version. Existing users can always use
the release page for a manual reinstall.

If the Sparkle key must rotate, follow Sparkle's key-rotation rules so existing
clients can verify the transition.
