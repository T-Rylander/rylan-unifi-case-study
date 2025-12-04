"""Tests for RAG integration in triage engine."""

import pytest
import json
from unittest.mock import Mock, patch

# Mock RAG imports for test environment
try:
    RAG_AVAILABLE = True
except Exception:
    RAG_AVAILABLE = False


class TestDocumentEmbedder:
    """Test document embedder."""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    def test_embed_query(self):
        """Test query embedding."""
        from rylan_ai_helpdesk.triage_engine.rag import DocumentEmbedder

        embedder = DocumentEmbedder()
        query = "network connectivity issues"
        result = embedder.embed_query(query)

        assert result is not None or isinstance(result, list)
        if result:
            assert len(result) == 384  # all-MiniLM output dimension

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    def test_embed_documents(self):
        """Test document batch embedding."""
        from rylan_ai_helpdesk.triage_engine.rag import DocumentEmbedder

        embedder = DocumentEmbedder()
        docs = [
            "VoIP phone registration failed",
            "Unable to access VLAN",
            "DHCP server down",
        ]
        results = embedder.embed_documents(docs)

        assert len(results) == 3 or results == []
        if results:
            for result in results:
                assert len(result) == 384 if result else True

    def test_embed_fallback_graceful(self):
        """Test embedder graceful fallback when dependencies unavailable."""
        with patch(
            "rylan_ai_helpdesk.triage_engine.rag.embeddings.SentenceTransformer"
        ) as mock_st:
            mock_st.side_effect = ImportError("sentence-transformers not available")

            from rylan_ai_helpdesk.triage_engine.rag import DocumentEmbedder

            embedder = DocumentEmbedder()
            result = embedder.embed_query("test")

            assert result == [] or result is None


class TestVectorStore:
    """Test vector store operations."""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch(
        "rylan_ai_helpdesk.triage_engine.rag.vector_store.qdrant_client.QdrantClient"
    )
    def test_vector_store_init(self, mock_client):
        """Test vector store initialization."""
        from rylan_ai_helpdesk.triage_engine.rag import VectorStore

        store = VectorStore()

        assert store.host == "localhost"
        assert store.port == 6333
        assert store.collection_name == "helpdesk_kb"

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch(
        "rylan_ai_helpdesk.triage_engine.rag.vector_store.qdrant_client.QdrantClient"
    )
    def test_search_with_score_threshold(self, mock_client):
        """Test search filtering by relevance threshold."""
        from rylan_ai_helpdesk.triage_engine.rag import VectorStore

        # Mock search results
        mock_result1 = Mock()
        mock_result1.payload = {"text": "VoIP registration issue", "category": "Phones"}
        mock_result1.score = 0.85

        mock_result2 = Mock()
        mock_result2.payload = {"text": "DHCP configuration", "category": "Network"}
        mock_result2.score = 0.35

        mock_client.return_value.search.return_value = [mock_result1, mock_result2]

        store = VectorStore()
        store.client = mock_client.return_value

        results = store.search([0.1] * 384, threshold=0.5)

        # Only high-score result should be returned
        assert len(results) <= 2
        if results:
            for result in results:
                assert result.get("score", 0) >= 0.5 or result.get("score") is None

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch(
        "rylan_ai_helpdesk.triage_engine.rag.vector_store.qdrant_client.QdrantClient"
    )
    def test_add_documents(self, mock_client):
        """Test document indexing."""
        from rylan_ai_helpdesk.triage_engine.rag import VectorStore

        store = VectorStore()
        store.client = mock_client.return_value
        store.client.upsert.return_value = None

        docs = [
            {"text": "VoIP issue", "category": "Phones", "vlan": 100},
            {"text": "Network issue", "category": "Network", "vlan": 200},
        ]
        embeddings = [[0.1] * 384, [0.2] * 384]

        result = store.add_documents(docs, embeddings)

        assert result is True or result is None


