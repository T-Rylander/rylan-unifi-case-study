"""Qdrant vector database integration for document storage and retrieval."""

from typing import List, Dict, Any
import logging
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct

logger = logging.getLogger(__name__)


class VectorStore:
    """Vector database for RAG document storage using Qdrant."""

    def __init__(self, host: str = "localhost", port: int = 6333):
        """Initialize Qdrant client.

        Args:
            host: Qdrant server host (default: localhost for Docker)
            port: Qdrant server port (default: 6333)
        """
        try:
            self.client = QdrantClient(host, port=port, timeout=5.0)
            logger.info(f"Connected to Qdrant at {host}:{port}")
        except Exception as e:
            logger.error(f"Failed to connect to Qdrant: {e}")
            self.client = None

        self.collection_name = "helpdesk_kb"
        self.vector_size = 384  # all-MiniLM-L6-v2 output size

    def init_collection(self) -> bool:
        """Create collection for first-time initialization.

        Returns:
            True if successful, False otherwise
        """
        if not self.client:
            logger.warning("Qdrant client not available")
            return False

        try:
            # Check if collection exists
            collections = self.client.get_collections()
            existing = [c.name for c in collections.collections]

            if self.collection_name in existing:
                logger.info(f"Collection '{self.collection_name}' already exists")
                return True

            # Create new collection
            self.client.recreate_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(
                    size=self.vector_size, distance=Distance.COSINE
                ),
            )
            logger.info(f"Created collection '{self.collection_name}'")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize collection: {e}")
            return False

    def add_documents(
        self, documents: List[Dict[str, Any]], vectors: List[List[float]]
    ) -> bool:
        """Add documents with embeddings to vector store.

        Args:
            documents: List of document dicts with 'text', 'category', etc.
            vectors: List of embedding vectors (must match document count)

        Returns:
            True if successful, False otherwise
        """
        if not self.client:
            logger.warning("Qdrant client not available")
            return False

        if len(documents) != len(vectors):
            logger.error(
                f"Document count ({len(documents)}) != vector count ({len(vectors)})"
            )
            return False

        try:
            points = [
                PointStruct(id=i, vector=vectors[i], payload=doc)
                for i, doc in enumerate(documents)
            ]
            self.client.upsert(
                collection_name=self.collection_name,
                points=points,
            )
            logger.info(f"Added {len(documents)} documents to vector store")
            return True
        except Exception as e:
            logger.error(f"Failed to add documents: {e}")
            return False

    def search(
        self, query_vector: List[float], limit: int = 3, score_threshold: float = 0.5
    ) -> List[Dict[str, Any]]:
        """Search for similar documents.

        Args:
            query_vector: Query embedding vector
            limit: Maximum number of results to return
            score_threshold: Minimum similarity score (0-1)

        Returns:
            List of matching documents with similarity scores
        """
        if not self.client:
            logger.warning("Qdrant client not available")
            return []

        try:
            results = self.client.search(
                collection_name=self.collection_name,
                query_vector=query_vector,
                limit=limit,
                score_threshold=score_threshold,
            )
            return [
                {
                    **result.payload,
                    "score": result.score,
                }
                for result in results
            ]
        except Exception as e:
            logger.error(f"Search failed: {e}")
            return []

    def delete_collection(self) -> bool:
        """Delete collection (for testing/cleanup).

        Returns:
            True if successful, False otherwise
        """
        if not self.client:
            return False

        try:
            self.client.delete_collection(collection_name=self.collection_name)
            logger.info(f"Deleted collection '{self.collection_name}'")
            return True
        except Exception as e:
            logger.error(f"Failed to delete collection: {e}")
            return False
