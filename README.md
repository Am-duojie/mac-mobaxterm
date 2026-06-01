# MacMobaXterm

MacMobaXterm is a SwiftUI macOS remote-session toolbox inspired by MobaXterm.
It combines terminal sessions, saved connections, network tools, and remote file browsing in one native app.

## Current Features

- Local terminal tabs powered by SwiftTerm
- Saved SSH, SFTP, Telnet, FTP, Serial, RDP, and VNC sessions
- Keychain-backed credential storage
- Session folders, favorites, duplication, import, and export
- Network tools: ping, traceroute, DNS lookup, whois, port scan, and interface info
- SSH-based remote directory browsing panel
- User defaults for terminal font, SSH timeout, keepalive, and host-key policy

## Build

```bash
swift build
```

Release build:

```bash
swift build -c release
```

## Development

Before changing code, check the worktree:

```bash
git status --short --branch
```

After changes:

```bash
swift build
git add .
git commit -m "Describe the change"
```

## Local Test Lab

Use [test-lab](test-lab/README.md) to start local SSH/SFTP, FTP, Telnet, and virtual serial targets for manual testing.
