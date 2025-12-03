#!/usr/bin/env python3
"""PII Redactor: Presidio-first, regex fallback (Bauer paranoia)"""

import re
import logging
import importlib.util

# Check Presidio availability at import time (E402/F401 safe)
PRESIDIO_ANALYZER = importlib.util.find_spec("presidio_analyzer")
PRESIDIO_ANONYMIZER = importlib.util.find_spec("presidio_anonymizer")
PRESIDIO_AVAILABLE = PRESIDIO_ANALYZER is not None and PRESIDIO_ANONYMIZER is not None

if not PRESIDIO_AVAILABLE:
    logging.warning(
        "Presidio unavailable — using regex fallback "
        "(pip install presidio-analyzer presidio-anonymizer)"
    )


def redact_pii(text: str) -> str:
    """Redact IPs, MACs, emails via Presidio or regex."""
    if PRESIDIO_AVAILABLE:
        from presidio_analyzer import AnalyzerEngine
        from presidio_anonymizer import AnonymizerEngine

        analyzer = AnalyzerEngine()
        anonymizer = AnonymizerEngine()

        # Analyze with built-in entities
        results = analyzer.analyze(
            text=text, entities=["IP_ADDRESS", "EMAIL_ADDRESS"], language="en"
        )

        # Add custom MAC address detection
        mac_pattern = re.compile(r"\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b")
        for match in mac_pattern.finditer(text):
            results.append(
                {
                    "start": match.start(),
                    "end": match.end(),
                    "entity_type": "MAC_ADDRESS",
                    "score": 1.0,
                }
            )

        return anonymizer.anonymize(text=text, analyzer_results=results).text

    # Regex fallback
    text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "[REDACTED_IP]", text)
    text = re.sub(
        r"\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b", "[REDACTED_MAC]", text
    )
    text = re.sub(
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b", "[REDACTED_EMAIL]", text
    )
    return text
