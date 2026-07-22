# Changelog

All notable changes to ipcheck are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-07-22

### Added

- Claude Code auto-detection through `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`,
  `CLAUDE_CONFIG_DIR`, and `~/.claude/settings.json`.
- Safe Anthropic-compatible `/v1/messages` protocol probes with no credentials,
  prompt, or billable inference request.
- Codex custom-provider and `openai_base_url` route detection.
- Per-client results, route validation, privacy metadata, warnings, and a
  versioned JSON schema.
- `codex`, `claude`, and `all` selectors plus `--service`, `--quick`, and
  `--version`.
- Warnings for Claude Code SOCKS and macOS system-proxy differences.
- Release automation, ShellCheck, pinned GitHub Actions, Dependabot, and project
  community files.

### Changed

- Generalized the report from Codex-only diagnostics to AI coding CLI
  diagnostics.
- HTTP 404 on a configured protocol route is now reported as `POOR`; HTTP 429
  and 5xx responses are reported as `FAIR` service conditions.
- Expanded privacy and configuration-redaction tests.

## [0.2.0] - 2026-07-22

### Added

- Initial Codex/OpenAI path diagnostics.
- Human, Markdown, and JSON reports.
- Homebrew and direct-download packaging.
- Median/P95 TTFB, jitter, reference bandwidth, and macOS `networkQuality`.

[0.3.0]: https://github.com/jacklv-coder/ipcheck/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jacklv-coder/ipcheck/releases/tag/v0.2.0
