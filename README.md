# Archyve

A RAG archive: documents arrive from **sources**, get processed into chunks and
embeddings, and are grouped into **collections** people can search and chat over.

- **Architecture & decisions** — `docs/architecture.md`
- **Design rules** — `docs/design.md`, and `/styleguide` in the running app
- **Open work** — `docs/todo.md`

## Running it

Everything goes through [ops](https://github.com/nickthecook/crops), which loads
configuration from `config/<env>/config.yml` and decrypts secrets from
`config/<env>/secrets.ejson`.

```sh
ops up       # Postgres (pgvector) and Docling in Docker
ops rails db:prepare
ops rails db:seed
ops server   # http://localhost:3000
ops test     # the whole suite
ops lint
```

`ops rails db:seed` creates the break-glass admin from `ARCHYVE_ADMIN_EMAIL` and
`ARCHYVE_ADMIN_PASSWORD`. In development both default, so a fresh clone can be
signed into without setting anything up.

## Running it in containers

`container/compose.yml` runs Archyve, Postgres and Docling. It reads its
configuration from the environment it runs in:

| Variable | |
|---|---|
| `ARCHYVE_DATABASE_PASSWORD` | Required. Postgres is created with it. |
| `ARCHYVE_ADMIN_EMAIL`, `ARCHYVE_ADMIN_PASSWORD` | Required. The break-glass admin. |
| `ARCHYVE_HOST` | The public hostname. Archyve expects a TLS-terminating proxy in front. |
| `ARCHYVE_FORCE_TLS` | Set to `false` to serve plain HTTP, e.g. on `localhost` without a proxy. |
| `OLLAMA_API_BASE` | Seeds an Ollama server, e.g. `http://ollama:11434/v1`. |
| `ARCHYVE_SSO_*` | Optional; see below. |
| `ARCHYVE_PORT` | Host port for the web container (default 3000). |

`SECRET_KEY_BASE` and the `ACTIVE_RECORD_ENCRYPTION_*` keys are generated on
first boot into the `keys` volume. Back that volume up with `postgres`: without
it, stored credentials can't be decrypted.

```sh
ops container start   # or `ops c start`; plain `docker compose up -d` works too
ops c logs
ops c stop
```

## Single sign-on with Keycloak

Archyve can authenticate against any OIDC provider; Keycloak is what it is
developed against. SSO is **authentication only** — Keycloak decides who may
sign in, Archyve decides what they can do. Everyone it provisions arrives as a
plain `user` with no collection or source access, to be raised by an admin from
Settings → Users.

With SSO configured, the sign-in page leads with it and keeps the password form
behind a "Use a password" disclosure. With it unconfigured, the button is hidden
and both SSO routes refuse — the local password form is the only way in.

Why it is built the way it is — why identity is keyed on `sub`, why the ID
token's signature is not verified, why sessions expire after a day — is in
`docs/architecture.md` under "Single sign-on".

### 1. Configuration

Four variables, **all required**: `Sso.configured?` is all-or-nothing, so there
is no state in which SSO is enabled but ungated.

In `config/<env>/config.yml`:

```yaml
environment:
  ARCHYVE_SSO_ISSUER: https://auth.example.net/realms/my-realm
  ARCHYVE_SSO_CLIENT_ID: archyve
  ARCHYVE_SSO_GROUP: /archyve-users
  ARCHYVE_HOST: archyve.example.net
```

In `config/<env>/secrets.ejson`:

```json
{ "environment": { "ARCHYVE_SSO_CLIENT_SECRET": "..." } }
```

`ARCHYVE_SSO_ISSUER` is the realm URL — the one the discovery document lives
under at `{issuer}/.well-known/openid-configuration`. `ARCHYVE_HOST` pins
`config.hosts`; the OIDC `redirect_uri` is built from the `Host` header, so
this is what stops a spoofed one bending it. An optional `ARCHYVE_EXTRA_HOSTS`
(comma-separated) adds further permitted hosts alongside it, in any
environment — e.g. a LAN hostname used to reach a dev server.

### 2. The client

**Clients → Create client**, OpenID Connect, then:

| Setting | Value |
|---|---|
| Client authentication | **On** (confidential — Archyve holds a secret) |
| Standard flow | **On** |
| Direct access grants, Implicit, Service accounts | Off |
| Valid redirect URIs | `https://<host>/sso/callback` — exact, no wildcard |
| Valid post logout redirect URIs | `https://<host>/session/new` |
| Web origins | *leave empty* — Archyve makes no browser-side calls |
| Advanced → PKCE Challenge Method | `S256` |

The client secret is on the **Credentials** tab; that is what goes in
`secrets.ejson`.

For local development the URIs are `http://localhost:3000/...` — plain HTTP,
since there is no proxy in front.

### 3. The group

**Groups → Create group**, e.g. `archyve-users`. Add people with
**Users → *user* → Groups → Join Group**.

Whatever you name it, `ARCHYVE_SSO_GROUP` must match the group's **full path**,
leading slash included — `/archyve-users` for a top-level group,
`/parent/archyve-users` for a nested one.

### 4. The group membership mapper

The claim does not appear in tokens until a mapper puts it there.

1. **Clients → *your client* → Client scopes** tab. This is the tab on the
   client's own page, not the realm-level "Client scopes" in the sidebar — the
   two are different screens with the same name.
2. Click the first row, **`<client-id>-dedicated`**. Mappers live inside the
   client's private scope; there is no Mappers tab on the client itself.
3. **Mappers → Configure a new mapper → Group Membership**

| Field | Value |
|---|---|
| Name | anything, e.g. `groups` |
| Token Claim Name | `groups` |
| Full group path | **On** |
| Add to ID token | **On** |
| Add to access token / userinfo | Off — Archyve reads neither |

Use the client's dedicated scope rather than editing a shared one, so no other
client's tokens change.

### 5. Verify before trying to sign in

**Clients → *your client* → Client scopes → Evaluate**. Pick a user from the
**Users** typeahead — you have to *click* the match, not just type it, or the
panel stays empty — then open **Generated ID token**. You want:

```json
{
  "iss": "https://auth.example.net/realms/my-realm",
  "aud": "archyve",
  "sub": "8c1f3118-...",
  "email": "person@example.com",
  "email_verified": true,
  "groups": ["/archyve-users"]
}
```

`nonce` is absent here and that is fine — Evaluate synthesises a token outside a
real authorization request. Archyve checks it on the live flow.

### 6. Production

Production must sit behind a TLS-terminating reverse proxy.
`config.assume_ssl` is what makes `redirect_uri` come out as `https`, and
`config.force_ssl` is what marks the session cookie secure; both are on in
`config/environments/production.rb`. The proxy must send
`X-Forwarded-Proto: https`, or every request redirects in a loop.

**Keep the break-glass admin working.** It is the way in when SSO is down, so
sign in with it once before relying on SSO, and note that linking an SSO
identity to an existing account never clears its password.

## Troubleshooting

| Symptom | Cause |
|---|---|
| No "Sign in with SSO" button | One of the four variables is unset — most often the secret, which lives in `secrets.ejson` rather than `config.yml` |
| "Your account doesn't have access to Archyve." | Not in the group, or `ARCHYVE_SSO_GROUP` doesn't match the claim. Compare against Evaluate |
| `groups` claim missing from the token | Mapper absent, on the wrong scope, or "Add to ID token" off |
| `groups` present but without a leading slash | "Full group path" is off on the mapper |
| "An Archyve account already uses that email address." | The address belongs to an account with a different (or no) `sub` — typically a Keycloak user that was deleted and recreated. Clear the stale link: `User.find_by(email_address: "…").update!(sso_subject: nil, sso_issuer: nil)` |
| Signing in creates a second account instead of linking | `email_verified` is false, so Archyve refuses to link on it. Common with LDAP federation |
| Keycloak rejects the logout | Post-logout redirect URI not registered |
| Signed in, but nothing is visible | Working as intended: new SSO users get no grants. Raise them in Settings → Users |
| Every request redirects in a loop | The proxy isn't sending `X-Forwarded-Proto: https` |

## License

[GNU Affero General Public License v3.0](LICENSE) or later.
