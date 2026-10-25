# Rootie

A tiny native macOS app that opens links in the right Chromium browser profile.
No Electron, no background service, and no browser extension for links opened
from Mail, Slack, Terminal, IDEs, and other apps.

**Website:** [rootie.hbak.co](https://rootie.hbak.co)

## Features

- Routes by exact domain, subdomain, and path prefix
- Opens the matching Chromium profile directly
- Automatic starter configuration based on installed browsers and profiles
- Plain JSON configuration at `~/.rootie/config.json`
- CLI for setup, discovery, and validation
- Automatic, cryptographically verified updates
- Native menu-bar app with negligible idle CPU use
- Universal app for Apple Silicon and Intel Macs

## Supported browsers

Rootie automatically detects:

- Helium
- Google Chrome
- Brave Browser
- Microsoft Edge
- Chromium
- Vivaldi

Other Chromium forks work by setting their application and user-data paths in
the JSON configuration.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/hmbakhsh/rootie/main/scripts/install-release.sh | zsh
```

Or with Homebrew: `brew install --cask hmbakhsh/tap/rootie` (also installs the
`rootie` command). Or download `Rootie.zip` from the
[latest release](https://github.com/hmbakhsh/rootie/releases/latest) and move
**Rootie** to your Applications folder.

**Update:** automatic. Rootie checks on launch and every 6 hours, verifies the
update's signature, and installs it in the background. To update now, choose
**Check for Updates…** from the menu bar, run `rootie update`, or re-run the
install line (it uses Homebrew if that's how you installed). Piping to
`VERSION=0.5.0 zsh` instead installs a specific release.

**Uninstall:** quit Rootie, then `brew uninstall --cask rootie`, or delete
**Rootie.app**. Your configuration stays in `~/.rootie/`; delete it too for a
clean removal.

On version 0.4.0 or earlier, or installed it as **Browser Router**? Those
versions can't update themselves. Run the install line (or
`brew upgrade --cask rootie`) once; after that, updates are automatic.

On first launch, Rootie creates `~/.rootie/config.json` using an
installed browser and profile, then opens it in your text editor. Add your rules,
save the file, choose **Reload Configuration**, then choose **Make Default
Browser** from the menu-bar icon.

You can instead configure it from Terminal:

```sh
rootie setup
rootie config
rootie validate
rootie default
```

Run `rootie help` for browser and profile discovery commands or use
`--browser` and `--profile` with `setup` for non-interactive configuration.

Add and inspect routing rules from Terminal:

```sh
rootie rules list
rootie rules add --host example.com --profile Work --include-subdomains
rootie rules add --host github.com --path-prefix /your-organization \
  --profile Work --name "Work GitHub"
```

Use `--position N` when a new rule must run before an existing broader rule.
Rootie validates the profile and configuration before writing it, and the
menu-bar app loads changes when it receives the next link.

## Agent skill

Rootie ships a portable [Agent Skill](https://agentskills.io) that lets Claude
Code, OpenCode, Codex, and other compatible agents safely add routing rules from
natural-language requests. Install it globally from this repository:

```sh
npx skills add hmbakhsh/rootie --skill rootie-routing -g
```

To target specific agents non-interactively:

```sh
npx skills add hmbakhsh/rootie --skill rootie-routing -g \
  -a claude-code -a opencode -a codex
```

Upgrading from Browser Router? Rootie automatically moves an existing
`~/.browser-router/config.json` to `~/.rootie/config.json` the first time it runs.

## JSON configuration

Use **Open Configuration** in the menu bar, or edit:

```text
~/.rootie/config.json
```

See [`config.example.json`](config.example.json) for the complete format. To use
another Chromium fork, set:

```json
{
  "browser": {
    "name": "My Chromium Fork",
    "applicationPath": "/Applications/My Browser.app",
    "userDataPath": "~/Library/Application Support/My Browser"
  }
}
```

Profile values are display names from the browser's profile menu, not directory
names. Reload after editing. Invalid JSON stops routing rather than opening a
link under the wrong identity.

Set `includeSubdomains` to match an apex domain and its subdomains. Set an
optional `pathPrefix` to limit a rule to one URL path. Rules are evaluated from
top to bottom; the first enabled match wins, and unmatched links use
`defaultProfile`.

## Build from source

Requires macOS 13 or later and Xcode 16 or later.

```sh
git clone https://github.com/hmbakhsh/rootie.git
cd rootie
./scripts/install.sh
```

Tests and release build:

```sh
swift test
./scripts/build-app.sh
```

## Limitations

- macOS only sends links from external apps to its default browser handler.
  Links clicked inside a browser require a browser extension.
- Release builds are ad-hoc signed rather than Apple-notarized. Homebrew removes
  quarantine during installation; manual downloads may require approval in
  **System Settings → Privacy & Security**.

## Privacy

Rootie routes links locally. It does not send URLs, configuration, or profile
data anywhere. Its only network request is the update check to GitHub Releases.

## License

[MIT](LICENSE)
