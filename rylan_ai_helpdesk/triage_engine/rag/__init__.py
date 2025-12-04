"""RAG (Retrieval-Augmented Generation) for AI Helpdesk.

Provides vector-based document retrieval to augment LLM prompts with
relevant knowledge base context, improving triage accuracy and consistency.
"""

from .vector_store import VectorStore
from .retriever import RAGRetriever
from .embeddings import DocumentEmbedder

__all__ = ["VectorStore", "RAGRetriever", "DocumentEmbedder"]
