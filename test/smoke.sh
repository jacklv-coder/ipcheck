#!/usr/bin/env bash

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STUB_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ipcheck-test.XXXXXX")
trap 'rm -rf "$STUB_DIR"' EXIT INT TERM

cat > "$STUB_DIR/curl" <<'EOF'
#!/usr/bin/env bash
is_bandwidth=0
is_blocked=0
is_flaky=0
is_proxy_auth=0
for argument in "$@"; do
  case "$argument" in
    *speed.cloudflare.com*) is_bandwidth=1 ;;
    *blocked.invalid*) is_blocked=1 ;;
    *flaky.invalid*) is_flaky=1 ;;
    *proxy-auth.invalid*) is_proxy_auth=1 ;;
  esac
done
if [ "$is_flaky" -eq 1 ]; then
  attempt_file="${IPCHECK_TEST_ATTEMPT_FILE:?}"
  attempt=$(($(cat "$attempt_file" 2>/dev/null || printf 0) + 1))
  printf '%s' "$attempt" > "$attempt_file"
  if [ "$attempt" -gt 1 ]; then
    exit 28
  fi
  printf '401\t0.001\t0.002\t0.003\t0.100\t0.100\t151\t1000'
elif [ "$is_proxy_auth" -eq 1 ]; then
  printf '407\t0.001\t0.002\t0.003\t0.050\t0.050\t100\t1000'
elif [ "$is_blocked" -eq 1 ]; then
  exit 28
elif [ "$is_bandwidth" -eq 1 ]; then
  bandwidth_code=${IPCHECK_TEST_BANDWIDTH_CODE:-200}
  printf '%s\t2000000\t10000000' "$bandwidth_code"
else
  first_byte=${IPCHECK_TEST_TTFB:-0.100}
  printf '401\t0.001\t0.002\t0.003\t%s\t%s\t151\t1000' "$first_byte" "$first_byte"
fi
EOF
chmod +x "$STUB_DIR/curl"

cat > "$STUB_DIR/networkQuality" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{
  "base_rtt" : 25,
  "dl_throughput" : 10000000,
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

bash -n "$PROJECT_DIR/bin/ipcheck"
"$PROJECT_DIR/bin/ipcheck" --help | grep -q '^ipcheck - diagnose'

report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 3 --no-bandwidth --json)
printf '%s\n' "$report" | grep -q '"result":"good"'
printf '%s\n' "$report" | grep -q '"reachable_endpoints":2'
printf '%s\n' "$report" | grep -q '"http_code":"401"'

decimal_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 08 --timeout 08 --no-bandwidth --endpoint https://decimal.invalid --json)
printf '%s\n' "$decimal_report" | grep -q '"samples":8'
printf '%s\n' "$decimal_report" | grep -q '"successful_samples":8'

fair_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  IPCHECK_TEST_TTFB=1.000 "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --json)
printf '%s\n' "$fair_report" | grep -q '"result":"fair"'

attempt_file="$STUB_DIR/attempt"
printf 0 > "$attempt_file"
flaky_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  IPCHECK_TEST_ATTEMPT_FILE="$attempt_file" "$PROJECT_DIR/bin/ipcheck" --samples 5 --no-bandwidth \
  --endpoint https://flaky.invalid --json)
printf '%s\n' "$flaky_report" | grep -q '"result":"poor"'
printf '%s\n' "$flaky_report" | grep -q '"primary_success_rate_pct":20'
printf '%s\n' "$flaky_report" | grep -q '"successful_samples":1'

precedence_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  CODEX_NETWORK_ENDPOINTS="https://blocked.invalid" "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth \
  --endpoint https://cli.invalid --json)
printf '%s\n' "$precedence_report" | grep -q '"url":"https://cli.invalid"'
if printf '%s\n' "$precedence_report" | grep -q 'blocked.invalid'; then
  printf 'CLI endpoint did not override CODEX_NETWORK_ENDPOINTS\n' >&2
  exit 1
fi

