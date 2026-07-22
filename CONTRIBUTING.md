# Contributing to ipcheck

Thanks for helping make AI coding network diagnostics more reliable.

## Before opening an issue

1. Run `ipcheck --version` and include the version.
2. Run `ipcheck --quick --markdown` and attach the redacted report.
3. Remove any organization-private hostnames you do not want to disclose.
4. Search existing issues for the same client, gateway, or proxy behavior.

Do not post API keys, auth tokens, proxy passwords, cookies, or unredacted
credential files. Use GitHub's private vulnerability reporting for security
issues.

## Development

ipcheck supports Bash 3.2, including the Bash version bundled with older macOS
releases. Avoid associative arrays and newer Bash-only syntax.

Run the local checks:

```bash
bash -n bin/ipcheck
bash test/smoke.sh
shellcheck bin/ipcheck test/smoke.sh
```

The smoke suite uses stubbed network commands and must not require internet
access or real credentials.

## Pull requests

- Keep each pull request focused.
- Add tests for behavior changes and failure modes.
- Update both English and Chinese documentation for user-facing changes.
- Preserve backward-compatible flags and JSON fields when practical.
- Never add code that extracts, stores, prints, or forwards client
  authentication credentials.
- Explain which real client behavior or official documentation the change
  matches.

All CI jobs must pass before merge. Maintainers may request a real, redacted
report for a new provider or gateway.

## Adding a client or gateway

A new built-in probe should:

1. Derive its route only from documented, non-secret configuration.
2. Avoid credentials, query parameters, redirects, and billable inference.
3. Use the same proxy behavior as the client as closely as possible.
4. Distinguish network reachability from an invalid protocol route.
5. Add stub tests for success, timeout, proxy authentication, and redaction.

By contributing, you agree that your contribution is licensed under Apache-2.0.
