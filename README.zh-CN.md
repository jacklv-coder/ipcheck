# ipcheck

[![CI](https://github.com/jacklv-coder/ipcheck/actions/workflows/test.yml/badge.svg)](https://github.com/jacklv-coder/ipcheck/actions/workflows/test.yml)
[![GitHub Release](https://img.shields.io/github/v/release/jacklv-coder/ipcheck)](https://github.com/jacklv-coder/ipcheck/releases)
[![License](https://img.shields.io/github/license/jacklv-coder/ipcheck)](LICENSE)

[English](README.md)

快速判断 AI 编程 CLI 到底是网络慢、代理被拦，还是网关地址配错。

`ipcheck` 是一个零依赖 Bash 命令行工具，面向 **Codex** 和
**Claude Code** 的真实网络路径。它会自动识别本机客户端以及不含密钥的路由
配置，测量可达性、首字节延迟（TTFB）中位数/P95、抖动和参考带宽，并给出
明确的 `GOOD`、`FAIR`、`POOR` 或 `BLOCKED` 结论。交互运行时会显示带颜色的
实时进度，并直接告诉你“现在是否适合开发”。

```text
$ ipcheck --quick
ipcheck v0.4.0 — AI 编程网络诊断

开发建议
  现在适合开发吗？可以，但会有些慢
  当前可以开发，但响应速度可能不够理想。

Detected clients
  Codex        model=gpt-5.6-sol, route=https://chatgpt.com + https://api.openai.com
  Claude Code  model=deepseek-v4-flash, route=https://dashscope.aliyuncs.com/apps/anthropic

Service results
  Codex        GOOD
  Claude Code  GOOD

Result: GOOD
```

## 核心能力

- 检测客户端真实协议路径，包括 Claude 兼容网关的
  `${ANTHROPIC_BASE_URL}/v1/messages`。
- 自动识别 Codex `config.toml`、自定义模型提供商、Claude Code
  `settings.json`、`ANTHROPIC_BASE_URL` 和 `ANTHROPIC_MODEL`。
- 兼容 OpenAI、Anthropic、LiteLLM 类网关，以及阿里云百炼/DashScope
  Anthropic 兼容入口。
- Codex 与 Claude Code 分别评分，避免一个正常服务掩盖另一个被拦服务。
- 不提取、不保存、不显示也不发送 API Key；不发送 Prompt，不产生模型调用费用。
- 支持终端、Markdown 和带版本号的 JSON 报告，方便提工单或接入自动化。

对 AI 编程工具而言，首字节延迟、失败率和抖动通常比峰值下载带宽更重要。
因此服务路径与 Cloudflare 参考下载会分开评分。

## 安装

Homebrew：

```bash
brew tap jacklv-coder/tap
brew install ipcheck
```

直接下载：

```bash
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/jacklv-coder/ipcheck/v0.4.0/bin/ipcheck \
  -o "$HOME/.local/bin/ipcheck"
chmod +x "$HOME/.local/bin/ipcheck"
```

## 使用

自动识别客户端：

```bash
ipcheck
ipcheck --quick
```

只检查指定客户端：

```bash
ipcheck codex
ipcheck claude
ipcheck all
ipcheck --service claude
```

生成可分享报告：

```bash
ipcheck --json > ipcheck-report.json
ipcheck --markdown > ipcheck-report.md
```

其他常用选项：

```bash
ipcheck --samples 10
ipcheck --timeout 30
ipcheck --system
ipcheck --endpoint https://your-gateway.example.com/health
ipcheck --lang en
ipcheck --no-progress --no-color
```

终端和 Markdown 报告默认跟随终端/系统语言，目前支持中文和英文。可以使用
`--lang zh`、`--lang en`，或 `IPCHECK_LANG=zh|en` 明确指定。JSON 的字段名、
枚举值和诊断原因始终保持英文，方便自动化脚本稳定解析。实时进度只会在普通
终端报告中写入 stderr，可通过 `IPCHECK_PROGRESS=auto|always|never` 控制。

运行 `ipcheck --help` 可以查看完整参数。

## 支持的客户端与配置

| 客户端 | 自动读取的非敏感配置 | 检测路径 |
| --- | --- | --- |
| Codex | `$CODEX_HOME/config.toml`、`model`、`openai_base_url`、当前自定义 provider | ChatGPT/OpenAI 默认路径或自定义 `/v1/responses` |
| Claude Code | `$CLAUDE_CONFIG_DIR/settings.json`、`~/.claude/settings.json`、`ANTHROPIC_BASE_URL`、`ANTHROPIC_MODEL` | `${ANTHROPIC_BASE_URL}/v1/messages` |
| 自定义 | `--endpoint`、`IPCHECK_ENDPOINTS` | 用户指定的 GET 地址 |

原有 `CODEX_NETWORK_ENDPOINTS` 保持兼容；Claude 可使用
`CLAUDE_NETWORK_ENDPOINTS` 覆盖端点。

### 阿里云百炼 + Claude Code

下面这种配置会被自动识别：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
    "ANTHROPIC_BASE_URL": "https://dashscope.aliyuncs.com/apps/anthropic",
    "ANTHROPIC_MODEL": "deepseek-v4-flash"
  }
}
```

执行 `ipcheck claude` 时会检测：

```text
https://dashscope.aliyuncs.com/apps/anthropic/v1/messages
```

检测请求不携带 `ANTHROPIC_AUTH_TOKEN`，也不会触发模型推理计费。

## 代理行为

工具会显示 `HTTPS_PROXY`、`HTTP_PROXY`、`ALL_PROXY` 及其小写形式，并对
用户名、密码进行脱敏。若没有配置 `HTTPS_PROXY` 或 `HTTP_PROXY`，Claude
检测会忽略其官方未声明支持的 `ALL_PROXY`。在 macOS 上，Codex/自定义检测
还可以在没有 HTTPS 代理环境变量时使用系统 HTTPS 代理。

Claude Code 支持 `HTTPS_PROXY`、`HTTP_PROXY` 和 `NO_PROXY`，但不支持
SOCKS。检测到不兼容或与 Codex/curl 路径可能不同的配置时，`ipcheck` 会明确警告。
详见 Anthropic 的
[企业代理文档](https://docs.anthropic.com/en/docs/claude-code/corporate-proxy)。

## 结论含义

| 结果 | 含义 |
| --- | --- |
| `GOOD` | 主端点全部采样成功，TTFB 与抖动均在合理范围 |
| `FAIR` | 网络可达，但延迟偏高、存在失败，或 API 正在限流/异常 |
| `POOR` | 多数不可用、非常慢/不稳定，或配置的 API 路径返回 404 |
| `BLOCKED` | 主端点没有 HTTP 响应，或代理返回 HTTP 407 |

HTTP 401/403 仍算网络可达，因为这表示 DNS、代理、TLS 和 HTTP 已到达 API
路径；HTTP 407 表示请求先被代理拒绝。配置的 `/v1/messages` 或
`/v1/responses` 返回 404 时，会判定为 `POOR` 并提示检查 Base URL。

默认阈值：

- `GOOD`：主路径 100% 成功，中位 TTFB 小于 800 ms，抖动小于 1,000 ms。
- `FAIR`：全部成功且中位 TTFB 小于 3,000 ms，或出现可恢复的服务警告。
- `POOR`：成功率低于 60%、中位 TTFB 至少 3,000 ms，或 API 路径无效。

## 隐私与安全

- 配置解析只提取指定的路由和模型字段，认证值不会进入 Shell 变量或临时文件。
- 不显示 API Key、Bearer Token 或 Cookie，也不会把它们传给 curl。
- 所有 curl 调用均以 `-q` 开始，用户级 `.curlrc` 无法注入请求头、Cookie、
  凭据或替换检测地址。
- Claude/OpenAI 协议探测只发送空 JSON，且不带认证，因此不会调用模型。
- 代理凭据会被隐藏；端点只允许无凭据的 HTTP/HTTPS 路径，URL 用户信息、
  查询参数和片段会被拒绝。
- 临时指标文件会在程序退出时删除。

安全问题请按照 [SECURITY.md](SECURITY.md) 私下报告。

## JSON 与退出码

JSON 包含 `schema_version`、每个客户端与端点的独立结论、隐私声明、警告、
带宽和可选的 macOS `networkQuality` 数据。增加兼容字段不会升级 schema；
破坏性字段调整才会升级版本。

- `0`：至少一个主服务路径可达。
- `1`：全部主服务路径被阻断或不可用。
- `2`：参数错误或缺少运行依赖。

## 运行要求

- Bash 3.2+
- curl
- awk、sed、sort
- macOS 可选：`networkQuality`

## 参与贡献

欢迎提交 Issue 和 Pull Request。请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)
和 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。版本历史见
[CHANGELOG.md](CHANGELOG.md)。

## 许可证

Apache-2.0
