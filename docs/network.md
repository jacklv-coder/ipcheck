# Routes, proxies, and bandwidth

[README](../README.md) · [简体中文](network.zh-CN.md)

## Routes tested

`ipcheck` tests the protocol route the detected client is expected to use:

| Client | Route |
| --- | --- |
| Codex defaults | ChatGPT Codex or OpenAI Responses protocol route, ordered by detected login mode |
| Codex custom provider | Configured base URL plus `/v1/responses` when needed |
| Claude Code | `${ANTHROPIC_BASE_URL}/v1/messages` |
| Custom | Credential-free URL supplied with `--endpoint` or `IPCHECK_ENDPOINTS` |

`CODEX_NETWORK_ENDPOINTS` remains supported for compatibility. Claude-specific
overrides can use `CLAUDE_NETWORK_ENDPOINTS`.

Codex's built-in Amazon Bedrock provider uses provider-specific authentication.
Without `CODEX_NETWORK_ENDPOINTS`, ipcheck reports it as `SKIPPED` rather than
probing an unrelated OpenAI route.

Direct Anthropic and Anthropic-compatible gateways are auto-probed. Provider-
native modes such as Amazon Bedrock, Google Vertex AI, Foundry, and Mantle use
provider-specific authenticated protocols, so `ipcheck` skips automatic Anthropic probing and asks for an explicit
credential-free `CLAUDE_NETWORK_ENDPOINTS` route instead of reporting a result
for the wrong provider. The provider appears as `SKIPPED` and the overall result
is `UNAVAILABLE` when no other client route can be measured.

## Proxy behavior

`HTTPS_PROXY`, `HTTP_PROXY`, `ALL_PROXY`, and lowercase variants are reported
with credentials redacted.

- Codex and custom checks can fall back to the macOS system HTTPS proxy when no
  HTTPS proxy environment variable is configured.
- Current Claude Code builds honor `HTTPS_PROXY`, `HTTP_PROXY`, and
  `NO_PROXY`/`no_proxy` bypass rules. Anthropic's public corporate-proxy page
  may still describe `NO_PROXY` as unsupported. `ALL_PROXY` and SOCKS proxies
  are not used for Claude probes.
- Claude probes therefore ignore `ALL_PROXY` unless `HTTPS_PROXY` or
  `HTTP_PROXY` is also configured.
- Claude probes do not explicitly copy the macOS HTTP proxy into curl. System,
  VPN, or TUN routing can still carry that traffic, so this is not labeled as a
  guaranteed direct connection.
- `ipcheck` warns when the detected proxy is incompatible or likely to differ
  from the client's actual route.

See Anthropic's
[corporate proxy documentation](https://docs.anthropic.com/en/docs/claude-code/corporate-proxy).

## Alibaba Cloud / DashScope example

Given this Claude Code configuration:

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
unauthenticated protocol request. It never reads `ANTHROPIC_AUTH_TOKEN`.

## Reference bandwidth

The service table measures time to first byte and jitter; it is not a transfer
speed test. The separate bandwidth section:

- downloads at most 2 MB from Cloudflare;
- uploads at most 1 MB of zero-filled data;
- uses the reported proxy/network path;
- treats incomplete transfers as estimates;
- never lets high bandwidth hide an unhealthy service route.

Use `--no-upload` to skip upload only, or `--no-bandwidth` to skip both. The
optional `--system` flag runs macOS `networkQuality`, which may transfer
substantially more data than ipcheck's capped checks.

## Endpoint safety

Custom endpoints must use HTTP or HTTPS and cannot contain URL credentials,
query strings, or fragments. Every curl invocation starts with `-q`, so a user
`.curlrc` cannot inject credentials, headers, cookies, or alternate routes.
