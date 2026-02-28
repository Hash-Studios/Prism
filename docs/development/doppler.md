# Doppler Secrets Workflow

Prism uses Doppler as the source of truth for runtime secrets.

- Project: `prism`
- Local config: `dev`
- Release config: `production`

`.env.example` remains a key contract reference only and is not used as runtime input by Make targets.

## Local onboarding

1. Install Doppler CLI: <https://docs.doppler.com/docs/install-cli>
2. From repo root, run:

```sh
make doppler-login
make setup-dev
```

3. Run the app:

```sh
make run
```

## CI/CD

Release workflows use Doppler Service Tokens.

- Required GitHub secret: `DOPPLER_TOKEN_PRODUCTION`

Workflows load secrets from `prism/production`.

## Secret update protocol

When adding or changing secrets:

1. Add/update key in Doppler (`prism/dev` and `prism/production` as needed).
2. Reflect key contract in:
   - `/.env.example`
   - `/lib/env/env.dart` (if app code reads it)
3. Run guards:

```sh
make secrets-guard
make env-guard
```

## Rotation procedure

1. Create a new Doppler Service Token for `prism/production`.
2. Update `DOPPLER_TOKEN_PRODUCTION` in GitHub Secrets.
3. Trigger a release workflow and verify successful secret fetch.
4. Revoke the old token.

## Troubleshooting

- `doppler: command not found`
  - Install CLI and retry.
- `no DOPPLER_TOKEN and not logged in`
  - Run `make doppler-login`.
- `cannot access prism/dev`
  - Confirm project/config names and team access.
- `missing key in Doppler config`
  - Add missing key to the selected config (`dev` or `production`).
