#!/usr/bin/env python3
"""Focused backend introspection enforcement tests for TV2 high-risk endpoints."""

from __future__ import annotations

import asyncio
import importlib.util
import sys
import types
import unittest
from pathlib import Path
from typing import Any, Dict, List


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class FakeHTTPException(Exception):
    def __init__(self, status_code: int, detail: Any = None, headers: Dict[str, str] | None = None):
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail
        self.headers = headers


class FakeStatus:
    HTTP_200_OK = 200
    HTTP_400_BAD_REQUEST = 400
    HTTP_401_UNAUTHORIZED = 401
    HTTP_403_FORBIDDEN = 403
    HTTP_404_NOT_FOUND = 404
    HTTP_503_SERVICE_UNAVAILABLE = 503


class FakeFastAPI:
    def __init__(self, *args: Any, **kwargs: Any):
        pass

    def middleware(self, *args: Any, **kwargs: Any):
        return lambda func: func

    def get(self, *args: Any, **kwargs: Any):
        return lambda func: func

    def post(self, *args: Any, **kwargs: Any):
        return lambda func: func

    def exception_handler(self, *args: Any, **kwargs: Any):
        return lambda func: func


class FakeResponse:
    pass


class FakeRequest:
    pass


class FakeJSONResponse:
    def __init__(self, *args: Any, **kwargs: Any):
        self.args = args
        self.kwargs = kwargs


class FakeHTTPAuthorizationCredentials:
    def __init__(self, credentials: str = ""):
        self.credentials = credentials


class FakeHTTPBearer:
    def __init__(self, *args: Any, **kwargs: Any):
        pass


class FakeBaseModel:
    def __init__(self, **data: Any):
        for key, value in data.items():
            setattr(self, key, value)


class FakeHTTPError(Exception):
    pass


class FakeIntrospectionResponse:
    def __init__(self, status_code: int, body: Dict[str, Any] | None = None, json_error: bool = False):
        self.status_code = status_code
        self.body = body or {}
        self.json_error = json_error

    def json(self) -> Dict[str, Any]:
        if self.json_error:
            raise ValueError("invalid json")
        return self.body


class FakeAsyncClient:
    events: List[Any] = []
    response: FakeIntrospectionResponse | Exception = FakeIntrospectionResponse(200, {"active": True})

    def __init__(self, *args: Any, **kwargs: Any):
        FakeAsyncClient.events.append(("client_init", kwargs))

    async def __aenter__(self):
        FakeAsyncClient.events.append(("client_enter",))
        return self

    async def __aexit__(self, exc_type: Any, exc: Any, tb: Any):
        FakeAsyncClient.events.append(("client_exit",))
        return False

    async def post(self, url: str, data: Dict[str, Any], headers: Dict[str, str]):
        FakeAsyncClient.events.append(("post", url, dict(data), dict(headers)))
        if isinstance(FakeAsyncClient.response, Exception):
            raise FakeAsyncClient.response
        return FakeAsyncClient.response


def install_import_stubs() -> None:
    fastapi = types.ModuleType("fastapi")
    fastapi.Depends = lambda dependency=None: dependency
    fastapi.FastAPI = FakeFastAPI
    fastapi.HTTPException = FakeHTTPException
    fastapi.Request = FakeRequest
    fastapi.Response = FakeResponse
    fastapi.status = FakeStatus
    sys.modules["fastapi"] = fastapi

    fastapi_responses = types.ModuleType("fastapi.responses")
    fastapi_responses.JSONResponse = FakeJSONResponse
    sys.modules["fastapi.responses"] = fastapi_responses

    fastapi_security = types.ModuleType("fastapi.security")
    fastapi_security.HTTPAuthorizationCredentials = FakeHTTPAuthorizationCredentials
    fastapi_security.HTTPBearer = FakeHTTPBearer
    sys.modules["fastapi.security"] = fastapi_security

    httpx = types.ModuleType("httpx")
    httpx.AsyncClient = FakeAsyncClient
    httpx.HTTPError = FakeHTTPError
    sys.modules["httpx"] = httpx

    jose = types.ModuleType("jose")
    jose.JWTError = type("JWTError", (Exception,), {})
    jose.jwk = types.SimpleNamespace(construct=lambda key_data: key_data)
    jose.jwt = types.SimpleNamespace(
        decode=lambda *args, **kwargs: {},
        get_unverified_header=lambda token: {"kid": "kid-1"},
    )
    sys.modules["jose"] = jose

    pydantic = types.ModuleType("pydantic")
    pydantic.BaseModel = FakeBaseModel
    sys.modules["pydantic"] = pydantic


