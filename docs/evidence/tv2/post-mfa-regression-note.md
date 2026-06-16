# Post-MFA Regression Test Strategy

Human demo users remain MFA-enforced:

- `alice`
- `bob`
- `admin01`

These accounts must keep the `CONFIGURE_TOTP` required action. They are for
interactive human demonstrations and must not be used by password-only smoke or
regression automation after MFA enforcement.

Automation-only regression fixtures:

- `ci-alice`
- `ci-bob`
- `ci-admin`

The `ci-*` accounts are automation-only internal smoke/regression fixtures.
They are not production human users and should not be described or treated as
human demo accounts. They intentionally do not have `CONFIGURE_TOTP` so
non-interactive automation can continue to verify authn/authz regressions while
human demo users remain protected by MFA/TOTP.

Each `ci-*` fixture has `automation_owner` as a claim source for ownership
boundary testing:

- `ci-alice` -> `alice`
- `ci-bob` -> `bob`
- `ci-admin` -> `admin01`

This claim is only for internal regression evidence. It is not a production
bypass and must not be used to weaken human-user MFA/TOTP requirements.
Order service honors `automation_owner` only for the BOLA fixed endpoint's
ownership comparison and only when `automation_fixture=true` is present.

Each `ci-*` fixture also has `automation_fixture=true` so tokens and evidence
can identify these accounts as internal test fixtures.
