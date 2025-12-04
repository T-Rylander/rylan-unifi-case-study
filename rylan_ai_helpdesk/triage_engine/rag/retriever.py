"""RAG retriever for context augmentation in triage engine."""

from typing import List, Dict, Any
import logging
import time

logger = logging.getLogger(__name__)


class RAGRetriever:
    """Retrieves context from knowledge base to augment LLM prompts."""

    def __init__(
        self,
        host: str = "localhost",
        port: int = 6333,
        embedder_model: str = "all-MiniLM-L6-v2",
    ):
        """Initialize RAG retriever.

        Args:
            host: Qdrant server host
            port: Qdrant server port
            embedder_model: HuggingFace embedding model name
        """
        from .vector_store import VectorStore
        from .embeddings import DocumentEmbedder

        self.vector_store = VectorStore(host, port)
        self.embedder = DocumentEmbedder(embedder_model)
        self.initialized = self.vector_store.init_collection()

        if self.initialized:
            logger.info("RAG retriever initialized successfully")
        else:
            logger.warning(
                "RAG retriever initialization failed - vector store unavailable"
            )

    def retrieve_context(self, query: str, limit: int = 3) -> str:
        """Get relevant context from knowledge base.

        Args:
            query: Search query from ticket
            limit: Maximum number of documents to retrieve

        Returns:
            Formatted context string for LLM prompt
        """
        if not self.initialized:
            logger.debug("Vector store not initialized - returning empty context")
            return ""

        start_time = time.time()

        try:
            # Embed query
            query_vector = self.embedder.embed_query(query)
            if not query_vector:
                logger.warning("Failed to embed query")
                return ""

            # Search vector store
            results = self.vector_store.search(query_vector, limit=limit)

            elapsed = (time.time() - start_time) * 1000  # Convert to ms
            logger.info(f"Retrieved {len(results)} documents in {elapsed:.1f}ms")

            # Format context
            context_parts = []
            for result in results:
                text = result.get("text", "")
                category = result.get("category", "General")
                score = result.get("score", 0)
                context_parts.append(f"[{category}] {text} (relevance: {score:.2f})")

            if not context_parts:
                return "No relevant context found."

            return "\n".join(context_parts)

        except Exception as e:
            logger.error(f"Context retrieval failed: {e}")
            return ""

    def index_documents(self, documents: List[Dict[str, Any]]) -> bool:
        """Index documents for retrieval.

        Args:
            documents: List of dicts with 'text', 'category', 'vlan', etc.

        Returns:
            True if successful, False otherwise
        """
        if not self.initialized:
            logger.warning("Vector store not initialized - cannot index documents")
            return False

        try:
            # Extract text from documents
            texts = [doc.get("text", "") for doc in documents]

            if not texts:
                logger.warning("No texts to embed")
                return False

            # Generate embeddings
            embeddings = self.embedder.embed_documents(texts)

            if not embeddings or not embeddings[0]:
                logger.warning("Failed to generate embeddings")
                return False

            # Store in vector DB
            success = self.vector_store.add_documents(documents, embeddings)

            if success:
                logger.info(f"Indexed {len(documents)} documents successfully")

            return success

        except Exception as e:
            logger.error(f"Document indexing failed: {e}")
            return False

    def update_knowledge_base(self, kb_file: str) -> bool:
        """Load and index knowledge base from file.

        Args:
            kb_file: Path to knowledge base file (JSON or CSV)

        Returns:
            True if successful, False otherwise
        """
        try:
            import json

            with open(kb_file, "r") as f:
                documents = json.load(f)

            if not isinstance(documents, list):
                logger.error("Knowledge base must be a JSON array")
                return False

            return self.index_documents(documents)

        except Exception as e:
            logger.error(f"Failed to load knowledge base: {e}")
            return False