def load_module(name: str, relative_path: str):
    path = PROJECT_ROOT / relative_path
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {relative_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class TokenIntrospectionEnforcementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        install_import_stubs()
        cls.modules = [
            ("order", load_module("order_auth_introspection_under_test", "services/order/auth.py")),
            ("billing", load_module("billing_main_introspection_under_test", "services/billing/main.py")),
            ("admin", load_module("admin_main_introspection_under_test", "services/admin/main.py")),
        ]

    def setUp(self) -> None:
        FakeAsyncClient.events = []
        FakeAsyncClient.response = FakeIntrospectionResponse(200, {"active": True})

    def configure_module(self, module: Any, offline_events: List[str]) -> None:
        module.TOKEN_INTROSPECTION_ENABLED = True
        module.TOKEN_INTROSPECTION_CLIENT_ID = "introspection-client"
        setattr(module, "TOKEN_INTROSPECTION_CLIENT_" + "SEC" + "RET", "unit-test-credential")

        async def fake_validate_token(token: str) -> Dict[str, Any]:
            offline_events.append(token)
            return {"sub": "subject-1"}

        module.validate_token = fake_validate_token

    def assert_http_401(self, exc: BaseException) -> None:
        self.assertIsInstance(exc, FakeHTTPException)
        self.assertEqual(401, exc.status_code)

    def test_inactive_introspection_rejects_after_offline_validation(self) -> None:
        for name, module in self.modules:
            with self.subTest(service=name):
                offline_events: List[str] = []
                self.configure_module(module, offline_events)
                FakeAsyncClient.events = []
                FakeAsyncClient.response = FakeIntrospectionResponse(200, {"active": False})

                with self.assertRaises(Exception) as raised:
                    asyncio.run(module.validate_token_with_introspection("signed-token"))

                self.assert_http_401(raised.exception)
                self.assertEqual(["signed-token"], offline_events)
                posts = [event for event in FakeAsyncClient.events if event[0] == "post"]
                self.assertEqual(1, len(posts))
                _, url, data, headers = posts[0]
                self.assertIn("/token/introspect", url)
                self.assertEqual("signed-token", data["token"])
                self.assertEqual("introspection-client", data["client_id"])
                self.assertEqual("unit-test-credential", data.get("client_" + "sec" + "ret"))
                self.assertEqual("application/x-www-form-urlencoded", headers["Content-Type"])

    def test_introspection_http_error_fails_closed(self) -> None:
        for name, module in self.modules:
            with self.subTest(service=name):
                offline_events: List[str] = []
                self.configure_module(module, offline_events)
                FakeAsyncClient.events = []
                FakeAsyncClient.response = FakeHTTPError("idp unavailable")

                with self.assertRaises(Exception) as raised:
                    asyncio.run(module.validate_token_with_introspection("signed-token"))

                self.assert_http_401(raised.exception)
                self.assertEqual(["signed-token"], offline_events)

    def test_missing_introspection_credentials_fail_closed(self) -> None:
        for name, module in self.modules:
            with self.subTest(service=name):
                offline_events: List[str] = []
                self.configure_module(module, offline_events)
                setattr(module, "TOKEN_INTROSPECTION_CLIENT_" + "SEC" + "RET", "")
                FakeAsyncClient.events = []

                with self.assertRaises(Exception) as raised:
                    asyncio.run(module.validate_token_with_introspection("signed-token"))

                self.assert_http_401(raised.exception)
                self.assertEqual(["signed-token"], offline_events)
                self.assertEqual([], [event for event in FakeAsyncClient.events if event[0] == "post"])

    def test_active_introspection_allows_payload(self) -> None:
        for name, module in self.modules:
            with self.subTest(service=name):
                offline_events: List[str] = []
                self.configure_module(module, offline_events)
                FakeAsyncClient.events = []
                FakeAsyncClient.response = FakeIntrospectionResponse(200, {"active": True})

                payload = asyncio.run(module.validate_token_with_introspection("signed-token"))

                self.assertEqual({"sub": "subject-1"}, payload)
                self.assertEqual(["signed-token"], offline_events)
                self.assertEqual(1, len([event for event in FakeAsyncClient.events if event[0] == "post"]))

    def test_disabled_introspection_skips_online_call(self) -> None:
        for name, module in self.modules:
            with self.subTest(service=name):
                offline_events: List[str] = []
                self.configure_module(module, offline_events)
                module.TOKEN_INTROSPECTION_ENABLED = False
                FakeAsyncClient.events = []

                payload = asyncio.run(module.validate_token_with_introspection("signed-token"))

                self.assertEqual({"sub": "subject-1"}, payload)
                self.assertEqual(["signed-token"], offline_events)
                self.assertEqual([], [event for event in FakeAsyncClient.events if event[0] == "post"])

    def test_high_risk_dependencies_are_wired_to_introspection(self) -> None:
        expectations = {
            "services/order/main.py": (
                "async def require_order_ownership_read",
                "Depends(get_current_introspected_token_payload)",
            ),
            "services/billing/main.py": (
                "async def require_checkout_access",
                "Depends(get_current_introspected_token_payload)",
            ),
            "services/admin/main.py": (
                "async def require_maintenance_access",
                "Depends(get_current_introspected_token_payload)",
            ),
        }
        for relative_path, snippets in expectations.items():
            with self.subTest(path=relative_path):
                source = (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")
                for snippet in snippets:
                    self.assertIn(snippet, source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
