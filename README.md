# ipcheck

[![CI](https://github.com/jacklv-coder/ipcheck/actions/workflows/test.yml/badge.svg)](https://github.com/jacklv-coder/ipcheck/actions/workflows/test.yml)
[![GitHub release](https://img.shields.io/github/v/release/jacklv-coder/ipcheck)](https://github.com/jacklv-coder/ipcheck/releases)
[![License](https://img.shields.io/github/license/jacklv-coder/ipcheck)](LICENSE)

[简体中文](README.zh-CN.md)

Know whether your AI coding CLI is slow, blocked, or using the wrong gateway.

`ipcheck` is a zero-dependency Bash CLI for the real network paths used by
**Codex** and **Claude Code**. It auto-detects installed clients and safe,
non-secret routing configuration, then reports reachability, median/P95
time-to-first-byte (TTFB), jitter, reference bandwidth, and a clear
`GOOD`, `FAIR`, `POOR`, or `BLOCKED` result. Interactive runs show live,
color-coded progress and finish with a direct answer to “Ready to code?”.

```text
$ ipcheck --quick
ipcheck v0.5.0 — AI coding network diagnostics

Developer verdict
  Ready to code? YES, WITH CAUTION
  Development is possible, but responses may feel slower than ideal.

Detected clients
  Codex        model=gpt-5.6-sol, route=https://chatgpt.com + https://api.openai.com
  Claude Code  model=deepseek-v4-flash, route=https://dashscope.aliyuncs.com/apps/anthropic

Service results
  Codex        GOOD    The service path is reachable with acceptable latency and jitter.
  Claude Code  GOOD    The service path is reachable with acceptable latency and jitter.

Result: GOOD

Network bandwidth
  Download  80.0 Mbps    FAST      Cloudflare, up to 2 MB
  Upload    16.0 Mbps    FAST      Cloudflare, up to 1 MB zero-filled
  Advice    Bandwidth is sufficient for everyday AI-assisted development.
```

## Why ipcheck

- Tests the routes the clients actually use, including Claude-compatible
  `${ANTHROPIC_BASE_URL}/v1/messages` gateways.
- Detects Codex `config.toml`, custom model providers, Claude Code
  `settings.json`, `ANTHROPIC_BASE_URL`, and `ANTHROPIC_MODEL`.
- Understands OpenAI, Anthropic, LiteLLM-style gateways, and Alibaba Cloud
  Model Studio/DashScope Anthropic-compatible routes.
- Reports each client separately, so one healthy service cannot hide another
  blocked service.
- Never extracts, stores, prints, or sends API keys; never sends a prompt or
  creates a billable model request.
- Produces human, Markdown, and stable versioned JSON output for support tickets
  and automation.
- Runs on the Bash and curl already available on macOS and Linux.

For coding agents, TTFB, failures, and jitter usually matter more than peak
download bandwidth. `ipcheck` scores the service path separately from its
optional Cloudflare reference download.

## Install

### Homebrew

```bash
brew tap jacklv-coder/tap
brew install ipcheck
```

### Direct download

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/jacklv-coder/ipcheck/v0.5.0/bin/ipcheck \
  -o "$HOME/.local/bin/ipcheck"
chmod +x "$HOME/.local/bin/ipcheck"
```

Make sure `$HOME/.local/bin` is on `PATH`.

## Usage

Auto-detect installed clients:

```bash
ipcheck
ipcheck --quick
```

Select a client explicitly:

```bash
ipcheck codex
ipcheck claude
ipcheck all
ipcheck --service claude
```

Create shareable reports:

```bash
ipcheck --json > ipcheck-report.json
ipcheck --markdown > ipcheck-report.md
```

Tune or override a check:

```bash
ipcheck --samples 10
ipcheck --timeout 30
ipcheck --system
ipcheck --endpoint https://your-gateway.example.com/health
ipcheck --lang zh
ipcheck --no-progress --no-color
ipcheck --no-upload
```

The human and Markdown reports default to the terminal/system language.
English and Simplified Chinese are currently supported. Override detection with
`--lang en`, `--lang zh`, or `IPCHECK_LANG=en|zh`. JSON field names, enum values,
and diagnostic reasons remain stable English for automation. Progress is written
to stderr only for human output and can be controlled with
`IPCHECK_PROGRESS=auto|always|never`.

The service table measures time to first byte and jitter; it is not a transfer
speed test. The separate bandwidth section downloads up to 2 MB and uploads up to 1 MB of
zero-filled data through the reported proxy/network path. It rates throughput
for common development work without allowing bandwidth to hide a slow or
unstable AI service. Use `--no-upload` to skip only the upload or
`--no-bandwidth` to skip both directions.

Bandwidth ratings use development-oriented thresholds: download is `FAST` at
25 Mbps or higher and `ADEQUATE` from 5 Mbps; upload is `FAST` at 10 Mbps or
higher and `ADEQUATE` from 2 Mbps. Lower measurements are `SLOW`. The optional
`--system` test delegates to macOS `networkQuality`, which can transfer
substantially more data than ipcheck's capped Cloudflare checks.

Run `ipcheck --help` for the complete option and environment-variable list.

## Supported clients and routes

| Client | Configuration detected | Network route tested |
| --- | --- | --- |
| Codex | `$CODEX_HOME/config.toml`, `model`, `openai_base_url`, selected custom provider | ChatGPT/OpenAI defaults or the configured `/v1/responses` route |
| Claude Code | `$CLAUDE_CONFIG_DIR/settings.json`, `~/.claude/settings.json`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL` | Configured `${ANTHROPIC_BASE_URL}/v1/messages` route |
| Custom | `--endpoint`, `IPCHECK_ENDPOINTS` | User-provided GET endpoint(s) |

Legacy `CODEX_NETWORK_ENDPOINTS` remains supported. Claude-specific endpoint
overrides can use `CLAUDE_NETWORK_ENDPOINTS`.

### Alibaba Cloud + Claude Code

This common Claude Code configuration is auto-detected:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
    "ANTHROPIC_BASE_URL": "https://dashscope.aliyuncs.com/apps/anthropic",
    "ANTHROPIC_MODEL": "deepseek-v4-flash"
  }
}
```

`ipcheck claude` probes
`https://dashscope.aliyuncs.com/apps/anthropic/v1/messages` with an empty,
unauthenticated protocol check. It does not read `ANTHROPIC_AUTH_TOKEN`.

## Proxy behavior

`HTTPS_PROXY`, `HTTP_PROXY`, `ALL_PROXY`, and lowercase variants are reported
with credentials redacted. Claude probes intentionally ignore `ALL_PROXY` when
neither `HTTPS_PROXY` nor `HTTP_PROXY` is configured, matching Claude Code's
documented support boundary. On macOS, Codex and custom checks can fall back to
the configured system HTTPS proxy when an HTTPS proxy environment variable is
absent.

Claude Code supports `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY`, but does not
support SOCKS proxies. `ipcheck` warns when its detected proxy configuration is
incompatible or likely to behave differently from curl or Codex. See Anthropic's
[corporate proxy documentation](https://docs.anthropic.com/en/docs/claude-code/corporate-proxy).

## Results

| Result | Meaning |
| --- | --- |
| `GOOD` | Every primary sample succeeded with acceptable TTFB and jitter. |
| `FAIR` | Reachable, but latency is elevated, samples failed, or the API is rate-limited/unhealthy. |
| `POOR` | Mostly unavailable, very slow/unstable, or the configured API route returned HTTP 404. |
| `BLOCKED` | No primary endpoint returned an HTTP response, or the proxy returned HTTP 407. |

HTTP 401 and 403 count as network-reachable because they prove DNS, proxying,
TLS, and HTTP reached the API route. HTTP 407 does not count because the proxy
rejected the request first. A 404 on a configured `/v1/messages` or
`/v1/responses` route is reported as `POOR` with a base-URL hint.

The default thresholds are:

- `GOOD`: 100% primary success, median TTFB below 800 ms, jitter below 1,000 ms.
- `FAIR`: all samples succeed and median TTFB is below 3,000 ms, or the path is
  otherwise reachable with a recoverable warning.
- `POOR`: primary success below 60%, median TTFB at least 3,000 ms, or an invalid
  configured API route.

## Privacy and security

`ipcheck` is intentionally a network-layer diagnostic:

- The settings parser selects only named routing/model fields. Authentication
  values are never extracted into shell variables or temporary files.
- API keys, bearer tokens, and cookies are never printed or passed to curl.
- Every curl invocation starts with `-q`, so user-level `.curlrc` files cannot
  inject headers, cookies, credentials, or alternate routes.
- Claude/OpenAI protocol probes use an empty JSON object and cannot invoke a
  model successfully without authentication.
- Proxy credentials are masked. Endpoint URLs are restricted to credential-free
  HTTP/HTTPS paths; URL userinfo, query strings, and fragments are rejected.
- Temporary metrics are deleted on exit.

Please report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## JSON and exit codes

JSON output includes `schema_version`, per-service results, per-endpoint
measurements, privacy guarantees, warnings, bandwidth, and optional macOS
network quality. Additive fields may appear without changing the schema version;
breaking field changes increment it.

- `0`: at least one selected primary service path was reachable.
- `1`: every selected primary service path was blocked/unavailable.
- `2`: invalid invocation or missing dependency.

## Requirements

- Bash 3.2+
- curl
- awk, sed, sort
- Optional on macOS: `networkQuality`

## Contributing

Issues and pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md)
and the [Code of Conduct](CODE_OF_CONDUCT.md). See [CHANGELOG.md](CHANGELOG.md)
for release history.

## License

Apache-2.0
