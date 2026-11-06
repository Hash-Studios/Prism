# Authentication for Prism integrations

Public catalog reads, including wallpaper search, wallpaper details, categories, and pricing, do not require authentication. An agent uses the `anonymous` identity type for these reads. Do not send credentials to public read endpoints.

The machine-readable summary is in the `agent_auth` block of [the authorization server metadata](/.well-known/oauth-authorization-server). It names the `identity_endpoint`, `claim_endpoint`, and `events_endpoint` under `https://prismwalls.com/agent/`. Those endpoints answer with structured JSON. They do not issue tokens.

## Discover

Fetch `/.well-known/oauth-protected-resource` for the protected resource and `/.well-known/oauth-authorization-server` for the `agent_auth` block and its `skill`, which points back to this file. A protected endpoint that needs a token answers 401 with a `WWW-Authenticate: Bearer resource_metadata="https://prismwalls.com/.well-known/oauth-protected-resource"` header.

## Pick a method

Public reads use the `anonymous` method. Prism does not accept `identity_assertion` or `service_auth` credentials on this website, and it does not accept an `id-jag` assertion (`urn:ietf:params:oauth:token-type:id-jag`). Do not mint an assertion for Prism.

## Register

Agent registration is not supported on this website. There is no self-serve agent signup and no client registration endpoint. People create accounts in the Prism app on Android or iOS.

## Claim

The claim endpoint does not create a claim. It returns a JSON error that explains agent authentication is not available and that public catalogue endpoints need no authentication.

## Exchange

There is no token exchange. No endpoint trades an assertion or a code for an access token, because protected agent access is not offered.

## Use the access_token

There is no `access_token` to use on prismwalls.com. Call the public API at `/api/v1` or the MCP server at `/mcp` without an Authorization header.

## Errors

Errors are JSON with an `error.code`, `error.message`, and `error.hint`. A 401 means the endpoint needs an app account, not an agent token. A 503 with code `catalog_unavailable` means the public catalogue is temporarily down.

## Revocation

There is nothing to revoke, because no agent token is issued. People manage their Prism account and sessions inside the app.
