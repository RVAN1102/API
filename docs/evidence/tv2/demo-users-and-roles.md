# Demo users and roles

`alice` is a demo user with role `user`. This account is used to test `/api/v1/users/me`, own-order access, billing checkout, and MFA/TOTP required action.

`bob` is a demo user with role `user`. This account is used to test the BOLA ownership boundary by comparing access to Bob's order from Bob's token and Alice's token.

`admin01` is a demo user with role `admin`. This account is used to test admin maintenance access, admin-only authorization behavior, and MFA/TOTP required action.

No production credential is documented here. Any local demo password, if present in repository scripts, is a local lab credential only and must not be reused outside the prototype.
