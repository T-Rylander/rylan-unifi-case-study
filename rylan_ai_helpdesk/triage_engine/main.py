from fastapi import FastAPI, HTTPException

from pydantic import BaseModel

import ollama

import json


try:
    from presidio_analyzer import AnalyzerEngine  # type: ignore

    PRESIDIO_AVAILABLE = True

except Exception:  # pragma: no cover - optional in CI
    AnalyzerEngine = None  # type: ignore

    PRESIDIO_AVAILABLE = False


try:
    from .rag import RAGRetriever

    RAG_AVAILABLE = True

except Exception:  # pragma: no cover - optional if Qdrant unavailable
    RAGRetriever = None  # type: ignore

    RAG_AVAILABLE = False


app = FastAPI()

rag_retriever = None


class TicketRequest(BaseModel):
    text: str

    vlan_source: str

    user_role: str


def get_analyzer():
    """Lazy-load Presidio analyzer only when needed."""

    if not PRESIDIO_AVAILABLE:
        return None

    try:
        return AnalyzerEngine()

    except Exception:
        return None


def get_rag_retriever():
    """Lazy-load RAG retriever only when needed."""

    global rag_retriever

    if not RAG_AVAILABLE:
        return None

    if rag_retriever is None:
        try:
            rag_retriever = RAGRetriever()

        except Exception:
            return None

    return rag_retriever


@app.post("/triage")
async def triage_ticket(ticket: TicketRequest):
    # Lazy-load analyzer only if PII detection is needed

    # analyzer = get_analyzer()

    # Retrieve RAG context if available

    rag_context = ""

    rag_retriever = get_rag_retriever()

    if rag_retriever:
        rag_context = rag_retriever.retrieve_context(ticket.text)

        if rag_context:
            rag_context = f"\nRelevant Knowledge Base:\n{rag_context}\n"

    prompt = f"""Analyze this IT ticket and respond with JSON only:

Ticket: {ticket.text}

VLAN: {ticket.vlan_source}

Role: {ticket.user_role}{rag_context}

Respond with: {{"confidence": 0.0-1.0, "action": "auto-close" or "escalate", "summary": "brief action"}}"""

    response = ollama.chat(
        model="llama3.2", messages=[{"role": "user", "content": prompt}]
    )

    try:
        decision = json.loads(response["message"]["content"])

        if decision["action"] == "escalate":
            raise HTTPException(status_code=418, detail="Escalation required")

        return {
            "action": decision["action"],
            "confidence": decision["confidence"],
            "summary": decision.get("summary", "Auto-resolved"),
        }

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="LLM response parsing failed")


@app.get("/health")
async def health():
    return {"status": "ok"}
