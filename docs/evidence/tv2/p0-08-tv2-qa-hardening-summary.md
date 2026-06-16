# TV2 P0.8 QA hardening summary

The previous QA hardening pass identified 10 known issues. This closeout branch does not claim that the whole system has no remaining bugs. The correct status is: 10 known issues identified in the QA hardening pass were fixed or triaged.

Main merged checkpoint:
- `f68a472 merge qa hardening fixes into main`

Auth/core-related hardening status:
- JWT validation is enabled for user, order, admin, and billing services.
- Admin and billing APIs reject fake or malformed tokens.
- User and order services had issuer/JWKS mismatch fixed and are checked again in this closeout branch.
- `/api/v1/users/me` requires a valid token.
- `/api/v1/admin/maintenance` enforces the `admin` role.
- `/api/v1/billing/checkout` requires a valid authenticated token.
- Order `/vulnerable` is intentionally retained as a BOLA demonstration endpoint.
- Order `/fixed` is the protected mitigation endpoint and blocks cross-owner access.
- Keycloak MFA runtime enforcement was added by assigning `CONFIGURE_TOTP` required action to demo human users.

Intentional demo:
- `/api/v1/orders/{order_id}/vulnerable` is not reported as an unfixed production bug. It exists to demonstrate Broken Object Level Authorization.
- `/api/v1/orders/{order_id}/fixed` is the mitigation endpoint used as the protected reference.

MFA status:
- `alice`, `bob`, and `admin01` have `CONFIGURE_TOTP` required action enforced in the local Keycloak runtime.
- Realm export was patched so the required action is preserved when the realm is re-imported.
- Browser screenshots should be captured separately for final reporting if the demo needs visual evidence of the OTP setup/challenge screen.
