# Security policy

## Supported versions

Security fixes are provided for the latest released version of ipcheck.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability.

Use GitHub's **Report a vulnerability** button in the Security tab of
[jacklv-coder/ipcheck](https://github.com/jacklv-coder/ipcheck/security) to send
a private report. Include the affected version, impact, reproduction steps, and
any suggested mitigation. Do not include live third-party credentials.

You should receive an initial response within seven days. Confirmed issues will
be coordinated privately until a fix and release are available.

## Security boundaries

ipcheck is designed not to extract, store, print, or transmit Codex/Claude
authentication tokens. Its settings parser selects only routing and model-name
fields required to choose a safe probe. Reports redact URL credentials and
query strings.

If you find a path that exposes a token, proxy password, cookie, sensitive query
parameter, or credential-file content, treat it as a security vulnerability.
