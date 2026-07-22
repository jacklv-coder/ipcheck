# ipcheck launch kit

Use these as starting points, then answer comments in your own voice. Do not add
percentile claims: the readiness score is deliberately rule-based.

## Show HN

**Title**

Show HN: ipcheck – Diagnose the network path used by Codex and Claude Code

**Post**

I built ipcheck after repeatedly wondering whether an AI coding CLI was slow
because of the model, my proxy, or the configured gateway.

It is a zero-dependency Bash CLI that detects Codex and Claude Code routes, then
measures reachability, TTFB median/P95, jitter, and small reference download and
upload samples. It gives each client a separate verdict and a transparent
readiness score. HTTP 401/403 is treated as reachable, so no API key or billable
model request is needed.

Install:

```sh
brew tap jacklv-coder/tap
brew install ipcheck
ipcheck
```

GitHub: https://github.com/jacklv-coder/ipcheck

I would especially value feedback from developers using proxies, VPNs, or
Anthropic-compatible gateways.

## Reddit

**Title**

I made a CLI that tells you whether Codex/Claude Code is slow because of your network path

**Post**

When an AI coding session feels slow, a normal speed test is often misleading:
TTFB, jitter, failures, proxy routing, and the actual API gateway matter more
than peak download speed.

ipcheck tests the real routes configured for Codex and Claude Code without
reading or sending credentials. It reports per-client latency and reachability,
small reference download/upload measurements, and a plain-language “ready to
code?” verdict. It is MIT licensed and runs with Bash + curl on macOS and Linux.

Repo and demo: https://github.com/jacklv-coder/ipcheck

## V2EX / 掘金

**标题**

做了一个 ipcheck：一条命令判断 Codex / Claude Code 的代理网络是否适合开发

**正文**

用 Codex 或 Claude Code 时，卡顿到底是模型慢、代理节点慢，还是网关配置错了，
普通测速很难回答。

我做了一个开源命令行工具 ipcheck。它会自动识别 Codex 和 Claude Code 的真实
网络路径，检测可达性、TTFB 中位数/P95、抖动，并用少量数据测试参考下载和
上传速度，最后直接给出“现在是否适合开发”和透明的规则评分。HTTP 401/403
只代表链路可达；工具不会读取或发送 API Key，也不会产生模型调用费用。

安装：

```sh
brew tap jacklv-coder/tap
brew install ipcheck
ipcheck
```

GitHub（MIT）：https://github.com/jacklv-coder/ipcheck

如果你使用代理、VPN、国内网关或 Anthropic 兼容接口，欢迎贴匿名报告反馈。
