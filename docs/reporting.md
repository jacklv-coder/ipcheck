# Reports, automation, and exit codes

[README](../README.md) · [简体中文](reporting.zh-CN.md)

## Human output

Human output follows the terminal or system language. English and Simplified
Chinese are supported; other languages fall back to English. Override detection
with `--lang en`, `--lang zh`, or `IPCHECK_LANG=en|zh`.

Interactive progress is written to stderr and controlled with
`IPCHECK_PROGRESS=auto|always|never`, `--progress`, or `--no-progress`.
`Ctrl+C` clears the live line, removes temporary files, prints a localized
cancellation message, and exits with status 130.

Use `--no-color` or `NO_COLOR=1` for plain output.

## Markdown reports

```bash
ipcheck --markdown > ipcheck-report.md
```

Markdown reports are intended for support tickets and issue descriptions. Add
`--explain-score` when the recipient needs the full scoring calculation.

## JSON reports

```bash
ipcheck --json > ipcheck-report.json
```

JSON field names, enum values, and diagnostic reasons remain English for stable
automation. Output includes:

- `schema_version` and ipcheck version;
- overall result and developer readiness;
- per-service and per-endpoint measurements;
- score method and component breakdown;
- warnings and redacted network path;
- capped Cloudflare reference transfers and optional macOS system measurements;
- explicit privacy guarantees.

The `bandwidth` object name is retained for JSON compatibility. Its
`scope`, `method`, `represents_api_path`, and `represents_peak_bandwidth`
fields define the narrower Cloudflare reference-transfer meaning.

Additive fields may appear without changing `schema_version`; breaking field
changes increment it. Progress is disabled for JSON and Markdown modes.

## Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | At least one selected primary service path was reachable |
| `1` | Every selected primary service path was blocked or unavailable |
| `2` | Invalid invocation or missing dependency |
| `130` | Cancelled with `Ctrl+C` |

## Useful overrides

| Setting | Purpose |
| --- | --- |
| `--samples N` | Requests per endpoint |
| `--timeout N` | Per-request timeout in seconds |
| `--endpoint URL` | Test a custom credential-free GET endpoint |
| `IPCHECK_ENDPOINTS` | Pipe-separated custom endpoints |
| `CODEX_NETWORK_ENDPOINTS` | Codex endpoint override |
| `CLAUDE_NETWORK_ENDPOINTS` | Claude endpoint override |
| `IPCHECK_SERVICES` | `auto`, `codex`, `claude`, or `all` |

Run `ipcheck --help` for the authoritative complete list.
