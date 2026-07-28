# CueGrove Supply-Chain Security

This document describes the automated controls used for CueGrove website,
PromptDock, and repository dependencies. It complements [SECURITY.md](SECURITY.md).

## Automated controls

The `Supply chain security` GitHub Actions workflow:

- reviews dependency changes in every pull request and blocks newly introduced
  vulnerabilities rated high or critical;
- installs the exact versions in `pnpm-lock.yaml` and audits production
  dependencies on pull requests, production-branch pushes, manual runs, and a
  weekly schedule;
- scans the full Git history for credentials, API tokens, private keys, and
  other likely secrets with Gitleaks.

Dependabot checks the pnpm workspace and GitHub Actions each week. Its pull
requests remain subject to the same review, tests, build, audit, and secret scan
as human-authored changes.

## Handling findings

1. Critical findings are treated as release blockers.
2. High findings block new dependencies and production deployment unless an
   exception is documented below.
3. Moderate and low findings are reviewed according to exploitability,
   affected runtime path, and availability of a compatible fix.
4. Exposed credentials are revoked or rotated before the finding is marked
   resolved. Removing a secret from the latest commit alone is not sufficient.

Secret-scan false positives may only be ignored by their exact Gitleaks
fingerprint. The current ignore is the public RFC 6238 SHA-1 test vector in the
MFA test suite; broad rule or directory exclusions are not permitted.

Reports containing exploitable detail should be sent privately to
[security@cuegroveapp.com](mailto:security@cuegroveapp.com?subject=%5BSecurity%5D%20).

## Time-limited exceptions

| Advisory | Affected dependency | Reason the path is not exposed | Review by |
| --- | --- | --- | --- |
| `GHSA-qwww-vcr4-c8h2` | React Router 7 | The advisory affects React Server Components action handling. CueGrove is a client-only declarative router served as static files and does not use React Router RSC or server actions. The compatible upstream fix requires the React 19, Vite 7, and React Router 8 migration, which will be handled separately. | 2026-08-29 |

Exceptions must identify the affected path, explain why it is not reachable,
name a review date, and be removed as soon as a compatible fix is deployed.
