import asyncio
import types

import pytest

# Minimal shim to import app from current path
import importlib.util
import sys
from pathlib import Path

triage_path = Path(__file__).parents[1] / '03-ai-helpdesk' / 'triage-engine' / 'main.py'
spec = importlib.util.spec_from_file_location("triage_main", str(triage_path))
assert spec is not None and spec.loader is not None
triage_main = importlib.util.module_from_spec(spec)
sys.modules["triage_main"] = triage_main
spec.loader.exec_module(triage_main)

app = triage_main.app
AnalyzerEngine = triage_main.AnalyzerEngine

class DummyAnalyzer:
    def analyze(self, text, entities=None, language='en'):
        # Pretend it found an email and phone
        return [
            types.SimpleNamespace(entity_type='EMAIL_ADDRESS', start=0, end=5),
            types.SimpleNamespace(entity_type='PHONE_NUMBER', start=6, end=10)
        ]
    @property
    def analyzer_redactor(self):
        class Redactor:
            def redact(self, text, results):
                class Result:
                    def __init__(self, text):
                        self.text = text
                return Result(text.replace('john@example.com', 'REDACTED_EMAIL').replace('555-1234', 'REDACTED_PHONE'))
        return Redactor()

# Monkeypatch presidio analyzer
triage_main.analyzer = DummyAnalyzer()

# Monkeypatch ollama chat
class DummyOllama:
    def chat(self, model, messages):
        # Return deterministic high confidence for password resets
        if 'Password reset' in messages[0]['content']:
            return {"message": {"content": "{'category': 'password_reset', 'confidence': 0.95, 'action': 'auto-close', 'summary': 'Reset password via AD portal'}"}}
        return {"message": {"content": "{'category': 'other', 'confidence': 0.70, 'action': 'escalate', 'summary': 'Needs human'}"}}

triage_main.ollama = DummyOllama()

@pytest.mark.asyncio
async def test_triage_autoclose():
    ticket = triage_main.TicketInput(text="Password reset for john@example.com 555-1234", vlan_source="30", user_role="employee")
    resp = await triage_main.triage_ticket(ticket)
    assert resp["action"] == "auto-close"
    assert resp["confidence"] >= 0.93

@pytest.mark.asyncio
async def test_triage_escalate():
    ticket = triage_main.TicketInput(text="Printer jam in office", vlan_source="30", user_role="employee")
    with pytest.raises(triage_main.HTTPException) as exc:
        await triage_main.triage_ticket(ticket)
    assert exc.value.status_code == 418
