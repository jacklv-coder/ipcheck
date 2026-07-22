# ipcheck

[简体中文](README.zh-CN.md)

`ipcheck` is a zero-dependency Bash CLI that diagnoses the real proxy and
network path used to reach Codex and OpenAI endpoints. It reports reachability,
median and P95 time-to-first-byte (TTFB), jitter, reference bandwidth, and a
clear `GOOD`, `FAIR`, `POOR`, or `BLOCKED` result.

For Codex, latency and jitter usually matter more than peak download bandwidth.
`ipcheck` therefore scores the service path separately from the optional
bandwidth test.

## Install

### Homebrew

```bash
brew tap jacklv-coder/tap
brew install ipcheck
```

### npm

```bash
npm install --global @jacklv-coder/ipcheck
```

The npm package installs the same Bash executable and supports macOS and Linux.

### Direct download

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/jacklv-coder/ipcheck/v0.2.0/bin/ipcheck \
  -o "$HOME/.local/bin/ipcheck"
chmod +x "$HOME/.local/bin/ipcheck"
```

Make sure `$HOME/.local/bin` is on `PATH`.

## Usage

```bash
ipcheck
ipcheck --system
ipcheck --json > report.json
ipcheck --markdown > report.md
ipcheck --samples 10
ipcheck --endpoint https://your-proxy.example.com/health
```

Options:

```text
--json                 Emit machine-readable JSON.
--markdown             Emit a Markdown report.
--endpoint URL         Test one endpoint instead of the defaults (repeatable).
--samples N            Requests per endpoint (default: 5).
--timeout SECONDS      Per-request timeout (default: 20).
--no-bandwidth         Skip the 2 MB reference download test.
--system               Also run macOS networkQuality when available.
```

Use `CODEX_NETWORK_ENDPOINTS` to replace the default endpoint list:

```bash
CODEX_NETWORK_ENDPOINTS='https://chatgpt.com/|https://api.openai.com/v1/models' ipcheck
```

`HTTPS_PROXY`, `ALL_PROXY`, and their lowercase variants are respected. On
macOS, `ipcheck` also detects and uses the configured system HTTPS proxy when
no proxy environment variable is set. Proxy credentials are redacted from
reports.

## Results

| Result | Meaning |
| --- | --- |
| `GOOD` | Every primary-endpoint sample succeeded with acceptable TTFB and jitter. |
| `FAIR` | Reachable, but latency is elevated or at least one sampled request failed. |
| `POOR` | The primary path is mostly unavailable, slow, or unstable. |
| `BLOCKED` | No tested endpoint returned an HTTP response. |

HTTP 401 and 403 responses count as reachable because they prove that DNS,
proxying, TLS, and HTTP reached the remote service; authentication is outside
this network-only check. HTTP 407 does not count because it means the proxy
rejected the request before it reached the service.

Credentials embedded in endpoint URLs are masked, and query strings are
replaced with `?<redacted>` in every report format.

`GOOD` requires every primary-endpoint sample to succeed, with median TTFB below
800 ms and jitter below 1,000 ms. Any failed primary sample limits the result to
`FAIR`; a success rate below 60% is `POOR`. With full reachability, median TTFB
below 3,000 ms is `FAIR`, and slower paths are `POOR`.
The reference bandwidth download uses Cloudflare and is not treated as OpenAI
model-generation speed.

## Requirements

- Bash
- curl
- awk
- sed
- sort
- Optional on macOS: `networkQuality`

## Exit codes

- `0`: at least one endpoint was reachable
- `1`: all endpoints were blocked or unavailable
- `2`: invalid invocation or missing dependency

## License

Apache-2.0
