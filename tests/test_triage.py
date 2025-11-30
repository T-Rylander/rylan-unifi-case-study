import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from 03_ai_helpdesk.triage_engine.main import app

client = TestClient(app)

@patch(''ollama.chat'')
@patch(''presidio_analyzer.AnalyzerEngine.analyze'')
def test_auto_close(mock_analyze, mock_ollama):
    mock_analyze.return_value = []
    mock_ollama.return_value = {''message'': {''content'': ''{{"confidence": 0.95, "action": "auto-close"}}''}}
    response = client.post(''/triage'', json={''text'': ''Test ticket'', ''vlan_source'': ''30'', ''user_role'': ''user''})
    assert response.status_code == 200
    assert response.json()[ ''action'' ] == ''auto-close''

@patch(''ollama.chat'')
@patch(''presidio_analyzer.AnalyzerEngine.analyze'')
def test_escalate(mock_analyze, mock_ollama):
    mock_analyze.return_value = []
    mock_ollama.return_value = {''message'': {''content'': ''{{"confidence": 0.85, "action": "escalate"}}''}}
    response = client.post(''/triage'', json={''text'': ''Complex issue'', ''vlan_source'': ''90'', ''user_role'': ''guest''})
    assert response.status_code == 418
