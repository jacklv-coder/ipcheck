# 报告、自动化与退出码

[中文 README](../README.zh-CN.md) · [English](reporting.md)

## 终端输出

普通终端输出会跟随终端或系统语言。目前支持英文和简体中文，其他语言会回退
到英文。可以使用 `--lang en`、`--lang zh` 或 `IPCHECK_LANG=en|zh` 覆盖。

交互进度写入 stderr，可以通过 `IPCHECK_PROGRESS=auto|always|never`、
`--progress` 或 `--no-progress` 控制。按下 `Ctrl+C` 后会清除动态行、删除临时
文件、显示本地化取消提示，并返回状态码 130。

使用 `--no-color` 或 `NO_COLOR=1` 可以获得无颜色输出。

## Markdown 报告

```bash
ipcheck --markdown > ipcheck-report.md
```

Markdown 适合支持工单和 Issue 描述。需要完整评分计算时可以增加
`--explain-score`。

## JSON 报告

```bash
ipcheck --json > ipcheck-report.json
```

为了稳定自动化，JSON 字段名、枚举值和诊断原因始终使用英文。内容包括：

- `schema_version` 和 ipcheck 版本；
- 总体结论和开发适配结果；
- 每个服务、每个端点的测量数据；
- 评分方法和逐项分数；
- 独立的 AI 交互与工程传输维度；
- 警告及脱敏后的网络路径；
- 限量 Cloudflare 参考传输和可选的 macOS 系统数据；
- 明确的隐私保证。

Schema 3 增加了 `developer_readiness.dimensions`、传输限幅、可信度和各方向
样本数量。JSON 为兼容已有使用方继续保留 `bandwidth` 对象名；其中的 `scope`、
`method`、`sample_strategy`、`represents_api_path` 和
`represents_peak_bandwidth` 字段明确限定其含义是 Cloudflare 参考传输。

增加兼容字段不会修改 `schema_version`，破坏性变更才会升级。JSON 和 Markdown
模式不会输出动态进度。

## 退出码

| 状态码 | 含义 |
| ---: | --- |
| `0` | 至少一个选中的主服务路径可达 |
| `1` | 所有选中的主服务路径均被阻断或不可用 |
| `2` | 参数错误或缺少依赖 |
| `130` | 通过 `Ctrl+C` 取消 |

## 常用覆盖项

| 设置 | 用途 |
| --- | --- |
| `--samples N` | 每个端点的请求次数 |
| `--timeout N` | 单次请求超时秒数 |
| `--endpoint URL` | 检测自定义的无凭据 GET 地址 |
| `IPCHECK_ENDPOINTS` | 使用竖线分隔的自定义端点 |
| `CODEX_NETWORK_ENDPOINTS` | Codex 端点覆盖 |
| `CLAUDE_NETWORK_ENDPOINTS` | Claude 端点覆盖 |
| `IPCHECK_SERVICES` | `auto`、`codex`、`claude` 或 `all` |

运行 `ipcheck --help` 可以查看权威的完整列表。
