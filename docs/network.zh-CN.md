# 服务路径、代理与参考传输

[中文 README](../README.zh-CN.md) · [English](network.md)

## 检测的服务路径

`ipcheck` 会检测客户端实际预期使用的协议路径：

| 客户端 | 检测路径 |
| --- | --- |
| Codex 默认配置 | 尽可能按登录方式选择 ChatGPT Codex 或 OpenAI Responses 协议路径 |
| Codex 自定义 provider | 配置的 Base URL，必要时补充 `/v1/responses` |
| Claude Code | `${ANTHROPIC_BASE_URL}/v1/messages` |
| 自定义 | 通过 `--endpoint` 或 `IPCHECK_ENDPOINTS` 提供的无凭据 URL |

`CODEX_NETWORK_ENDPOINTS` 保持兼容；Claude 可使用
`CLAUDE_NETWORK_ENDPOINTS` 覆盖端点。

Codex 内置的 Amazon Bedrock provider 使用专用认证协议。未设置
`CODEX_NETWORK_ENDPOINTS` 时，ipcheck 会将其报告为“已跳过”，不会误测
无关的 OpenAI 路径。

Anthropic 直连与 Anthropic 兼容网关会自动探测。Amazon Bedrock、Google
Vertex AI、Foundry、Mantle 等 provider 原生模式使用各自的认证协议，因此 `ipcheck` 会跳过 Anthropic 自动探测，
并要求通过 `CLAUDE_NETWORK_ENDPOINTS` 明确提供无凭据检测路径，避免对错误的
provider 给出结论。该 provider 会显示为“已跳过”；没有其他可测客户端链路时，
总结果显示为 `UNAVAILABLE`。

## 代理行为

`HTTPS_PROXY`、`HTTP_PROXY`、`ALL_PROXY` 及其小写形式会被显示，其中凭据
会被脱敏。

- 没有 HTTPS 代理环境变量时，Codex 和自定义检测可以使用 macOS 系统
  HTTPS 代理。
- 当前 Claude Code 已实际支持 `HTTPS_PROXY`、`HTTP_PROXY` 与
  `NO_PROXY`/`no_proxy` 绕过规则；Anthropic 公开的企业代理页面可能仍写着
  `NO_PROXY` 不受支持。Claude 探测不使用 `ALL_PROXY` 或 SOCKS。
- 因此没有同时配置 `HTTPS_PROXY` 或 `HTTP_PROXY` 时，Claude 检测会忽略
  `ALL_PROXY`。
- Claude 探测不会把 macOS HTTP 代理显式传给 curl；系统、VPN 或 TUN 路由
  仍可能承载这部分流量，因此不会再把它笼统标记为“直连”。
- 检测到不兼容或可能与客户端实际链路不同的代理时，`ipcheck` 会明确警告。

详见 Anthropic 的
[企业代理文档](https://docs.anthropic.com/en/docs/claude-code/corporate-proxy)。

## 阿里云百炼 / DashScope 示例

假设 Claude Code 使用下面的配置：

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "YOUR_API_KEY",
    "ANTHROPIC_BASE_URL": "https://dashscope.aliyuncs.com/apps/anthropic",
    "ANTHROPIC_MODEL": "deepseek-v4-flash"
  }
}
```

`ipcheck claude` 会向
`https://dashscope.aliyuncs.com/apps/anthropic/v1/messages` 发送空的、未认证的
协议检测请求，并且不会读取 `ANTHROPIC_AUTH_TOKEN`。

## Cloudflare 参考传输

服务表测量的是首字节延迟和抖动，并不是传输测速。独立的参考传输模块会：

- 从 Cloudflare 下载一个最多 2 MB 的限量样本；
- 上传一个最多 1 MB 的全零限量样本；
- 使用报告中显示的代理/网络路径；
- 将未完成传输明确标记为估算；
- 样本较高时不增加开发适配分。

`https://speed.cloudflare.com/__down` 是
[Cloudflare 官方测速引擎](https://github.com/cloudflare/speedtest)使用的下载
API。官方引擎会组合多个尺寸并重复传输；ipcheck 的单个限量样本并未复刻这套
完整测速方法。

这个样本只回答一个范围有限的问题：当前时刻，通过当前代理/网络路径向
Cloudflare 传输小文件时表现如何。它不是：

- 运营商或峰值宽带测速；
- OpenAI、Anthropic、GitHub 或 npm 的吞吐测量；
- AI 服务专用可达性和 TTFB 探测的替代品。

完整的偏低样本每个方向扣 2 分；较高或一般的样本不加分，不可用或跳过不影响
分数，未完成样本每个方向扣 1 分。这样可以让参考信号始终从属于真实 AI
服务路径。

使用 `--no-upload` 只跳过上传，使用 `--no-bandwidth` 跳过上下行。可选的
`--system` 会运行 macOS `networkQuality`，消耗的数据量可能明显高于 ipcheck
的限量检测。

## 端点安全

自定义端点必须使用 HTTP 或 HTTPS，并且不能包含 URL 凭据、查询参数或片段。
每次 curl 调用都以 `-q` 开始，因此用户 `.curlrc` 无法注入凭据、请求头、
Cookie 或替换检测路径。
