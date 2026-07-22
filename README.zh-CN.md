# ipcheck

[English](README.md)

`ipcheck` 是一个零依赖 Bash 命令行工具，用来诊断访问 Codex/OpenAI 时
实际经过的代理和网络路径。它会测量端点可达性、首字节延迟中位数、P95、
抖动和参考带宽，并给出明确的 `GOOD`、`FAIR`、`POOR` 或 `BLOCKED` 结论。

## 安装

Homebrew：

```bash
brew tap jacklv-coder/tap
brew install ipcheck
```

npm（macOS/Linux）：

```bash
npm install --global @jacklv-coder/ipcheck
```

直接下载：

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/jacklv-coder/ipcheck/v0.2.0/bin/ipcheck \
  -o "$HOME/.local/bin/ipcheck"
chmod +x "$HOME/.local/bin/ipcheck"
```

## 使用

```bash
ipcheck
ipcheck --system
ipcheck --json > report.json
ipcheck --markdown > report.md
ipcheck --samples 10
ipcheck --endpoint https://your-proxy.example.com/health
```

工具会尊重 `HTTPS_PROXY`、`ALL_PROXY` 等代理变量；macOS 未配置代理变量时，
还会读取并使用系统 HTTPS 代理。报告中的代理凭据会被脱敏。

## 结论含义

| 结果 | 含义 |
| --- | --- |
| `GOOD` | 主端点全部采样成功，且首字节延迟和抖动较低 |
| `FAIR` | 端点可达，但延迟偏高或至少一次采样失败 |
| `POOR` | 主路径多数采样不可用、延迟高或响应不稳定 |
| `BLOCKED` | 所有端点都无法获得 HTTP 响应 |

HTTP 401/403 仍算网络可达，因为这表示 DNS、代理、TLS 和 HTTP 已经到达
远端服务，只是请求没有携带有效认证。HTTP 407 不算可达，因为它表示请求
在到达服务前就被代理拒绝。报告会隐藏端点 URL 中的凭据和查询参数。

默认规则：主端点全部采样成功、首字节延迟中位数低于 800 ms 且抖动低于
1,000 ms 为 `GOOD`；只要有采样失败，最高为 `FAIR`，成功率低于 60% 为
`POOR`。在全部采样成功时，低于 3,000 ms 为 `FAIR`，更慢则为 `POOR`。
Cloudflare 下载测试只是参考
带宽，不代表 OpenAI 模型生成速度。

## 许可证

Apache-2.0
