# TV2 P0.7 MFA/2FA runtime status

The local Keycloak runtime has been updated to require OTP/TOTP setup for demo human users.

Implemented runtime control:
- `CONFIGURE_TOTP` required action is assigned to `alice`, `bob`, and `admin01`.
- The runtime status was verified through Keycloak Admin REST API.
- The realm export was patched so the MFA required action is preserved when the realm is re-imported.
- Password-only authentication is no longer considered sufficient for affected human users.

Evidence:
- `docs/evidence/tv2/p0-07-mfa-status-grep.txt`
- `docs/evidence/tv2/p0-07-mfa-runtime-enforce-command.txt`
- `docs/evidence/tv2/p0-07-mfa-runtime-status.txt`

Important note:
- The previous dev-only limitation has been closed for the local runtime after assigning `CONFIGURE_TOTP`.
- Browser-based login evidence should be captured separately to show the Keycloak OTP/TOTP setup or OTP challenge screen.
