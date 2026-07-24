# Scoring and result rules

[README](../README.md) · [简体中文](scoring.zh-CN.md)

`ipcheck` uses two related signals:

- a measured service result: `GOOD`, `FAIR`, `POOR`, or `BLOCKED`, plus
  `SKIPPED` when a provider-specific route cannot be probed safely;
- a 0–100 development-readiness score calculated with `rule_v4`.

The score is a transparent heuristic, not a user percentile or a benchmark of
model intelligence.

TTFB comes from credential-free protocol probes. It includes DNS, proxy, TLS,
network, and gateway ingress, but not authentication or model generation. P95
uses the nearest-rank method; with the default three samples it is effectively
the slowest sample. Jitter is the root-mean-square deviation from the sample
median. Use more samples when comparing close results.

## Service results

| Result | Default rule |
| --- | --- |
| `GOOD` | 100% primary success, median TTFB below 800 ms, jitter below 1,000 ms |
| `FAIR` | Reachable with median TTFB below 3,000 ms, recoverable failures, rate limiting, or server errors |
| `POOR` | Primary success below 60%, median TTFB at least 3,000 ms, or HTTP 404 on a configured API route |
| `BLOCKED` | No primary HTTP response, or proxy authentication stopped the request with HTTP 407 |
| `SKIPPED` | The provider needs an explicit credential-free endpoint before it can be measured |

With multiple clients, results remain independent. If every client is blocked,
the overall result is `BLOCKED`; if blocked and reachable clients are mixed, it
is `POOR`; otherwise the least healthy client result is used. The readiness
score always uses the lowest-scoring service path, so a healthy Claude route
cannot hide a broken Codex route.

Skipped clients do not affect another measured client's score. If every
selected client is skipped, the overall result is `UNAVAILABLE`, the score is
0, and the command exits with status 1.

## Rule v4 dimensions

The score has two visible dimensions:

- **AI interaction: 80 points.** The lowest-scoring selected service path
  measures reachability, credential-free protocol TTFB, P95, and jitter.
- **Engineering transfer: 20 points.** Two small download samples and two
  zero-filled upload samples measure the current proxy path to Cloudflare.

This weighting makes sustained transfer limitations materially affect the
result without letting a CDN path outweigh the actual Codex or Claude protocol
path. Editing files is local; network transfer matters mainly when sending
context, receiving responses, cloning repositories, and installing
dependencies.

### AI interaction: 80 points

| Component | Maximum | Rule |
| --- | ---: | --- |
| Reachability | 30 | 30 at 100% success, 19 at 60–99%, 8 above 0%, otherwise 0 |
| Median TTFB | 30 | 30 below 800 ms, 26 below 1,500, 19 below 3,000, 12 below 5,000, otherwise 5 |
| P95 TTFB | 10 | 10 below 2,000 ms, 7 below 4,000, 4 below 6,000, otherwise 0 |
| Jitter | 10 | 10 below 200 ms, 7 below 500, 4 below 1,000, otherwise 0 |

Blocked paths receive zero latency and stability points.

### Engineering transfer: 20 points

Download and upload each contribute up to 10 points. The displayed speed is the
mean of valid samples in that direction.

| Direction | 10 points | 7 points | 4 points | 0 points |
| --- | ---: | ---: | ---: | ---: |
| Download | at least 10 Mbps | at least 3 Mbps | at least 1 Mbps | below 1 Mbps |
| Upload | at least 5 Mbps | at least 1 Mbps | at least 0.3 Mbps | below 0.3 Mbps |

The ratings are `COMFORTABLE`, `MILDLY LIMITED`, `CONSTRAINED`, and
`SEVERELY LIMITED`. They apply only to these capped Cloudflare samples and are
not general-purpose ISP ratings.

Skipped or unavailable transfer directions receive a neutral 10 points so
firewalls, offline reporting, or `--no-bandwidth` do not create a false
penalty. The dimension is labelled `UNMEASURED`, and JSON reports its
confidence. A partial sample can still supply an estimate, but lowers
confidence and cannot by itself establish a confirmed bottleneck.

## Caps and labels

The raw dimension total is limited by both service and transfer evidence.
Service caps are:

- usable `FAIR` paths are capped at 89;
- temporarily unavailable `FAIR` and `POOR` paths are capped at 64;
- `BLOCKED` paths are capped at 0.

Transfer caps require repeat evidence:

- when both valid samples in either direction are `CONSTRAINED` or worse, the
  total is capped at 79;
- when both valid samples in either direction are `SEVERELY LIMITED`, the
  total is capped at 74;
- one valid `SEVERELY LIMITED` estimate caps the total at 89, but is not treated
  as confirmed.

The final cap is the lower of the service and transfer caps. This prevents an
excellent TTFB from hiding a repeatedly unusable transfer path while avoiding
a strong conclusion from one partial sample.

| Score | Label |
| ---: | --- |
| 90–100 | `COMFORTABLE` |
| 75–89 | `GOOD` |
| 65–74 | `USABLE` |
| 0–64 | `LIMITED` |

Run `ipcheck --explain-score` to see both dimensions, their components, and all
caps. JSON schema 3 exposes the same calculation under
`developer_readiness.dimensions` and `developer_readiness.score_breakdown`.
