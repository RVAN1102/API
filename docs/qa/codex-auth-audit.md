Billing/Admin use FastAPI HTTPBearer as if it validates JWTs. It does not. It only checks that an Authorization: Bearer ... header is present and returns the raw credentials object.
The affected route handlers never call validate_token, never verify signature/expiry/issuer/JWKS, and never enforce roles. That is why Bearer abc and Bearer fake.jwt.token are accepted.
2. Affected Files And Functions
[services/billing/main.py (line 142)](/home/rvan1102/API/services/billing/main.py:142)
create_checkout
Uses credentials: HTTPAuthorizationCredentials = Depends(security) at line 146.
No JWT validation or role check.

[services/admin/main.py (line 219)](/home/rvan1102/API/services/admin/main.py:219)
run_maintenance
metadata_fetch_vulnerable
metadata_fetch_fixed
All depend only on local HTTPBearer presence checks at lines 223, 244, and 289.

3. Current Vulnerable Behavior
Endpoints using Bearer presence-only checks:
POST /api/v1/billing/checkout
POST /api/v1/admin/maintenance
POST /api/v1/admin/metadata-fetch/vulnerable
POST /api/v1/admin/metadata-fetch/fixed
Unaffected/public by design:
GET /api/v1/billing/health
GET /api/v1/admin/health
Unaffected and must stay HMAC-only:
POST /api/v1/webhooks/payment
4. Existing Reusable Auth Logic From User/Order
Yes, User/Order JWT validation can be reused.
Reusable pieces:
[services/user/auth.py (line 91)](/home/rvan1102/API/services/user/auth.py:91) and [services/order/auth.py (line 73)](/home/rvan1102/API/services/order/auth.py:73)
Fetch JWKS from Keycloak.
Verify RS256 signature.
Verify exp.
Verify issuer equals http://keycloak:8080/realms/topic10-sme-api.
Return payload or raise 401.

[services/user/authz.py (line 29)](/home/rvan1102/API/services/user/authz.py:29) and [services/order/authz.py (line 21)](/home/rvan1102/API/services/order/authz.py:21)
require_role(...) raises 403 when a valid token lacks required roles.
Existing roles: user, admin, billing-service, internal-service.

Realm/export evidence:
[idp/realm-export/topic10-realm.json (line 58)](/home/rvan1102/API/idp/realm-export/topic10-realm.json:58) defines realm roles:user
admin
billing-service
internal-service

Seeded users:alice: user
bob: user
admin01: user, admin

scopeMappings and clientScopeMappings are empty in the export.
[idp/jwt-claims.md (line 56)](/home/rvan1102/API/idp/jwt-claims.md:56) already documents that all backend services should perform full JWT validation.
5. Minimal Patch Plan
For Admin:
Replace raw credentials = Depends(security) with a validated payload dependency.
Call require_admin(payload) before executing:run_maintenance
metadata_fetch_vulnerable
metadata_fetch_fixed

Result:malformed token: 401
valid non-admin token: 403
valid admin token: route behavior proceeds.


For Billing checkout:
Replace raw credentials = Depends(security) with a validated payload dependency.
Safest minimal role rule: require user or admin.
Reason: current Billing README uses a user token for checkout, and the realm export does not assign billing-service to the service account. If checkout is later confirmed as service-to-service only, change this to billing-service after fixing realm role assignment.

Keep unchanged:
Billing/admin health routes public.
Payment webhook HMAC-only, no Bearer JWT dependency.
User/Order auth behavior.

Implementation shape:
Prefer local Admin/Billing auth helpers copied from User/Order, or a shared helper if the service packaging already supports it.
Do not import User service internals directly from Admin/Billing containers unless the runtime Python path guarantees that works.
6. Exact Tests To Run After Patch
Start stack:
docker compose -f infra/docker-compose.yml up -d --build
Get tokens:
bash demo/auth/get-user-token.sh alice >/tmp/alice-token.log
ALICE_TOKEN=$(cat /tmp/user-token.txt)

bash demo/auth/get-user-token.sh admin01 >/tmp/admin-token.log
ADMIN_TOKEN=$(cat /tmp/user-token.txt)
Expected checks:
# Public health stays public
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/v1/billing/health
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/api/v1/admin/health

# Malformed Bearer tokens now fail with 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer abc" -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'

curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/v1/admin/maintenance \
  -H "Authorization: Bearer fake.jwt.token" -H "Content-Type: application/json" \
  -d '{"action":"rotate-logs"}'

# Valid non-admin token fails admin with 403
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/v1/admin/maintenance \
  -H "Authorization: Bearer ${ALICE_TOKEN}" -H "Content-Type: application/json" \
  -d '{"action":"rotate-logs"}'

# Valid admin token succeeds admin
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/v1/admin/maintenance \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" -H "Content-Type: application/json" \
  -d '{"action":"rotate-logs"}'

# Billing checkout succeeds for user/admin token
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8000/api/v1/billing/checkout \
  -H "Authorization: Bearer ${ALICE_TOKEN}" -H "Content-Type: application/json" \
  -d '{"order_id":"ord-alice-1001","amount":150000,"currency":"VND"}'

# Existing regressions
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-user-profile.sh
ACCESS_TOKEN="${ALICE_TOKEN}" bash tests/auth/test-order-access.sh
ACCESS_TOKEN="${ADMIN_TOKEN}" bash tests/attack/ssrf-attack.sh
bash tests/attack/webhook-forgery.sh
7. Risk Of Breaking Current Demo
Medium but expected.
Admin SSRF demo must use admin01; alice/bob should now get 403.
Billing checkout with alice should still work under the proposed user/admin rule.
Fake-token demo behavior intentionally changes from 200/202 to 401.
Admin/Billing protected routes will now depend on Keycloak/JWKS availability, matching User/Order.
8. Files That Should Not Be Modified
services/user/auth.py
services/order/auth.py
services/user/authz.py
services/order/authz.py
idp/jwt-claims.md
idp/realm-export/topic10-realm.json
Billing webhook logic in services/billing/main.py should not receive Bearer JWT auth.

Codex chạy xog r
