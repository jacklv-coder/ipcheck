#!/usr/bin/env bash

set -eu

# Keep report-language assertions deterministic regardless of the host locale.
IPCHECK_LANG=en
export IPCHECK_LANG

PROJECT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
STUB_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ipcheck-test.XXXXXX")
FIXTURE_HOME="$STUB_DIR/home"
CODEX_FIXTURE="$FIXTURE_HOME/.codex"
CLAUDE_FIXTURE="$FIXTURE_HOME/.claude"
CURL_LOG="$STUB_DIR/curl.log"
trap 'rm -rf "$STUB_DIR"' EXIT INT TERM

mkdir -p "$CODEX_FIXTURE" "$CLAUDE_FIXTURE"

cat > "$STUB_DIR/curl" <<'EOF'
#!/usr/bin/env bash
[ -z "${IPCHECK_TEST_CURL_SLEEP:-}" ] || exec sleep "$IPCHECK_TEST_CURL_SLEEP"
is_bandwidth=0
is_upload=0
is_blocked=0
is_flaky=0
is_proxy_auth=0
is_not_found=0
is_rate_limited=0
is_server_error=0
is_mixed_status=0
is_anthropic=0
is_score_scenario=0
[ "${1-}" = "-q" ] || {
  printf 'curl was not invoked with -q first\n' >&2
  exit 64
}
printf 'env:HTTPS_PROXY=%s\n' "${HTTPS_PROXY-}" >> "${IPCHECK_TEST_CURL_LOG:?}"
printf 'env:http_proxy=%s\n' "${http_proxy-}" >> "${IPCHECK_TEST_CURL_LOG:?}"
printf 'env:ALL_PROXY=%s\n' "${ALL_PROXY-}" >> "${IPCHECK_TEST_CURL_LOG:?}"
for argument in "$@"; do
  printf '%s\n' "$argument" >> "${IPCHECK_TEST_CURL_LOG:?}"
  case "$argument" in
    *__up*) is_upload=1 ;;
    *speed.cloudflare.com*) is_bandwidth=1 ;;
    *blocked.invalid*) is_blocked=1 ;;
    *flaky.invalid*) is_flaky=1 ;;
    *proxy-auth.invalid*) is_proxy_auth=1 ;;
    *not-found.invalid*) is_not_found=1 ;;
    *rate-limit.invalid*) is_rate_limited=1 ;;
    *server-error.invalid*) is_server_error=1 ;;
    *mixed-status.invalid*) is_mixed_status=1 ;;
    *score-scenario.invalid*) is_score_scenario=1 ;;
    *anthropic*|*dashscope*|*/v1/messages*) is_anthropic=1 ;;
  esac
done
if [ "$is_flaky" -eq 1 ]; then
  attempt_file="${IPCHECK_TEST_ATTEMPT_FILE:?}"
  attempt=$(($(sed -n '1p' "$attempt_file" 2>/dev/null || printf 0) + 1))
  printf '%s' "$attempt" > "$attempt_file"
  if [ "$attempt" -gt 1 ]; then
    exit 28
  fi
  printf '401\t0.001\t0.002\t0.003\t0.100\t0.100\t151\t1000'
elif [ "$is_proxy_auth" -eq 1 ]; then
  printf '407\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
elif [ "$is_blocked" -eq 1 ]; then
  exit 28
elif [ "$is_upload" -eq 1 ]; then
  upload_code=${IPCHECK_TEST_UPLOAD_CODE:-200}
  upload_speed=${IPCHECK_TEST_UPLOAD_SPEED:-2000000}
  upload_bytes=${IPCHECK_TEST_UPLOAD_BYTES:-1000000}
  printf '%s\t%s\t%s' "$upload_code" "$upload_bytes" "$upload_speed"
  upload_exit=${IPCHECK_TEST_UPLOAD_EXIT:-0}
  [ "$upload_exit" -eq 0 ] || exit "$upload_exit"
elif [ "$is_bandwidth" -eq 1 ]; then
  bandwidth_code=${IPCHECK_TEST_BANDWIDTH_CODE:-200}
  bandwidth_speed=${IPCHECK_TEST_BANDWIDTH_SPEED:-10000000}
  bandwidth_bytes=${IPCHECK_TEST_BANDWIDTH_BYTES:-2000000}
  printf '%s\t%s\t%s' "$bandwidth_code" "$bandwidth_bytes" "$bandwidth_speed"
  bandwidth_exit=${IPCHECK_TEST_BANDWIDTH_EXIT:-0}
  [ "$bandwidth_exit" -eq 0 ] || exit "$bandwidth_exit"
elif [ "$is_not_found" -eq 1 ]; then
  printf '404\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
elif [ "$is_rate_limited" -eq 1 ]; then
  printf '429\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
elif [ "$is_server_error" -eq 1 ]; then
  printf '503\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
elif [ "$is_mixed_status" -eq 1 ]; then
  attempt_file="${IPCHECK_TEST_MIXED_FILE:?}"
  attempt=$(($(sed -n '1p' "$attempt_file" 2>/dev/null || printf 0) + 1))
  printf '%s' "$attempt" > "$attempt_file"
  if [ "$attempt" -eq 1 ]; then
    printf '401\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
  else
    printf '503\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
  fi
elif [ "$is_score_scenario" -eq 1 ]; then
  attempt_file="${IPCHECK_TEST_SCORE_FILE:?}"
  attempt=$(($(sed -n '1p' "$attempt_file" 2>/dev/null || printf 0) + 1))
  printf '%s' "$attempt" > "$attempt_file"
  case "$attempt" in
    1) first_byte=8.108 ;;
    2) first_byte=4.881 ;;
    *) first_byte=2.250 ;;
  esac
  printf '401\t0.001\t0.002\t0.003\t%s\t%s\t151\t1000' "$first_byte" "$first_byte"