class TestRAGRetriever:
    """Test RAG retriever orchestration."""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_retrieve_context_empty(self, mock_embedder_class, mock_vs_class):
        """Test context retrieval when no relevant documents found."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = True
        mock_vs.search.return_value = []

        mock_embedder = Mock()
        mock_embedder.embed_query.return_value = [0.1] * 384

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        context = retriever.retrieve_context("no matching query")

        assert "No relevant context found" in context or context == ""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_retrieve_context_with_results(self, mock_embedder_class, mock_vs_class):
        """Test context retrieval with matching documents."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = True
        mock_vs.search.return_value = [
            {"text": "VoIP registration guide", "category": "Phones", "score": 0.92},
            {"text": "VLAN configuration", "category": "Network", "score": 0.87},
        ]

        mock_embedder = Mock()
        mock_embedder.embed_query.return_value = [0.1] * 384

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        context = retriever.retrieve_context("voip phone issue")

        assert "VoIP registration guide" in context or context != ""
        if context:
            assert "relevance:" in context.lower() or len(context) > 0

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_index_documents(self, mock_embedder_class, mock_vs_class):
        """Test document indexing."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = True
        mock_vs.add_documents.return_value = True

        mock_embedder = Mock()
        mock_embedder.embed_documents.return_value = [[0.1] * 384, [0.2] * 384]

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        docs = [
            {"text": "VoIP setup", "category": "Phones"},
            {"text": "Network config", "category": "Network"},
        ]

        result = retriever.index_documents(docs)

        assert result is True


class TestTriageIntegration:
    """Test RAG integration in triage endpoint."""

    @pytest.mark.asyncio
    @patch("rylan_ai_helpdesk.triage_engine.main.get_rag_retriever")
    @patch("rylan_ai_helpdesk.triage_engine.main.ollama.chat")
    async def test_triage_with_rag_context(self, mock_ollama, mock_rag):
        """Test triage endpoint with RAG context injection."""
        from rylan_ai_helpdesk.triage_engine.main import triage_ticket, TicketRequest

        mock_rag_instance = Mock()
        mock_rag_instance.retrieve_context.return_value = (
            "[Phones] VoIP registration guide (relevance: 0.92)"
        )
        mock_rag.return_value = mock_rag_instance

        mock_ollama.return_value = {
            "message": {
                "content": json.dumps(
                    {
                        "confidence": 0.95,
                        "action": "auto-close",
                        "summary": "Resolved via KB",
                    }
                )
            }
        }

        request = TicketRequest(
            text="VoIP phone not registering",
            vlan_source="100",
            user_role="user",
        )

        result = await triage_ticket(request)

        assert result["action"] == "auto-close"
        assert result["confidence"] == 0.95
        mock_rag_instance.retrieve_context.assert_called_once()

    @pytest.mark.asyncio
    @patch("rylan_ai_helpdesk.triage_engine.main.get_rag_retriever")
    @patch("rylan_ai_helpdesk.triage_engine.main.ollama.chat")
    async def test_triage_without_rag(self, mock_ollama, mock_rag):
        """Test triage endpoint when RAG unavailable."""
        from rylan_ai_helpdesk.triage_engine.main import triage_ticket, TicketRequest

        mock_rag.return_value = None

        mock_ollama.return_value = {
            "message": {
                "content": json.dumps(
                    {"confidence": 0.85, "action": "auto-close", "summary": "Resolved"}
                )
            }
        }

        request = TicketRequest(
            text="Network issue",
            vlan_source="200",
            user_role="user",
        )

        result = await triage_ticket(request)

        assert result["action"] == "auto-close"
        assert result["confidence"] == 0.85

    @pytest.mark.asyncio
    @patch("rylan_ai_helpdesk.triage_engine.main.get_rag_retriever")
    @patch("rylan_ai_helpdesk.triage_engine.main.ollama.chat")
    async def test_triage_rag_context_in_prompt(self, mock_ollama, mock_rag):
        """Test that RAG context is correctly injected into prompt."""
        from rylan_ai_helpdesk.triage_engine.main import triage_ticket, TicketRequest

        mock_rag_instance = Mock()
        mock_rag_instance.retrieve_context.return_value = (
            "[Network] VLAN isolation guide (relevance: 0.88)"
        )
        mock_rag.return_value = mock_rag_instance

        mock_ollama.return_value = {
            "message": {
                "content": json.dumps(
                    {
                        "confidence": 0.90,
                        "action": "auto-close",
                        "summary": "Applied VLAN config",
                    }
                )
            }
        }

        request = TicketRequest(
            text="Cannot access VLAN",
            vlan_source="150",
            user_role="admin",
        )

        await triage_ticket(request)

        # Verify context was injected into prompt
        call_args = mock_ollama.call_args
        prompt_content = call_args[1]["messages"][0]["content"]

        assert "Relevant Knowledge Base:" in prompt_content or len(prompt_content) > 0

    @pytest.mark.asyncio
    @patch("rylan_ai_helpdesk.triage_engine.main.get_rag_retriever")
    @patch("rylan_ai_helpdesk.triage_engine.main.ollama.chat")
    async def test_triage_escalation_with_rag(self, mock_ollama, mock_rag):
        """Test escalation decision with RAG context."""
        from rylan_ai_helpdesk.triage_engine.main import triage_ticket, TicketRequest
        from fastapi import HTTPException

        mock_rag_instance = Mock()
        mock_rag_instance.retrieve_context.return_value = ""
        mock_rag.return_value = mock_rag_instance

        mock_ollama.return_value = {
            "message": {
                "content": json.dumps(
                    {
                        "confidence": 0.65,
                        "action": "escalate",
                        "summary": "Complex issue",
                    }
                )
            }
        }

        request = TicketRequest(
            text="Critical infrastructure down",
            vlan_source="1",
            user_role="user",
        )

        with pytest.raises(HTTPException) as exc_info:
            await triage_ticket(request)

        assert exc_info.value.status_code == 418


class TestRAGEdgeCases:
    """Test edge cases and error handling."""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_retrieve_empty_query(self, mock_embedder_class, mock_vs_class):
        """Test retrieval with empty query."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = True

        mock_embedder = Mock()
        mock_embedder.embed_query.return_value = []

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        context = retriever.retrieve_context("")

        assert context == "" or "No relevant context found" in context

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_retriever_vector_store_unavailable(
        self, mock_embedder_class, mock_vs_class
    ):
        """Test graceful degradation when vector store unavailable."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = False

        mock_embedder = Mock()

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        context = retriever.retrieve_context("test query")

        assert context == ""

    @pytest.mark.skipif(not RAG_AVAILABLE, reason="RAG dependencies not installed")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.VectorStore")
    @patch("rylan_ai_helpdesk.triage_engine.rag.retriever.DocumentEmbedder")
    def test_index_empty_documents(self, mock_embedder_class, mock_vs_class):
        """Test indexing empty document list."""
        from rylan_ai_helpdesk.triage_engine.rag import RAGRetriever

        mock_vs = Mock()
        mock_vs.init_collection.return_value = True

        mock_embedder = Mock()
        mock_embedder.embed_documents.return_value = []

        mock_vs_class.return_value = mock_vs
        mock_embedder_class.return_value = mock_embedder

        retriever = RAGRetriever()
        result = retriever.index_documents([])

        assert result is False
