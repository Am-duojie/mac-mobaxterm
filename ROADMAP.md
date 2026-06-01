# Roadmap

## Next

- Complete SFTP upload, download, rename, delete, and mkdir operations.
- Add SSH tunnel manager for local, remote, and dynamic forwarding.
- Add jump host and proxy command support.
- Improve connection editor validation and per-protocol forms.
- Add app-level logging for failed launches and network-tool errors.

## Later

- Multi-exec commands across selected SSH sessions.
- Terminal split panes.
- Macro recording and replay.
- Snippets and quick commands.
- Import/export formats compatible with common SSH managers.
- Optional cloud sync for non-secret connection metadata.

## Quality

- Add tests when the local Swift toolchain exposes a usable test framework.
- Add UI smoke checks for key workflows.
- Keep all credentials in Keychain, never in exported JSON unless explicitly encrypted.
