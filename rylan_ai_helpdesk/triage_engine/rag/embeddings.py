"""Document embeddings using SentenceTransformers for semantic search."""

from typing import List
import logging

logger = logging.getLogger(__name__)

# Lazy import - only load model when needed
_EMBEDDER = None


class DocumentEmbedder:
    """Generate embeddings for documents and queries using SentenceTransformers."""

    def __init__(self, model_name: str = "all-MiniLM-L6-v2"):
        """Initialize embedder with lightweight model.

        Args:
            model_name: HuggingFace model name (default: all-MiniLM-L6-v2)
        """
        global _EMBEDDER
        self.model_name = model_name

        try:
            from sentence_transformers import SentenceTransformer

            _EMBEDDER = SentenceTransformer(model_name)
            logger.info(f"Loaded embedder model: {model_name}")
        except ImportError:
            logger.warning("sentence-transformers not available - embeddings disabled")
            _EMBEDDER = None

    def embed_documents(self, documents: List[str]) -> List[List[float]]:
        """Convert documents to embeddings.

        Args:
            documents: List of text documents to embed

        Returns:
            List of embedding vectors (one per document)
        """
        if not _EMBEDDER:
            logger.warning("Embedder not initialized")
            return [[] for _ in documents]

        try:
            embeddings = _EMBEDDER.encode(documents, convert_to_tensor=False)
            logger.info(f"Embedded {len(documents)} documents")
            return embeddings.tolist()
        except Exception as e:
            logger.error(f"Embedding failed: {e}")
            return [[] for _ in documents]

    def embed_query(self, query: str) -> List[float]:
        """Convert query to embedding.

        Args:
            query: Query text to embed

        Returns:
            Embedding vector
        """
        if not _EMBEDDER:
            logger.warning("Embedder not initialized")
            return []

        try:
            embedding = _EMBEDDER.encode(query, convert_to_tensor=False)
            return embedding.tolist()
        except Exception as e:
            logger.error(f"Query embedding failed: {e}")
            return []
