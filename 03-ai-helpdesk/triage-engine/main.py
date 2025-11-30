from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from presidio_analyzer import AnalyzerEngine
import ollama
import os
from dotenv import load_dotenv

load_dotenv()
app = FastAPI(title="Rylan AI Triage v5.0")
analyzer = AnalyzerEngine()

class TicketInput(BaseModel):
    text: str
    vlan_source: str
    user_role: str

@app.post("/triage")
async def triage_ticket(ticket: TicketInput):
    results = analyzer.analyze(text=ticket.text, entities=["PHONE_NUMBER", "EMAIL_ADDRESS"], language="en")
    redacted_text = analyzer.analyzer_redactor.redact(ticket.text, results).text
    priority_map = {"30": "high", "90": "low"}
    enriched = f"Priority: {priority_map.get(ticket.vlan_source, ''medium'')}. Role: {ticket.user_role}. Text: {redacted_text}"
    response = ollama.chat(model="llama3.3:70b", messages=[{"role": "user", "content": f"Classify IT ticket: {enriched}. Output JSON: {''category'': str, ''confidence'': float, ''action'': ''auto-close'' if >=0.93 else ''escalate'', ''summary'': str}}"}])
    output = eval(response["message"]["content"])
    if output["confidence"] >= 0.93:
        print(f"Auto-closing ticket with summary: {output[''summary'']}")
        return { "action": "auto-close", "confidence": output["confidence"] }
    raise HTTPException(status_code=418, detail="Escalate to agent")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
