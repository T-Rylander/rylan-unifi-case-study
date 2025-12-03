"""Tests for AI triage engine with PII redaction"""

import pytest
from unittest.mock import MagicMock

# Import redact_pii from app (will use Presidio or regex)
from app.redactor import redact_pii


def test_redact_pii_ipv4():
    assert redact_pii("IP 10.0.90.50") == "IP [REDACTED_IP]"


def test_redact_pii_mac_colon():
    assert redact_pii("MAC aa:bb:cc:dd:ee:ff") == "MAC [REDACTED_MAC]"


def test_redact_pii_mac_dash():
    assert redact_pii("MAC AA-BB-CC-DD-EE-FF") == "MAC [REDACTED_MAC]"


def test_redact_pii_email():
    result = redact_pii("Contact admin@rylan.internal")
    assert "admin@rylan.internal" not in result


@pytest.fixture
def mock_osticket():
    mock = MagicMock()
    mock.get_ticket.return_value = {
        "subject": "Guest WiFi broken",
        "body": "IP 10.0.90.50 can't reach support.internal",
    }
    return mock


def test_triage_confidence(mock_osticket):
    try:
        from app.triage import TriageEngine

        engine = TriageEngine()
        result = engine.triage(ticket_id=123)
        assert result["confidence"] >= 0.93
        assert "auto_close" in result
    except ImportError:
        pytest.skip("app.triage module not implemented yet")
