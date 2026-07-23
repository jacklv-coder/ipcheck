# Scoring and result rules

[README](../README.md) · [简体中文](scoring.zh-CN.md)

`ipcheck` uses two related signals:

- a measured service result: `GOOD`, `FAIR`, `POOR`, or `BLOCKED`, plus
  `SKIPPED` when a provider-specific route cannot be probed safely;
- a 0–100 development-readiness score calculated with `rule_v2`.

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

## Rule v2 service-path points

The selected service path contributes up to 90 points.

| Component | Maximum | Rule |
| --- | ---: | --- |
| Reachability | 35 | 35 at 100% success, 22 at 60–99%, 10 above 0%, otherwise 0 |
| Median TTFB | 35 | 35 below 800 ms, 30 below 1,500, 22 below 3,000, 14 below 5,000, otherwise 6 |
| P95 TTFB | 10 | 10 below 2,000 ms, 7 below 4,000, 4 below 6,000, otherwise 0 |
| Jitter | 10 | 10 below 200 ms, 7 below 500, 4 below 1,000, otherwise 0 |

Blocked paths receive zero latency and stability points.

## Bandwidth adjustments

Download and upload are scored independently.

| Rating | Points per direction |
| --- | ---: |
| `FAST` | +5 |
| `ADEQUATE` | +3 |
| `SLOW` | -5 |
| Unavailable or skipped | 0 |
| Incomplete sample | an additional -2 |

Download is `FAST` from 25 Mbps and `ADEQUATE` from 5 Mbps. Upload is `FAST`
from 10 Mbps and `ADEQUATE` from 2 Mbps. These thresholds represent common
development work, not general-purpose ISP quality.

## Caps and labels

Service health limits the final score so bandwidth cannot conceal an unhealthy
AI route:

- usable `FAIR` paths are capped at 89;
- temporarily unavailable `FAIR` and `POOR` paths are capped at 64;
- `BLOCKED` paths are capped at 0.

| Score | Label |
| ---: | --- |
| 90–100 | `COMFORTABLE` |
| 75–89 | `GOOD` |
| 65–74 | `USABLE` |
| 0–64 | `LIMITED` |

Run `ipcheck --explain-score` to see every component. JSON reports expose the
same calculation under `developer_readiness.score_breakdown`.
