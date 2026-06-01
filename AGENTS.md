# Codex Project Rules

This repository is a SwiftUI macOS terminal and remote-session manager.

## Workflow

- Before editing, run `git status --short --branch`.
- Keep changes scoped to the user's request.
- After code changes, run `swift build`.
- For release-sensitive changes, also run `swift build -c release`.
- Commit every completed change before ending the task.
- Do not rewrite or revert user changes unless the user explicitly asks.

## Commit Style

- Use concise imperative commit messages, for example:
  - `Add remote SFTP browser`
  - `Fix serial session launch`
  - `Persist connection type`
- One logical change per commit when practical.

## Product Direction

The app should grow toward a MobaXterm-like workflow on macOS:

- Session manager for SSH, SFTP, Telnet, FTP, Serial, RDP, and VNC.
- Strong defaults for terminal reliability and security.
- Keychain-backed secrets.
- Integrated network tools.
- Remote file browsing and transfer.
- SSH tunnels and jump hosts.
- Keyboard-focused workflows for power users.