elif [ "$is_anthropic" -eq 1 ]; then
  [ "${IPCHECK_TEST_ANTHROPIC_BLOCKED:-0}" -eq 0 ] || exit 28
  first_byte=${IPCHECK_TEST_ANTHROPIC_TTFB:-${IPCHECK_TEST_TTFB:-0.100}}
  anthropic_code=${IPCHECK_TEST_ANTHROPIC_CODE:-403}
  printf '%s\t0.001\t0.002\t0.003\t%s\t%s\t151\t1000' "$anthropic_code" "$first_byte" "$first_byte"
else
  first_byte=${IPCHECK_TEST_TTFB:-0.100}
  printf '401\t0.001\t0.002\t0.003\t%s\t%s\t151\t1000' "$first_byte" "$first_byte"
fi
EOF
chmod +x "$STUB_DIR/curl"

MINIMAL_BIN="$STUB_DIR/minimal-bin"
mkdir -p "$MINIMAL_BIN"
for utility in bash awk sed sort mktemp rm tr date head env; do
  ln -s "$(command -v "$utility")" "$MINIMAL_BIN/$utility"
done
ln -s "$STUB_DIR/curl" "$MINIMAL_BIN/curl"

MAC_LANG_BIN="$STUB_DIR/mac-lang-bin"
mkdir -p "$MAC_LANG_BIN"
cat > "$MAC_LANG_BIN/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
cat > "$MAC_LANG_BIN/defaults" <<'EOF'
#!/usr/bin/env bash
printf '(\n    "%s"\n)\n' "${IPCHECK_TEST_APPLE_LANG:-en}"
EOF
chmod +x "$MAC_LANG_BIN/uname" "$MAC_LANG_BIN/defaults"

cat > "$STUB_DIR/networkQuality" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{
  "base_rtt" : 25,
  "dl_throughput" : 10000000,
  "ul_throughput" : 5000000,
  "interface_name" : "en0",
  "proxy_state" : "Non-Proxied"
}
JSON
EOF
chmod +x "$STUB_DIR/networkQuality"

cat > "$STUB_DIR/scutil" <<'EOF'
#!/usr/bin/env bash
cat <<'PROXY'
<dictionary> {
  HTTPSEnable : 1
  HTTPSProxy : 127.0.0.1
  HTTPSPort : 1082
}
PROXY
EOF
chmod +x "$STUB_DIR/scutil"

cat > "$CODEX_FIXTURE/config.toml" <<'EOF'
model = "gpt-test"
EOF

cat > "$CLAUDE_FIXTURE/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "fixture-secret-must-never-appear",
    "ANTHROPIC_BASE_URL": "https://dashscope.aliyuncs.com/apps/anthropic",
    "ANTHROPIC_MODEL": "deepseek-v4-flash"
  }
}
EOF

run_ipcheck() {
  env \
    -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL \
    -u IPCHECK_SERVICES -u IPCHECK_ENDPOINTS \
    -u CODEX_NETWORK_ENDPOINTS -u CLAUDE_NETWORK_ENDPOINTS \
    -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
    PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
    HTTPS_PROXY="http://127.0.0.1:1080" IPCHECK_LANG="${IPCHECK_LANG:-en}" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
    "$PROJECT_DIR/bin/ipcheck" "$@"
}

run_ipcheck_direct() {
  env \
    -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL \
    -u IPCHECK_SERVICES -u IPCHECK_ENDPOINTS \
    -u CODEX_NETWORK_ENDPOINTS -u CLAUDE_NETWORK_ENDPOINTS \
    -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
    PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
    IPCHECK_LANG="${IPCHECK_LANG:-en}" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
    "$PROJECT_DIR/bin/ipcheck" "$@"
}

bash -n "$PROJECT_DIR/bin/ipcheck"
"$PROJECT_DIR/bin/ipcheck" --help | grep -q '^ipcheck - diagnose Codex and Claude Code'
[ "$("$PROJECT_DIR/bin/ipcheck" --version)" = "ipcheck 0.7.0" ]
"$PROJECT_DIR/bin/ipcheck" --help | grep -q -- '--explain-score'

: > "$CURL_LOG"
report=$(ANTHROPIC_AUTH_TOKEN="runtime-secret-must-never-appear" run_ipcheck --samples 3 --no-bandwidth --json)
printf '%s\n' "$report" | grep -q '"schema_version":1'
printf '%s\n' "$report" | grep -q '"result":"good"'
printf '%s\n' "$report" | grep -q '"reachable_endpoints":3'
printf '%s\n' "$report" | grep -q '"id":"codex"'
printf '%s\n' "$report" | grep -q '"model":"gpt-test"'
printf '%s\n' "$report" | grep -q '"id":"claude"'
printf '%s\n' "$report" | grep -q '"model":"deepseek-v4-flash"'
printf '%s\n' "$report" | grep -q 'https://dashscope.aliyuncs.com/apps/anthropic'
printf '%s\n' "$report" | grep -q 'https://dashscope.aliyuncs.com/apps/anthropic/v1/messages'
printf '%s\n' "$report" | grep -q '"credentials_used":false'
printf '%s\n' "$report" | grep -q '"billable_requests":false'
printf '%s\n' "$report" | grep -q '"developer_readiness":{"ready":true,"level":"ready"'
printf '%s\n' "$report" | grep -q '"score":90,"score_label":"COMFORTABLE","score_method":"rule_v2"'
printf '%s\n' "$report" | grep -q '"score_breakdown":{"scored_service":"codex","service_path":90,"availability":35,"median_ttfb":35,"p95":10,"jitter":10'
if printf '%s\n' "$report" | grep -Eq 'fixture-secret|runtime-secret'; then
  printf 'Claude credential leaked into JSON report\n' >&2
  exit 1
