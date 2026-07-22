# Changelog

All notable changes to ipcheck are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [0.6.0] - 2026-07-22

### Added

- A visible `Ctrl+C` cancellation hint and graceful interrupt handling with
  localized feedback, temporary-file cleanup, and exit status 130.
- A transparent 0–100 developer-readiness score in human, Markdown, and JSON
  reports. The score is explicitly rule-based rather than a user percentile.

## [0.5.0] - 2026-07-22

### Added

- A safe 1 MB zero-filled Cloudflare upload test alongside the existing 2 MB
  reference download.
- Separate download/upload ratings, test-path disclosure, and plain-language
  bandwidth advice in human and Markdown reports.
- Structured `bandwidth.download` and `bandwidth.upload` JSON objects while
  preserving the existing download fields for compatibility.
- `--no-upload` to skip only the upload measurement.

### Changed

- The bandwidth section now clearly separates throughput from AI service TTFB.
- macOS `networkQuality --system` reports both download and upload throughput.

## [0.4.0] - 2026-07-22

### Added

- Live service and sample progress on interactive terminals, with a quiet mode
  for scripts and structured reports.
- Automatic English/Chinese output based on the terminal or macOS system
  language, plus `--lang` and `IPCHECK_LANG` overrides.
- A plain-language developer readiness verdict in human, Markdown, and JSON
  reports.
- TTY-aware color output with `--color`, `--no-color`, and `NO_COLOR` support.

### Changed

- Human reports now lead with an actionable answer and recommendation.
- Numeric output always uses a dot decimal separator, independent of locale.

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

[0.6.0]: https://github.com/jacklv-coder/ipcheck/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/jacklv-coder/ipcheck/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/jacklv-coder/ipcheck/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/jacklv-coder/ipcheck/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jacklv-coder/ipcheck/releases/tag/v0.2.0
