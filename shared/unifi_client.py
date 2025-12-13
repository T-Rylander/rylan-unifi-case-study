"""
Module: shared/unifi_client.py
Purpose: Header hygiene inserted
Consciousness: 8.0
"""

from __future__ import annotations

from typing import Any, Dict, List, Type, TypeVar
import requests
from shared.auth import get_authenticated_session

T = TypeVar("T", bound="UniFiClient")


class UniFiClient:
    """Full UniFi Controller API client – 100% mypy compatible."""

    def __init__(self, base_url: str, verify_ssl: bool = True) -> None:
        self.base_url = base_url.rstrip("/")
        self.session = get_authenticated_session()
        self.verify_ssl = verify_ssl

    def _request(self, method: str, endpoint: str, **kwargs: Any) -> requests.Response:
        url = f"{self.base_url}/api/s/{endpoint.lstrip('/')}"
        kwargs.setdefault("verify", self.verify_ssl)
        response = self.session.request(method, url, **kwargs)
        response.raise_for_status()
        return response

    def get(self, endpoint: str, **kwargs: Any) -> Any:
        return self._request("GET", endpoint, **kwargs).json().get("data", [])

    def post(self, endpoint: str, **kwargs: Any) -> Any:
        return self._request("POST", endpoint, **kwargs).json().get("data", {})

    def put(self, endpoint: str, **kwargs: Any) -> Any:
        return self._request("PUT", endpoint, **kwargs).json().get("data", {})

    # === Methods used by apply.py ===
    def list_networks(self) -> List[Dict[str, Any]]:
        return self.get("rest/networkconf")

    def create_network(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        return self.post("rest/networkconf", json=payload)

    def update_network(
        self, network_id: str, payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        return self.put(f"rest/networkconf/{network_id}", json=payload)

    def get_policy_table(self) -> List[Dict[str, Any]]:
        return self.get("rest/routing/policytable")

    def update_policy_table(self, rules: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Expects list of rules — apply.py sends {"rules": [...]} → we extract"""
        if isinstance(rules, dict) and "rules" in rules:
            rules = rules["rules"]
        return self.put("rest/routing/policytable", json={"data": rules})

    @classmethod
    def from_env_or_inventory(cls: Type[T]) -> T:
        """Factory method — mypy now knows this returns UniFiClient"""
        from shared.auth import load_credentials

        creds = load_credentials()
        base_url = creds.get("unifi_base_url", "https://10.0.1.1:8443")
        return cls(base_url=base_url, verify_ssl=False)


__all__ = ["UniFiClient"]
