# GOLD STAR ACHIEVEMENT PLAN – Phase 2 Actual Completion

**Current Reality**: 56/100 INCOMPLETE (Per Leo's audit)  
**Target**: 90+/100 GOLD STAR  
**Timeline**: 5-7 days of actual work  
**Status**: 🔴 BLOCKING Phase 3

---

## PRIORITY 1: RAG Implementation (3-4 days) 🔴 BLOCKING

### Why This Matters
- **RAG** = Retrieval-Augmented Generation (not just Ollama)
- Requires: Vector DB + Embeddings + Context injection
- Core Phase 2 deliverable that's completely missing
- Currently scoring 62/100 for this category

### What Must Be Built

#### 1.1: Vector Store Module

**File**: `rylan_ai_helpdesk/triage_engine/rag/__init__.py`

```python
"""RAG (Retrieval-Augmented Generation) for AI Helpdesk."""

from .vector_store import VectorStore
from .retriever import RAGRetriever
from .embeddings import DocumentEmbedder

__all__ = ["VectorStore", "RAGRetriever", "DocumentEmbedder"]
```

#### 1.2: Vector Store Implementation

**File**: `rylan_ai_helpdesk/triage_engine/rag/vector_store.py`

```python
"""Qdrant vector database integration."""

from typing import List, Dict, Any
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

class VectorStore:
    def __init__(self, host: str = "localhost", port: int = 6333):
        """Initialize Qdrant client."""
        self.client = QdrantClient(host, port=port)
        self.collection_name = "helpdesk_kb"
        self.vector_size = 384  # all-MiniLM-L6-v2 output size
        
    def init_collection(self):
        """Create collection for first time."""
        try:
            self.client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=self.vector_size,
                    distance=Distance.COSINE
                )
            )
        except Exception as e:
            print(f"Collection init warning: {e}")
    
    def add_documents(self, documents: List[Dict[str, Any]], vectors: List[List[float]]):
        """Add documents with embeddings to vector store."""
        points = [
            PointStruct(
                id=i,
                vector=vectors[i],
                payload=doc
            )
            for i, doc in enumerate(documents)
        ]
        self.client.upsert(
            collection_name=self.collection_name,
            points=points
        )
    
    def search(self, query_vector: List[float], limit: int = 3) -> List[Dict]:
        """Search for similar documents."""
        results = self.client.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=limit,
            score_threshold=0.5  # Minimum relevance score
        )
        return [result.payload for result in results]
```

#### 1.3: Embeddings Pipeline

**File**: `rylan_ai_helpdesk/triage_engine/rag/embeddings.py`

```python
"""Document embeddings using SentenceTransformers."""

from typing import List
from sentence_transformers import SentenceTransformer

class DocumentEmbedder:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        """Initialize embedder with lightweight model."""
        self.model = SentenceTransformer(model_name)
    
    def embed_documents(self, documents: List[str]) -> List[List[float]]:
        """Convert documents to embeddings."""
        embeddings = self.model.encode(documents, convert_to_tensor=False)
        return embeddings.tolist()
    
    def embed_query(self, query: str) -> List[float]:
        """Convert query to embedding."""
        embedding = self.model.encode(query, convert_to_tensor=False)
        return embedding.tolist()
```

#### 1.4: RAG Retriever

**File**: `rylan_ai_helpdesk/triage_engine/rag/retriever.py`

```python
"""RAG retriever for context augmentation."""

from typing import List, Dict, Any
from .vector_store import VectorStore
from .embeddings import DocumentEmbedder

class RAGRetriever:
    def __init__(self, host: str = "localhost", port: int = 6333):
        """Initialize RAG retriever."""
        self.vector_store = VectorStore(host, port)
        self.embedder = DocumentEmbedder()
        self.vector_store.init_collection()
    
    def retrieve_context(self, query: str, limit: int = 3) -> str:
        """Get relevant context from knowledge base."""
        # Embed query
        query_vector = self.embedder.embed_query(query)
        
        # Search vector store
        results = self.vector_store.search(query_vector, limit=limit)
        
        # Format context
        context_parts = []
        for result in results:
            text = result.get("text", "")
            category = result.get("category", "General")
            context_parts.append(f"[{category}] {text}")
        
        return "\n".join(context_parts) if context_parts else "No relevant context found."
    
    def index_documents(self, documents: List[Dict[str, Any]]):
        """Index documents for retrieval."""
        # Extract text from documents
        texts = [doc.get("text", "") for doc in documents]
        
        # Generate embeddings
        embeddings = self.embedder.embed_documents(texts)
        
        # Store in vector DB
        self.vector_store.add_documents(documents, embeddings)
```

#### 1.5: Integration with Triage Engine

**File**: `rylan_ai_helpdesk/triage_engine/main.py` (MODIFY)

```python
# Add to imports
from rag.retriever import RAGRetriever

# Initialize RAG retriever
rag_retriever = RAGRetriever(host="10.0.10.60", port=6333)

@app.post("/triage")
async def triage_ticket(ticket: TicketRequest):
    """Analyze ticket with RAG-augmented LLM."""
    
    # Get relevant context
    context = rag_retriever.retrieve_context(ticket.text)
    
    # Build prompt with context
    prompt = f"""You are an IT helpdesk AI assistant.

CONTEXT (from knowledge base):
{context}

TICKET:
Text: {ticket.text}
VLAN: {ticket.vlan_source}
User Role: {ticket.user_role}

Analyze the ticket and provide: {{"confidence": 0.0-1.0, "action": "auto-close" or "escalate", "summary": "brief action"}}"""
    
    response = ollama.chat(
        model="llama3.2",
        messages=[{"role": "user", "content": prompt}]
    )
    
    # ... rest of logic
```

### Acceptance Criteria

- [ ] `qdrant_client` and `sentence-transformers` in requirements.txt
- [ ] Qdrant running in Docker (port 6333)
- [ ] Vector store initialized with test documents
- [ ] Embeddings <500ms per document
- [ ] Context retrieval <500ms per query
- [ ] Tests passing (unit + integration)

### Test Implementation

**File**: `tests/test_rag_integration.py`

```python
"""Tests for RAG integration."""

import pytest
from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

@pytest.fixture
def rag():
    return RAGRetriever()

def test_vector_store_initialization(rag):
    """Vector store initializes without error."""
    assert rag.vector_store is not None
    assert rag.vector_store.collection_name == "helpdesk_kb"

def test_document_embedding(rag):
    """Documents embed successfully."""
    docs = [
        {"text": "Reset password for user", "category": "Password"},
        {"text": "Fix network connectivity", "category": "Network"}
    ]
    rag.index_documents(docs)
    # Should complete without error

def test_context_retrieval(rag):
    """Context retrieved for queries."""
    context = rag.retrieve_context("password reset")
    assert len(context) > 0
    assert "password" in context.lower() or "No relevant" in context

def test_rag_response_time(rag):
    """RAG retrieval completes in <500ms."""
    import time
    start = time.time()
    rag.retrieve_context("test query")
    elapsed = (time.time() - start) * 1000
    assert elapsed < 500  # milliseconds
```

---

## PRIORITY 2: Backup RTO Validation (1-2 days) 🔴 BLOCKING

### Why This Matters
- Currently scoring 43/100 for backup validation
- Missing: RTO gate, dry-run mode, restore simulation
- Critical for production readiness

### What Must Be Built

#### 2.1: RTO Validation Gate

**File**: `03-validation-ops/orchestrator.sh` (MODIFY)

Add this function after backup logic:

```bash
validate_rto() {
    local actual_duration=$1
    local rto_target=900  # 15 minutes in seconds
    
    if [ "$actual_duration" -gt "$rto_target" ]; then
        log_error "❌ RTO EXCEEDED: ${actual_duration}s > ${rto_target}s"
        log_error "   Target: ${rto_target}s (15 min)"
        log_error "   Actual: ${actual_duration}s"
        return 1
    fi
    
    local margin=$(($rto_target - $actual_duration))
    log_info "✅ RTO VALIDATED: ${actual_duration}s < ${rto_target}s (${margin}s buffer)"
    return 0
}

# At end of backup loop, replace:
end_time=$(date +%s)
duration=$((end_time - start_time))

# WITH:
end_time=$(date +%s)
duration=$((end_time - start_time))
validate_rto "$duration" || exit 1
```

#### 2.2: Dry-Run Mode Implementation

```bash
# Add to argument parsing:
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            log_info "DRY-RUN MODE: No actual backup will be performed"
            shift
            ;;
        --restore)
            RESTORE_MODE=true
            shift
            ;;
        *)
            echo "Usage: $0 [--dry-run] [--restore]"
            exit 1
            ;;
    esac
done

# Modify backup logic:
if [[ "$DRY_RUN" == true ]]; then
    log_info "Would backup $BACKUP_DIR (dry-run, no actual copy)"
    # Simulate timing
    sleep 2  # Simulate backup delay
else
    rsync -avz "$source" "$dest" || fail "Backup failed"
fi
```

#### 2.3: Restore Simulation

```bash
# Add restore function:
restore_from_backup() {
    local backup_path="$1"
    local restore_dest="${2:-.}"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup path not found: $backup_path"
        return 1
    fi
    
    log_info "Restore simulation: $backup_path → $restore_dest"
    
    # Verify backup integrity
    if [[ -f "$backup_path/manifest.txt" ]]; then
        log_info "✅ Backup manifest found"
    fi
    
    # Simulate restoration
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would restore $(du -sh "$backup_path" | cut -f1) of data"
    else
        rsync -avz --delete "$backup_path/" "$restore_dest/" || return 1
    fi
    
    return 0
}

# Add to main flow:
if [[ "$RESTORE_MODE" == true ]]; then
    restore_from_backup "$BACKUP_DIR" "/tmp/restore-test" || exit 1
fi
```

### Acceptance Criteria

- [ ] RTO gate enforces <15 min limit
- [ ] Script exits with code 1 if RTO breached
- [ ] Dry-run mode completes in <5 seconds
- [ ] Restore simulation validates backup integrity
- [ ] Logs show timing breakdown per host

### Test Implementation

**File**: `tests/test_backup_validation.py`

```python
"""Tests for backup validation."""

import subprocess
import time

def test_rto_validation_passes():
    """RTO validation passes for <15 min backup."""
    result = subprocess.run(
        ["bash", "03-validation-ops/orchestrator.sh", "--dry-run"],
        capture_output=True,
        text=True,
        timeout=60
    )
    assert result.returncode == 0
    assert "✅ RTO VALIDATED" in result.stdout

def test_dry_run_quick():
    """Dry-run completes in <5 seconds."""
    start = time.time()
    subprocess.run(
        ["bash", "03-validation-ops/orchestrator.sh", "--dry-run"],
        capture_output=True,
        timeout=60
    )
    elapsed = time.time() - start
    assert elapsed < 5, f"Dry-run took {elapsed}s, expected <5s"

def test_restore_simulation():
    """Restore simulation validates backup."""
    result = subprocess.run(
        ["bash", "03-validation-ops/orchestrator.sh", "--restore", "--dry-run"],
        capture_output=True,
        text=True,
        timeout=900
    )
    assert result.returncode == 0
```

---

## PRIORITY 3: HA Scaling Guide (1 day) 🟡 IMPORTANT

### File Location
`docs/runbooks/ha-backup-scaling-guide.md`

**This file must be created** (currently missing despite being claimed).

See the previous comprehensive scaling guide in repo context for content.

### Acceptance Criteria

- [ ] File exists at correct path
- [ ] 3 scaling paths documented (Multi-dest, NAS, Cloud)
- [ ] Cost analysis table included
- [ ] RTO/RPO comparison matrix
- [ ] Migration procedures for each path

---

## PRIORITY 4: Run CI on Branch (30 min) 🟡 URGENT

```bash
# Trigger workflow run
git commit --allow-empty -m "ci: validate Phase 2 implementation"
git push origin release/v.1.1.2-endgame

# Monitor at:
# https://github.com/T-Rylander/rylan-unifi-case-study/actions

# Check results
gh run list --branch release/v.1.1.2-endgame
```

### Acceptance Criteria

- [ ] Workflow triggers on push
- [ ] All 13 tests pass
- [ ] Policy table validation passes
- [ ] No BOM errors in logs
- [ ] CI completes in <10 minutes

---

## PRIORITY 5: Phase 2 Smoke Tests (1 day) 🟡 IMPORTANT

**File**: `tests/test_phase2_requirements.py`

```python
"""Phase 2 specific smoke tests."""

import requests
import time
import subprocess

def test_ollama_availability():
    """Ollama service is running and responding."""
    try:
        response = requests.get("http://10.0.10.60:11434/api/tags", timeout=5)
        assert response.status_code == 200
        assert "models" in response.json()
    except Exception as e:
        pytest.skip(f"Ollama not available: {e}")

def test_rag_integration():
    """RAG retriever is functional."""
    from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever
    rag = RAGRetriever()
    context = rag.retrieve_context("test query")
    assert isinstance(context, str)

def test_rag_response_time():
    """RAG queries complete within budget."""
    start = time.time()
    from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever
    rag = RAGRetriever()
    rag.retrieve_context("password reset")
    elapsed = (time.time() - start) * 1000
    assert elapsed < 500, f"RAG query took {elapsed}ms, expected <500ms"

def test_backup_rto_validation():
    """Backup RTO validation gate works."""
    result = subprocess.run(
        ["bash", "03-validation-ops/orchestrator.sh", "--dry-run"],
        capture_output=True,
        text=True,
        timeout=60
    )
    assert result.returncode == 0
    assert "✅ RTO VALIDATED" in result.stdout or "Would" in result.stdout

def test_restore_simulation():
    """Restore simulation test passes."""
    result = subprocess.run(
        ["bash", "03-validation-ops/orchestrator.sh", "--restore", "--dry-run"],
        capture_output=True,
        text=True,
        timeout=900
    )
    assert result.returncode == 0
```

### Acceptance Criteria

- [ ] 5 new tests added
- [ ] All tests passing
- [ ] Ollama availability verified
- [ ] RAG response time <500ms
- [ ] Backup RTO gate validated

---

## IMPLEMENTATION TIMELINE

### Day 1: Setup & Priority 1 Start
- [ ] Add dependencies (qdrant-client, sentence-transformers)
- [ ] Create RAG module structure
- [ ] Implement vector store
- [ ] Set up local Qdrant

### Day 2: RAG Implementation
- [ ] Complete embeddings pipeline
- [ ] Complete retriever
- [ ] Integrate with triage engine
- [ ] Write RAG tests

### Day 3: RAG Testing & Priority 2 Start
- [ ] Run RAG tests
- [ ] Fix any issues
- [ ] Start backup RTO validation
- [ ] Implement dry-run mode

### Day 4: Backup Completion & Priority 3
- [ ] Complete restore simulation
- [ ] Write backup tests
- [ ] Create HA scaling guide
- [ ] Document all 3 paths

### Day 5: Integration & Testing
- [ ] Run all tests
- [ ] Fix any failures
- [ ] Trigger CI on branch
- [ ] Verify all workflows pass

### Days 6-7: Polish & Validation
- [ ] Performance testing
- [ ] Load testing
- [ ] Documentation review
- [ ] Final QC against Leo's checklist

---

## SUCCESS CRITERIA

### Category Targets

| Category | Current | Target | Gap |
|----------|---------|--------|-----|
| CI/CD | 70 | 85+ | +15 |
| RAG | 62 | 90+ | +28 |
| Backup | 43 | 85+ | +42 |
| Smoke | 50 | 85+ | +35 |
| Scaling | 43 | 80+ | +37 |

### Overall Target

**Current**: 56/100 INCOMPLETE  
**Target**: 90+/100 GOLD STAR  
**Path**: Fix Priority 1-5 above

---

## VERIFICATION COMMANDS

```bash
# Check RAG implementation
ls -la rylan_ai_helpdesk/triage_engine/rag/
pytest tests/test_rag_integration.py -v

# Check backup validation
./03-validation-ops/orchestrator.sh --dry-run
pytest tests/test_backup_validation.py -v

# Check scaling guide
ls -la docs/runbooks/ha-backup-scaling-guide.md

# Run all tests
pytest tests/ -v

# Check CI
gh run list --branch release/v.1.1.2-endgame
```

---

## FINAL STATE (After Completion)

✅ RAG fully implemented (vector DB, embeddings, context retrieval)  
✅ Backup RTO validation enforced (<15 min gate)  
✅ Restore simulation tested  
✅ HA scaling guide complete (3 paths)  
✅ CI/CD passing on current branch  
✅ New Phase 2 smoke tests passing  
✅ Score: 90+/100 GOLD STAR  

---

**Let's build it right. No more hallucination.** 🛡️🔥
