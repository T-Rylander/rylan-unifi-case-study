import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
from typing import Dict


def get_authenticated_session() -> requests.Session:
    session = requests.Session()
    retry = Retry(total=3, backoff_factor=1, status_forcelist=[502, 503, 504])
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def load_credentials() -> Dict[str, str]:
    import yaml

    with open("shared/inventory.yaml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)
