"""
mitmproxy addon: inject HTTP headers based on a host-to-headers mapping.

Reads credentials from ~/.config/proxy-creds/credentials.json:
{
  "api.example.com": {
    "Authorization": "Bearer real-token-here"
  },
  "mlflow.internal.com": {
    "Authorization": "Bearer mlflow-token"
  }
}

Usage:
  mitmdump -s inject_credentials.py
"""
import json
import logging
from pathlib import Path

from mitmproxy import http

logger = logging.getLogger(__name__)

MAPPING_FILE = Path.home() / ".config" / "proxy-creds" / "credentials.json"


class InjectCredentials:
    def __init__(self) -> None:
        if not MAPPING_FILE.exists():
            logger.warning("No credential mapping at %s — running in passthrough mode", MAPPING_FILE)
            self.mapping: dict[str, dict[str, str]] = {}
            return

        with open(MAPPING_FILE) as f:
            self.mapping = json.load(f)

        logger.info("Loaded credential mappings for %d host(s)", len(self.mapping))

    def request(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        if host in self.mapping:
            for header_name, header_value in self.mapping[host].items():
                flow.request.headers[header_name] = header_value


addons = [InjectCredentials()]
