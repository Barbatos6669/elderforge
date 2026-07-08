#!/usr/bin/env python3
"""Tiny HTTP status endpoint for the Elderforge playtest server.

This intentionally reports only public operational state. It does not know the
playtest code, player identities, SSH keys, or any private deployment details.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def is_udp_port_listening(port: int) -> bool:
    """Return true when a local process is listening on the Godot UDP port."""

    try:
        result = subprocess.run(
            ["ss", "-lun"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except Exception:
        return False

    if result.returncode != 0:
        return False

    markers = (f":{port} ", f":{port}\n")
    return any(marker in result.stdout for marker in markers)


class StatusHandler(BaseHTTPRequestHandler):
    server_version = "ElderforgeStatus/1.0"

    def log_message(self, fmt: str, *args: object) -> None:
        if self.server.log_requests:
            super().log_message(fmt, *args)

    def _send_json(self, status_code: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path not in ("/", "/status"):
            self._send_json(404, {"online": False, "message": "Not found"})
            return

        online = is_udp_port_listening(self.server.game_port)
        message = "Server is online." if online else "Server is offline."
        self._send_json(
            200,
            {
                "online": online,
                "server_name": self.server.realm_name,
                "game_port": self.server.game_port,
                "status_port": self.server.server_port,
                "checked_at_utc": utc_now(),
                "message": message,
            },
        )


class ElderforgeStatusServer(ThreadingHTTPServer):
    def __init__(
        self,
        server_address: tuple[str, int],
        request_handler_class: type[BaseHTTPRequestHandler],
        realm_name: str,
        game_port: int,
        log_requests: bool,
    ) -> None:
        super().__init__(server_address, request_handler_class)
        self.realm_name = realm_name
        self.game_port = game_port
        self.server_port = server_address[1]
        self.log_requests = log_requests


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve Elderforge playtest status as JSON.")
    parser.add_argument("--host", default="0.0.0.0", help="Address to bind.")
    parser.add_argument("--port", type=int, default=24567, help="HTTP status port.")
    parser.add_argument("--game-port", type=int, default=24566, help="Godot UDP game port.")
    parser.add_argument("--name", default="Elderforge Playtest", help="Public realm name.")
    parser.add_argument("--log", action="store_true", help="Log HTTP requests.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    server = ElderforgeStatusServer(
        (args.host, args.port),
        StatusHandler,
        realm_name=args.name,
        game_port=args.game_port,
        log_requests=args.log,
    )
    print(f"Serving {args.name} status on http://{args.host}:{args.port}/status", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
