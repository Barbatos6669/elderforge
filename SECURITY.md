# Security Policy

Elderforge is not yet production software. Security expectations will grow as networking, accounts, persistence, and public servers are added.

## Reporting

Please do not publicly disclose exploitable vulnerabilities before maintainers have had a chance to respond. Once a maintainer contact address exists, report security issues there with:

- A short summary.
- Reproduction steps.
- Expected impact.
- Any logs, screenshots, or proof-of-concept details that help verification.

## Scope

Security-sensitive areas will include:

- Authentication and account services.
- Server-authoritative gameplay validation.
- Inventory, trade, economy, and item duplication prevention.
- Chat, moderation, and user-generated content.
- Deployment scripts and secrets management.

## Public Repository Rules

This repository is public. Do not commit:

- Playit agent secrets, tunnel config files, or private tunnel tokens.
- Cloud provider API keys, SSH private keys, `.env` files, or deployment credentials.
- Private server IPs, admin passwords, database files, or account data.
- Paid or non-redistributable art/audio/model assets.

Public release assets may contain the current playtest server address. That address is not a secret; it only points clients at the test server. The server itself must still treat all clients as untrusted.