set +e
proxy_auth_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 2 --no-bandwidth --endpoint https://proxy-auth.invalid --json)
proxy_auth_exit=$?
set -e
[ "$proxy_auth_exit" -eq 1 ]
printf '%s\n' "$proxy_auth_report" | grep -q '"result":"blocked"'
printf '%s\n' "$proxy_auth_report" | grep -q '"http_code":"407"'
printf '%s\n' "$proxy_auth_report" | grep -q '"successful_samples":0'
printf '%s\n' "$proxy_auth_report" | grep -q 'proxy requires authentication'

sensitive_endpoint='https://alice:topsecret@secure.invalid/path?token=verysecret#private'
sensitive_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --endpoint "$sensitive_endpoint" --json)
printf '%s\n' "$sensitive_report" | grep -Fq 'https://***@secure.invalid/path?<redacted>'
if printf '%s\n' "$sensitive_report" | grep -Eq 'alice|topsecret|verysecret|private'; then
  printf 'endpoint credentials leaked into JSON report\n' >&2
  exit 1
fi
sensitive_human=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --endpoint "$sensitive_endpoint")
if printf '%s\n' "$sensitive_human" | grep -Eq 'alice|topsecret|verysecret|private'; then
  printf 'endpoint credentials leaked into human report\n' >&2
  exit 1
fi

proxy_fallback_report=$(env -u HTTPS_PROXY -u https_proxy -u ALL_PROXY -u all_proxy \
  PATH="$STUB_DIR:$PATH" HTTP_PROXY="http://ignored.invalid:8080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --json)
printf '%s\n' "$proxy_fallback_report" | grep -q 'macOS HTTPS proxy=127.0.0.1:1082'
if printf '%s\n' "$proxy_fallback_report" | grep -q 'HTTP_PROXY'; then
  printf 'HTTP_PROXY incorrectly suppressed HTTPS system proxy fallback\n' >&2
  exit 1
fi

bandwidth_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --json)
printf '%s\n' "$bandwidth_report" | grep -q '"bandwidth":{"enabled":true,"available":true,"http_code":"200"'
invalid_bandwidth_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  IPCHECK_TEST_BANDWIDTH_CODE=407 "$PROJECT_DIR/bin/ipcheck" --samples 1 --json)
printf '%s\n' "$invalid_bandwidth_report" | grep -q '"bandwidth":{"enabled":true,"available":false,"http_code":"407","bytes":0,"bytes_per_second":0}'

[ "$(grep -c -- '--max-time "$TIMEOUT"' "$PROJECT_DIR/bin/ipcheck")" -eq 2 ]
grep -q 'networkQuality -c -u -M "$TIMEOUT"' "$PROJECT_DIR/bin/ipcheck"
grep -q 'download_bits_per_second' "$PROJECT_DIR/bin/ipcheck"
grep -q 'value / 1000000' "$PROJECT_DIR/bin/ipcheck"

system_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --system --json)
printf '%s\n' "$system_report" | grep -q '"download_bits_per_second":10000000'
system_human=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --system)
printf '%s\n' "$system_human" | grep -q 'macOS networkQuality: 10.0 Mbps'

set +e
blocked_report=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --endpoint https://blocked.invalid --json)
blocked_exit=$?
set -e
[ "$blocked_exit" -eq 1 ]
printf '%s\n' "$blocked_report" | grep -q '"http_code":"000"'
printf '%s\n' "$blocked_report" | grep -q '"bandwidth":{"enabled":false,"available":false,"http_code":"000"'

markdown=$(PATH="$STUB_DIR:$PATH" HTTPS_PROXY="http://127.0.0.1:1080" \
  "$PROJECT_DIR/bin/ipcheck" --samples 1 --no-bandwidth --markdown)
printf '%s\n' "$markdown" | grep -q '^# ipcheck: Codex Network Check'
printf '%s\n' "$markdown" | grep -q '| Jitter |'

printf 'ipcheck smoke tests: ok\n'