fi
grep -q '^anthropic-version: 2023-06-01$' "$CURL_LOG"
grep -q '^{}$' "$CURL_LOG"
if grep -Eqi 'authorization|x-api-key|fixture-secret|runtime-secret' "$CURL_LOG"; then
  printf 'Claude credential was passed to curl\n' >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  REPORT_JSON="$report" python3 -c 'import json, os; json.loads(os.environ["REPORT_JSON"])'
fi

mixed_client_quality=$(IPCHECK_TEST_ANTHROPIC_TTFB=4.000 run_ipcheck --samples 1 --no-bandwidth --json)
printf '%s\n' "$mixed_client_quality" | grep -q '"result":"poor"'
printf '%s\n' "$mixed_client_quality" | grep -q '"score":63,"score_label":"LIMITED","score_method":"rule_v2"'
printf '%s\n' "$mixed_client_quality" | grep -q '"scored_service":"claude","service_path":63'

for anthropic_status in 429 503; do
  mixed_service_error=$(IPCHECK_TEST_ANTHROPIC_CODE="$anthropic_status" run_ipcheck --samples 1 --no-bandwidth --json)
  printf '%s\n' "$mixed_service_error" | grep -q '"result":"fair"'
  printf '%s\n' "$mixed_service_error" | grep -q '"score":64,"score_label":"LIMITED","score_method":"rule_v2"'
  printf '%s\n' "$mixed_service_error" | grep -q '"scored_service":"claude","service_path":90'
  printf '%s\n' "$mixed_service_error" | grep -q '"pre_cap_total":90,"verdict_cap":64'
done

for anthropic_status in 429 503; do
  mixed_fair_unavailable=$(IPCHECK_TEST_TTFB=1.000 IPCHECK_TEST_ANTHROPIC_CODE="$anthropic_status" run_ipcheck --samples 1 --no-bandwidth --json)
  printf '%s\n' "$mixed_fair_unavailable" | grep -q '"result":"fair"'
  printf '%s\n' "$mixed_fair_unavailable" | grep -q '"score":64,"score_label":"LIMITED","score_method":"rule_v2"'
  printf '%s\n' "$mixed_fair_unavailable" | grep -q '"scored_service":"claude","service_path":85'
  printf '%s\n' "$mixed_fair_unavailable" | grep -q '"pre_cap_total":85,"verdict_cap":64'
done

mixed_blocked=$(IPCHECK_TEST_ANTHROPIC_BLOCKED=1 run_ipcheck --samples 1 --json)
printf '%s\n' "$mixed_blocked" | grep -q '"result":"poor"'
printf '%s\n' "$mixed_blocked" | grep -q '"score":0,"score_label":"LIMITED","score_method":"rule_v2"'
printf '%s\n' "$mixed_blocked" | grep -q '"scored_service":"claude","service_path":0'
printf '%s\n' "$mixed_blocked" | grep -q '"pre_cap_total":10,"verdict_cap":0'

AUTO_HOME="$STUB_DIR/auto-home"
mkdir -p "$AUTO_HOME/codex" "$AUTO_HOME/claude"
: > "$CURL_LOG"
auto_codex_override=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u IPCHECK_SERVICES -u IPCHECK_ENDPOINTS \
  -u CLAUDE_NETWORK_ENDPOINTS -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
  PATH="$MINIMAL_BIN" HOME="$AUTO_HOME" CODEX_HOME="$AUTO_HOME/codex" CLAUDE_CONFIG_DIR="$AUTO_HOME/claude" \
  CODEX_NETWORK_ENDPOINTS="https://codex-override.invalid" HTTPS_PROXY="http://127.0.0.1:1080" \
  IPCHECK_TEST_CURL_LOG="$CURL_LOG" "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --json)
printf '%s\n' "$auto_codex_override" | grep -q '"id":"codex"'
if printf '%s\n' "$auto_codex_override" | grep -q '"id":"claude"'; then
  printf 'Codex endpoint override did not participate in auto-detection\n' >&2
  exit 1
fi

: > "$CURL_LOG"
auto_claude_override=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u IPCHECK_SERVICES -u IPCHECK_ENDPOINTS \
  -u CODEX_NETWORK_ENDPOINTS -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
  PATH="$MINIMAL_BIN" HOME="$AUTO_HOME" CODEX_HOME="$AUTO_HOME/codex" CLAUDE_CONFIG_DIR="$AUTO_HOME/claude" \
  CLAUDE_NETWORK_ENDPOINTS="https://claude-override.invalid/v1/messages" HTTPS_PROXY="http://127.0.0.1:1080" \
  IPCHECK_TEST_CURL_LOG="$CURL_LOG" "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --json)
printf '%s\n' "$auto_claude_override" | grep -q '"id":"claude"'
if printf '%s\n' "$auto_claude_override" | grep -q '"id":"codex"'; then
  printf 'Claude endpoint override did not participate in auto-detection\n' >&2
  exit 1
fi

