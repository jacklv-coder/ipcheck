# 服务路径、代理与带宽

[中文 README](../README.zh-CN.md) · [English](network.md)

## 检测的服务路径

`ipcheck` 会检测客户端实际预期使用的协议路径：

| 客户端 | 检测路径 |
| --- | --- |
| Codex 默认配置 | ChatGPT 和 OpenAI 可达路径 |
| Codex 自定义 provider | 配置的 Base URL，必要时补充 `/v1/responses` |
| Claude Code | `${ANTHROPIC_BASE_URL}/v1/messages` |
| 自定义 | 通过 `--endpoint` 或 `IPCHECK_ENDPOINTS` 提供的无凭据 URL |

`CODEX_NETWORK_ENDPOINTS` 保持兼容；Claude 可使用
`CLAUDE_NETWORK_ENDPOINTS` 覆盖端点。

## 代理行为

`HTTPS_PROXY`、`HTTP_PROXY`、`ALL_PROXY` 及其小写形式会被显示，其中凭据
会被脱敏。

- 没有 HTTPS 代理环境变量时，Codex 和自定义检测可以使用 macOS 系统
  HTTPS 代理。
- Claude Code 官方声明支持 `HTTPS_PROXY`、`HTTP_PROXY` 和 `NO_PROXY`，
  但没有声明支持 `ALL_PROXY` 或 SOCKS。
- 因此没有同时配置 `HTTPS_PROXY` 或 `HTTP_PROXY` 时，Claude 检测会忽略
  `ALL_PROXY`。
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

## 参考带宽

服务表测量的是首字节延迟和抖动，并不是传输测速。独立的带宽模块会：

- 从 Cloudflare 下载最多 2 MB；
- 上传最多 1 MB 全零数据；
- 使用报告中显示的代理/网络路径；
- 将未完成传输明确标记为估算；
- 不允许高带宽掩盖异常的服务路径。

使用 `--no-upload` 只跳过上传，使用 `--no-bandwidth` 跳过上下行。可选的
`--system` 会运行 macOS `networkQuality`，消耗的数据量可能明显高于 ipcheck
的限量检测。

## 端点安全

自定义端点必须使用 HTTP 或 HTTPS，并且不能包含 URL 凭据、查询参数或片段。
每次 curl 调用都以 `-q` 开始，因此用户 `.curlrc` 无法注入凭据、请求头、
Cookie 或替换检测路径。