claude_report=$(run_ipcheck claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$claude_report" | grep -q '"id":"claude"'
if printf '%s\n' "$claude_report" | grep -q '"id":"codex"'; then
  printf 'Claude-only mode included Codex\n' >&2
  exit 1
fi

env_precedence_report=$(ANTHROPIC_BASE_URL="https://gateway.example.com/anthropic" ANTHROPIC_MODEL="gateway-model" \
  env -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
  PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
  HTTPS_PROXY="http://127.0.0.1:1080" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
  "$PROJECT_DIR/bin/ipcheck" claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$env_precedence_report" | grep -q '"model":"gateway-model"'
printf '%s\n' "$env_precedence_report" | grep -q 'https://gateway.example.com/anthropic/v1/messages'

cat > "$CODEX_FIXTURE/config.toml" <<'EOF'
model = 'proxy-model'
model_provider = "company"

[model_providers.company]
base_url = 'https://codex-gateway.example.com/v1'
env_key = "SECRET_THAT_IPCHECK_MUST_NOT_READ"
EOF
codex_provider_report=$(run_ipcheck codex --samples 1 --no-bandwidth --json)
printf '%s\n' "$codex_provider_report" | grep -q '"model":"proxy-model"'
printf '%s\n' "$codex_provider_report" | grep -q 'https://codex-gateway.example.com/v1/responses'
printf '%s\n' "$codex_provider_report" | grep -q 'config.toml provider company'

decimal_report=$(run_ipcheck --samples 08 --timeout 08 --no-bandwidth --endpoint https://decimal.invalid --json)
printf '%s\n' "$decimal_report" | grep -q '"samples":8'
printf '%s\n' "$decimal_report" | grep -q '"successful_samples":8'

fair_report=$(IPCHECK_TEST_TTFB=1.000 run_ipcheck --samples 1 --no-bandwidth --endpoint https://fair.invalid --json)
printf '%s\n' "$fair_report" | grep -q '"result":"fair"'
printf '%s\n' "$fair_report" | grep -q '"level":"with_caution"'
printf '%s\n' "$fair_report" | grep -q '"score":85,"score_label":"GOOD"'
fair_fast_bandwidth_report=$(IPCHECK_TEST_TTFB=1.000 run_ipcheck --samples 1 --endpoint https://fair.invalid --json)
printf '%s\n' "$fair_fast_bandwidth_report" | grep -q '"score":89,"score_label":"GOOD"'
fair_slow_bandwidth_report=$(IPCHECK_TEST_TTFB=1.000 IPCHECK_TEST_BANDWIDTH_SPEED=100000 IPCHECK_TEST_UPLOAD_SPEED=100000 run_ipcheck --samples 1 --endpoint https://fair.invalid --json)
printf '%s\n' "$fair_slow_bandwidth_report" | grep -q '"score":75,"score_label":"GOOD"'

just_below_poor=$(IPCHECK_TEST_TTFB=2.999 run_ipcheck --samples 1 --no-bandwidth --endpoint https://boundary.invalid --json)
printf '%s\n' "$just_below_poor" | grep -q '"score":74,"score_label":"USABLE"'
at_poor_boundary=$(IPCHECK_TEST_TTFB=3.000 run_ipcheck --samples 1 --no-bandwidth --endpoint https://boundary.invalid --json)
printf '%s\n' "$at_poor_boundary" | grep -q '"score":64,"score_label":"LIMITED"'

SCORE_SCENARIO_FILE="$STUB_DIR/score-scenario-attempt"
: > "$SCORE_SCENARIO_FILE"
score_scenario=$(IPCHECK_TEST_SCORE_FILE="$SCORE_SCENARIO_FILE" IPCHECK_TEST_BANDWIDTH_SPEED=400000 IPCHECK_TEST_UPLOAD_SPEED=425000 run_ipcheck --samples 3 --endpoint https://score-scenario.invalid --json)
printf '%s\n' "$score_scenario" | grep -q '"result":"poor"'
printf '%s\n' "$score_scenario" | grep -q '"score":47,"score_label":"LIMITED","score_method":"rule_v2"'
printf '%s\n' "$score_scenario" | grep -q '"service_path":49,"availability":35,"median_ttfb":14,"p95":0,"jitter":0,"download":-5'

fair_human=$(IPCHECK_TEST_TTFB=1.000 IPCHECK_LANG=en run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://fair.invalid)
printf '%s\n' "$fair_human" | grep -q 'Ready to code? YES, WITH CAUTION'

chinese_human=$(IPCHECK_LANG=zh run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://language.invalid)
printf '%s\n' "$chinese_human" | grep -q '现在适合开发吗？适合'
printf '%s\n' "$chinese_human" | grep -q '当前网络适合进行 AI 辅助开发'
printf '%s\n' "$chinese_human" | grep -q '^AI 服务延迟$'
printf '%s\n' "$chinese_human" | grep -q '首字节延迟（TTFB）'

english_override=$(LANG=zh_CN.UTF-8 IPCHECK_LANG=en run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://language.invalid)
printf '%s\n' "$english_override" | grep -q 'Ready to code? YES'

unsupported_language=$(PATH="$MINIMAL_BIN" LC_ALL='' LC_MESSAGES='' LANG=ja_JP.UTF-8 IPCHECK_LANG=auto run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://language.invalid)
printf '%s\n' "$unsupported_language" | grep -q 'Ready to code? YES'
if printf '%s\n' "$unsupported_language" | grep -q '现在适合开发吗'; then
  printf 'unsupported system language did not fall back to English\n' >&2
  exit 1
fi

mac_unsupported_language=$(PATH="$MAC_LANG_BIN:$MINIMAL_BIN" LC_ALL=C IPCHECK_LANG=auto IPCHECK_TEST_APPLE_LANG=ja-JP run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://language.invalid)
printf '%s\n' "$mac_unsupported_language" | grep -q 'Ready to code? YES'
mac_chinese_language=$(PATH="$MAC_LANG_BIN:$MINIMAL_BIN" LC_ALL=C IPCHECK_LANG=auto IPCHECK_TEST_APPLE_LANG=zh-Hans run_ipcheck --samples 1 --no-bandwidth --no-progress --endpoint https://language.invalid)
printf '%s\n' "$mac_chinese_language" | grep -q '现在适合开发吗？适合'

progress_log="$STUB_DIR/progress.log"
IPCHECK_PROGRESS=always IPCHECK_LANG=en run_ipcheck --samples 2 --no-bandwidth --endpoint https://progress.invalid >/dev/null 2>"$progress_log"
grep -q 'sample 1/2' "$progress_log"
grep -q 'sample 2/2' "$progress_log"
grep -q 'reachable 2/2' "$progress_log"

json_progress_log="$STUB_DIR/json-progress.log"
IPCHECK_PROGRESS=always run_ipcheck --samples 1 --no-bandwidth --json > /dev/null 2>"$json_progress_log"
[ ! -s "$json_progress_log" ]

colored_human=$(IPCHECK_LANG=en run_ipcheck --samples 1 --no-bandwidth --color --endpoint https://color.invalid)
case "$colored_human" in
  *"$(printf '\033[32m')"*) ;;
  *) printf 'forced color output did not contain ANSI color codes\n' >&2; exit 1 ;;
esac

attempt_file="$STUB_DIR/attempt"
printf 0 > "$attempt_file"
flaky_report=$(IPCHECK_TEST_ATTEMPT_FILE="$attempt_file" run_ipcheck --samples 5 --no-bandwidth --endpoint https://flaky.invalid --json)
printf '%s\n' "$flaky_report" | grep -q '"result":"poor"'
printf '%s\n' "$flaky_report" | grep -q '"primary_success_rate_pct":20'
printf '%s\n' "$flaky_report" | grep -q '"successful_samples":1'

not_found_report=$(run_ipcheck --samples 1 --no-bandwidth --endpoint https://not-found.invalid/v1/messages --json)
printf '%s\n' "$not_found_report" | grep -q '"result":"poor"'
printf '%s\n' "$not_found_report" | grep -q '"score":64,"score_label":"LIMITED"'
printf '%s\n' "$not_found_report" | grep -q 'configured API route returned HTTP 404'

rate_limit_report=$(run_ipcheck --samples 1 --no-bandwidth --endpoint https://rate-limit.invalid --json)
printf '%s\n' "$rate_limit_report" | grep -q '"result":"fair"'
printf '%s\n' "$rate_limit_report" | grep -q '"ready":false,"level":"temporarily_unavailable"'
server_error_report=$(run_ipcheck --samples 1 --no-bandwidth --endpoint https://server-error.invalid --json)
printf '%s\n' "$server_error_report" | grep -q '"result":"fair"'
printf '%s\n' "$server_error_report" | grep -q '"ready":false,"level":"temporarily_unavailable"'
printf '%s\n' "$server_error_report" | grep -q '"score":64,"score_label":"LIMITED"'

server_error_progress="$STUB_DIR/server-error-progress.log"
IPCHECK_PROGRESS=always run_ipcheck --samples 1 --no-bandwidth --endpoint https://server-error.invalid >/dev/null 2>"$server_error_progress"
grep -q '! Custom · Custom endpoint 1 — HTTP 503, reachable 1/1' "$server_error_progress"
if grep -q '✓ Custom · Custom endpoint 1' "$server_error_progress"; then
  printf 'server error was incorrectly shown as successful progress\n' >&2
  exit 1
fi

mixed_status_file="$STUB_DIR/mixed-status-attempt"
printf 0 > "$mixed_status_file"
mixed_status_report=$(IPCHECK_TEST_MIXED_FILE="$mixed_status_file" run_ipcheck --samples 2 --no-bandwidth --endpoint https://mixed-status.invalid --json)
printf '%s\n' "$mixed_status_report" | grep -q '"result":"fair"'
printf '%s\n' "$mixed_status_report" | grep -q 'at least one sample returned a server error'
printf '%s\n' "$mixed_status_report" | grep -q '"ready":true,"level":"with_caution"'

precedence_report=$(CODEX_NETWORK_ENDPOINTS="https://blocked.invalid" run_ipcheck --samples 1 --no-bandwidth --endpoint https://cli.invalid --json)
printf '%s\n' "$precedence_report" | grep -q '"url":"https://cli.invalid"'
if printf '%s\n' "$precedence_report" | grep -q 'blocked.invalid'; then
  printf 'CLI endpoint did not override CODEX_NETWORK_ENDPOINTS\n' >&2
  exit 1
fi

set +e
proxy_auth_report=$(run_ipcheck --samples 2 --no-bandwidth --endpoint https://proxy-auth.invalid --json)
proxy_auth_exit=$?
set -e
[ "$proxy_auth_exit" -eq 1 ]
printf '%s\n' "$proxy_auth_report" | grep -q '"result":"blocked"'
printf '%s\n' "$proxy_auth_report" | grep -q '"http_code":"407"'
printf '%s\n' "$proxy_auth_report" | grep -q 'proxy requires authentication'

mixed_report=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
  CODEX_NETWORK_ENDPOINTS="https://blocked.invalid" \
  CLAUDE_NETWORK_ENDPOINTS="https://dashscope.aliyuncs.com/apps/anthropic/v1/messages" \
  PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
  HTTPS_PROXY="http://127.0.0.1:1080" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
  "$PROJECT_DIR/bin/ipcheck" all --samples 1 --no-bandwidth --json)
printf '%s\n' "$mixed_report" | grep -q '"result":"poor"'
printf '%s\n' "$mixed_report" | grep -q '1 good, 0 fair, 0 poor, 1 blocked'

for unsafe_endpoint in \
  'file:///etc/passwd' \
  '--config=/tmp/curlrc' \
  'https://alice:topsecret@secure.invalid/path' \
  'https://secure.invalid/path?token=verysecret' \
  'https://secure.invalid/path#private'
do
  set +e
  run_ipcheck --samples 1 --no-bandwidth --endpoint "$unsafe_endpoint" --json >/dev/null 2>&1
  unsafe_exit=$?
  set -e
  [ "$unsafe_exit" -eq 2 ]
done

proxy_redaction_report=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u HTTP_PROXY -u http_proxy -u ALL_PROXY -u all_proxy \
  PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
  HTTPS_PROXY="http://proxy-user:p@ss@127.0.0.1:1080?token=proxy-secret" \
  IPCHECK_TEST_CURL_LOG="$CURL_LOG" "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --endpoint https://proxy-redaction.invalid --json)
printf '%s\n' "$proxy_redaction_report" | grep -Fq 'HTTPS_PROXY=http://***@127.0.0.1:1080?<redacted>'
if printf '%s\n' "$proxy_redaction_report" | grep -Eq 'proxy-user|p@ss|proxy-secret'; then
  printf 'proxy credentials leaked into report\n' >&2
  exit 1
fi

: > "$CURL_LOG"
proxy_fallback_report=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u HTTPS_PROXY -u https_proxy -u ALL_PROXY -u all_proxy \
  HTTP_PROXY="http://ignored.invalid:8080" PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" \
  CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --endpoint https://system-proxy.invalid --json)
printf '%s\n' "$proxy_fallback_report" | grep -q 'macOS HTTPS proxy=127.0.0.1:1082'
grep -q '^--proxy$' "$CURL_LOG"
grep -q '^http://127.0.0.1:1082$' "$CURL_LOG"

: > "$CURL_LOG"
claude_system_proxy_report=$(run_ipcheck_direct claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$claude_system_proxy_report" | grep -q 'Claude Code expects HTTPS_PROXY/HTTP_PROXY'
if grep -q '^--proxy$' "$CURL_LOG"; then
  printf 'Claude probe incorrectly used the macOS system proxy\n' >&2
  exit 1
fi

: > "$CURL_LOG"
claude_http_proxy_report=$(env \
  -u ANTHROPIC_MODEL -u HTTPS_PROXY -u https_proxy -u ALL_PROXY -u all_proxy \
  ANTHROPIC_BASE_URL="http://claude-http-gateway.invalid/anthropic" HTTP_PROXY="http://claude-proxy.invalid:8080" \
  PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" \
  CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
  "$PROJECT_DIR/bin/ipcheck" claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$claude_http_proxy_report" | grep -q '"result":"good"'
grep -q '^env:HTTPS_PROXY=http://claude-proxy.invalid:8080$' "$CURL_LOG"
grep -q '^env:http_proxy=http://claude-proxy.invalid:8080$' "$CURL_LOG"
if grep -q '^--proxy$' "$CURL_LOG"; then
  printf 'Claude HTTP_PROXY credentials could be exposed in process arguments\n' >&2
  exit 1
fi
if printf '%s\n' "$claude_http_proxy_report" | grep -q 'Claude Code expects HTTPS_PROXY/HTTP_PROXY'; then
  printf 'Claude HTTP_PROXY fallback incorrectly emitted system-proxy warning\n' >&2
  exit 1
fi

: > "$CURL_LOG"
claude_https_precedence_report=$(env \
  -u ANTHROPIC_MODEL -u HTTP_PROXY -u http_proxy -u https_proxy \
  ANTHROPIC_BASE_URL="http://claude-http-gateway.invalid/anthropic" \
  HTTPS_PROXY="http://supported-proxy.invalid:8080" ALL_PROXY="http://unsupported-proxy.invalid:8081" \
  PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" \
  IPCHECK_TEST_CURL_LOG="$CURL_LOG" "$PROJECT_DIR/bin/ipcheck" claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$claude_https_precedence_report" | grep -q '"result":"good"'
grep -q '^env:HTTPS_PROXY=http://supported-proxy.invalid:8080$' "$CURL_LOG"
grep -q '^env:ALL_PROXY=$' "$CURL_LOG"

: > "$CURL_LOG"
socks_report=$(env \
  -u ANTHROPIC_BASE_URL -u ANTHROPIC_MODEL -u HTTPS_PROXY -u https_proxy -u HTTP_PROXY -u http_proxy \
  ALL_PROXY="socks5h://127.0.0.1:1080" PATH="$STUB_DIR:$PATH" HOME="$FIXTURE_HOME" \
  CODEX_HOME="$CODEX_FIXTURE" CLAUDE_CONFIG_DIR="$CLAUDE_FIXTURE" IPCHECK_TEST_CURL_LOG="$CURL_LOG" \
  "$PROJECT_DIR/bin/ipcheck" claude --samples 1 --no-bandwidth --json)
printf '%s\n' "$socks_report" | grep -q 'Claude Code does not support SOCKS proxies'
printf '%s\n' "$socks_report" | grep -q 'Claude Code does not document ALL_PROXY'
grep -q '^env:ALL_PROXY=$' "$CURL_LOG"

bandwidth_report=$(run_ipcheck --samples 1 --json)
printf '%s\n' "$bandwidth_report" | grep -q '"score":100,"score_label":"COMFORTABLE","score_method":"rule_v2"'
printf '%s\n' "$bandwidth_report" | grep -q '"score_breakdown":{"scored_service":"codex","service_path":90,"availability":35,"median_ttfb":35,"p95":10,"jitter":10,"download":5,"download_speed":5,"download_partial_penalty":0,"upload":5'
printf '%s\n' "$bandwidth_report" | grep -q '"bandwidth":{"enabled":true,"available":true,"http_code":"200"'
printf '%s\n' "$bandwidth_report" | grep -q '"download":{"enabled":true,"available":true,"complete":true,"http_code":"200","bytes":2000000,"bytes_per_second":10000000,"mbps":80.0,"rating":"fast"}'
printf '%s\n' "$bandwidth_report" | grep -q '"upload":{"enabled":true,"available":true,"complete":true,"http_code":"200","bytes":1000000,"bytes_per_second":2000000,"mbps":16.0,"rating":"fast"}'
printf '%s\n' "$bandwidth_report" | grep -q '"upload_payload":"zero-filled"'
bandwidth_human=$(IPCHECK_LANG=zh run_ipcheck --samples 1)
printf '%s\n' "$bandwidth_human" | grep -q '^网络带宽$'
printf '%s\n' "$bandwidth_human" | grep -q '开发适配分：100/100 · 舒适'
printf '%s\n' "$bandwidth_human" | grep -q '下载  80.0 Mbps.*快.*Cloudflare，最多 2 MB'
printf '%s\n' "$bandwidth_human" | grep -q '上传  16.0 Mbps.*快.*Cloudflare，最多 1 MB 零字节'
printf '%s\n' "$bandwidth_human" | grep -q '路径  HTTPS_PROXY=http://127.0.0.1:1080'
score_explanation=$(IPCHECK_LANG=en run_ipcheck --samples 1 --explain-score)
printf '%s\n' "$score_explanation" | grep -q 'Score breakdown: service path 90/90 (reachability 35 + TTFB 35 + P95 10 + jitter 10); download 5 (FAST); upload 5 (FAST); total 100.'
score_explanation_zh=$(IPCHECK_LANG=zh run_ipcheck --samples 1 --markdown --explain-score)
printf '%s\n' "$score_explanation_zh" | grep -q '评分依据：服务链路 90/90（可达性 35 + TTFB 35 + P95 10 + 抖动 10）；下载 5（快）；上传 5（快）；限幅前 100；结论上限 100；总分 100。'
score_explanation_without_bandwidth=$(IPCHECK_LANG=en run_ipcheck --samples 1 --no-bandwidth --explain-score)
printf '%s\n' "$score_explanation_without_bandwidth" | grep -q 'Score breakdown: service path 90/90 (reachability 35 + TTFB 35 + P95 10 + jitter 10); download 0 (UNAVAILABLE); upload 0 (UNAVAILABLE); total 90.'

slow_upload_human=$(IPCHECK_TEST_UPLOAD_SPEED=100000 IPCHECK_LANG=en run_ipcheck --samples 1 --explain-score)
printf '%s\n' "$slow_upload_human" | grep -q 'Upload.*0.8 Mbps.*SLOW'
printf '%s\n' "$slow_upload_human" | grep -q 'Readiness score: 90/100 · COMFORTABLE'
printf '%s\n' "$slow_upload_human" | grep -q 'upload -5 (SLOW); total 90.'
printf '%s\n' "$slow_upload_human" | grep -q 'Upload is slow; sending large code contexts may take longer.'
invalid_bandwidth_report=$(IPCHECK_TEST_BANDWIDTH_CODE=407 run_ipcheck --samples 1 --json)
printf '%s\n' "$invalid_bandwidth_report" | grep -q '"bandwidth":{"enabled":true,"available":false,"http_code":"407","bytes":0,"bytes_per_second":0,'
invalid_upload_report=$(IPCHECK_TEST_UPLOAD_CODE=503 run_ipcheck --samples 1 --json)
printf '%s\n' "$invalid_upload_report" | grep -q '"upload":{"enabled":true,"available":false,"complete":false,"http_code":"503","bytes":0,"bytes_per_second":0,"mbps":0.0,"rating":"unavailable"}'

no_upload_report=$(run_ipcheck --samples 1 --no-upload --json)
printf '%s\n' "$no_upload_report" | grep -q '"upload":{"enabled":false,"available":false'

partial_upload_report=$(IPCHECK_TEST_UPLOAD_BYTES=500000 IPCHECK_TEST_UPLOAD_EXIT=28 run_ipcheck --samples 1 --json)
printf '%s\n' "$partial_upload_report" | grep -q '"upload":{"enabled":true,"available":true,"complete":false,"http_code":"200","bytes":500000,"bytes_per_second":2000000,"mbps":16.0,"rating":"partial"}'
printf '%s\n' "$partial_upload_report" | grep -q '"score":98,"score_label":"COMFORTABLE"'

partial_download_report=$(IPCHECK_TEST_BANDWIDTH_BYTES=500000 IPCHECK_TEST_BANDWIDTH_EXIT=28 run_ipcheck --samples 1 --json)
printf '%s\n' "$partial_download_report" | grep -q '"bandwidth":{"enabled":true,"available":false,"http_code":"000","bytes":0,"bytes_per_second":0,'
printf '%s\n' "$partial_download_report" | grep -q '"download":{"enabled":true,"available":true,"complete":false,"http_code":"200","bytes":500000,"bytes_per_second":10000000,"mbps":80.0,"rating":"partial"}'

complete_slow_download=$(IPCHECK_TEST_BANDWIDTH_SPEED=12500 run_ipcheck --samples 1 --json)
printf '%s\n' "$complete_slow_download" | grep -q '"score":90,"score_label":"COMFORTABLE"'
partial_slow_download=$(IPCHECK_TEST_BANDWIDTH_SPEED=12500 IPCHECK_TEST_BANDWIDTH_BYTES=500000 IPCHECK_TEST_BANDWIDTH_EXIT=28 run_ipcheck --samples 1 --json)
printf '%s\n' "$partial_slow_download" | grep -q '"score":88,"score_label":"GOOD"'
printf '%s\n' "$partial_slow_download" | grep -q '"download":-7,"download_speed":-5,"download_partial_penalty":-2'

partial_human=$(IPCHECK_TEST_UPLOAD_BYTES=500000 IPCHECK_TEST_UPLOAD_EXIT=28 IPCHECK_LANG=en run_ipcheck --samples 1)
printf '%s\n' "$partial_human" | grep -q 'Upload.*16.0 Mbps.*ESTIMATE'
printf '%s\n' "$partial_human" | grep -q 'partial estimates and do not prove bandwidth is sufficient'
partial_markdown=$(IPCHECK_TEST_BANDWIDTH_BYTES=500000 IPCHECK_TEST_BANDWIDTH_EXIT=28 IPCHECK_LANG=en run_ipcheck --samples 1 --markdown)
printf '%s\n' "$partial_markdown" | grep -q '| Download | 80.0 Mbps | ESTIMATE |'
printf '%s\n' "$partial_markdown" | grep -q 'partial estimates and do not prove bandwidth is sufficient'

progress_report=$(IPCHECK_LANG=en run_ipcheck --samples 1 --no-bandwidth --progress 2>&1 >/dev/null)
printf '%s\n' "$progress_report" | grep -q 'Press Ctrl+C to cancel at any time.'
if command -v python3 >/dev/null 2>&1; then
  PROJECT_DIR="$PROJECT_DIR" STUB_DIR="$STUB_DIR" FIXTURE_HOME="$FIXTURE_HOME" \
    CODEX_FIXTURE="$CODEX_FIXTURE" CLAUDE_FIXTURE="$CLAUDE_FIXTURE" CURL_LOG="$CURL_LOG" \
    python3 <<'PY'
import os
import glob
import signal
import subprocess
import time

env = os.environ.copy()
for key in (
    "ANTHROPIC_BASE_URL", "ANTHROPIC_MODEL", "IPCHECK_SERVICES", "IPCHECK_ENDPOINTS",
    "CODEX_NETWORK_ENDPOINTS", "CLAUDE_NETWORK_ENDPOINTS", "HTTP_PROXY", "http_proxy",
    "ALL_PROXY", "all_proxy",
):
    env.pop(key, None)
env.update({
    "PATH": os.environ["STUB_DIR"] + os.pathsep + env["PATH"],
    "HOME": os.environ["FIXTURE_HOME"],
    "CODEX_HOME": os.environ["CODEX_FIXTURE"],
    "CLAUDE_CONFIG_DIR": os.environ["CLAUDE_FIXTURE"],
    "HTTPS_PROXY": "http://127.0.0.1:1080",
    "IPCHECK_LANG": "en",
    "IPCHECK_PROGRESS": "always",
    "IPCHECK_TEST_CURL_LOG": os.environ["CURL_LOG"],
    "IPCHECK_TEST_CURL_SLEEP": "5",
})
command = [os.path.join(os.environ["PROJECT_DIR"], "bin", "ipcheck"), "--samples", "1", "--no-bandwidth"]

interrupt_tmp = os.path.join(os.environ["STUB_DIR"], "interrupt-tmp")
os.mkdir(interrupt_tmp)
interrupt_env = env.copy()
interrupt_env["TMPDIR"] = interrupt_tmp
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=interrupt_env)
time.sleep(0.5)
started = time.monotonic()
process.send_signal(signal.SIGINT)
_, stderr = process.communicate(timeout=2)
assert process.returncode == 130, process.returncode
assert time.monotonic() - started < 2
assert "Cancelled." in stderr, stderr
assert not glob.glob(os.path.join(interrupt_tmp, "ipcheck.*"))

term_tmp = os.path.join(os.environ["STUB_DIR"], "term-tmp")
os.mkdir(term_tmp)
term_env = env.copy()
term_env["TMPDIR"] = term_tmp
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=term_env)
time.sleep(0.5)
started = time.monotonic()
process.terminate()
process.communicate(timeout=2)
assert process.returncode == 143, process.returncode
assert time.monotonic() - started < 2
assert not glob.glob(os.path.join(term_tmp, "ipcheck.*"))
PY
fi

grep -Fq -- "--max-time \"\$TIMEOUT\"" "$PROJECT_DIR/bin/ipcheck"
grep -Fq "networkQuality -c -s -M \"\$TIMEOUT\"" "$PROJECT_DIR/bin/ipcheck"
grep -q 'download_bits_per_second' "$PROJECT_DIR/bin/ipcheck"
grep -q 'value / 1000000' "$PROJECT_DIR/bin/ipcheck"

system_report=$(run_ipcheck --samples 1 --no-bandwidth --system --json)
printf '%s\n' "$system_report" | grep -q '"download_bits_per_second":10000000'
printf '%s\n' "$system_report" | grep -q '"upload_bits_per_second":5000000'
system_human=$(run_ipcheck --samples 1 --no-bandwidth --system)
printf '%s\n' "$system_human" | grep -q 'macOS networkQuality: down 10.0 Mbps, up 5.0 Mbps'

set +e
blocked_report=$(run_ipcheck --samples 1 --no-bandwidth --endpoint https://blocked.invalid --json)
blocked_exit=$?
set -e
[ "$blocked_exit" -eq 1 ]
printf '%s\n' "$blocked_report" | grep -q '"http_code":"000"'
printf '%s\n' "$blocked_report" | grep -q '"bandwidth":{"enabled":false,"available":false,"http_code":"000"'
printf '%s\n' "$blocked_report" | grep -q '"score":0,"score_label":"LIMITED","score_method":"rule_v2"'

markdown=$(run_ipcheck --samples 1 --no-bandwidth --markdown)
printf '%s\n' "$markdown" | grep -q '^# ipcheck: AI Coding Network Report'
printf '%s\n' "$markdown" | grep -q '| Claude Code |'
printf '%s\n' "$markdown" | grep -q '| Jitter |'

chinese_markdown=$(IPCHECK_LANG=zh run_ipcheck --samples 1 --no-bandwidth --markdown)
printf '%s\n' "$chinese_markdown" | grep -q '^# ipcheck：AI 编程网络报告'
printf '%s\n' "$chinese_markdown" | grep -q '现在适合开发吗？'
printf '%s\n' "$chinese_markdown" | grep -q '^## AI 服务延迟（TTFB）$'

quick_report=$(run_ipcheck --quick --json)
printf '%s\n' "$quick_report" | grep -q '"samples":1'
printf '%s\n' "$quick_report" | grep -q '"bandwidth":{"enabled":false'
printf '%s\n' "$quick_report" | grep -q '"upload":{"enabled":false'

set +e
run_ipcheck --service invalid >/dev/null 2>&1
invalid_exit=$?
set -e
[ "$invalid_exit" -eq 2 ]

for numeric_option in --samples --timeout; do
  set +e
  run_ipcheck "$numeric_option" 9223372036854775808 >/dev/null 2>&1
  invalid_exit=$?
  set -e
  [ "$invalid_exit" -eq 2 ]
done

printf 'ipcheck smoke tests: ok\n'
