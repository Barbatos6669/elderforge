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
from pathlib import Path


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


def parse_bool(value: object, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    if isinstance(value, (int, float)):
        return value != 0
    return default


def clean_text(value: object, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def load_metadata(path: str) -> dict[str, object]:
    if not path:
        return {}

    metadata_path = Path(path)
    if not metadata_path.exists():
        return {}

    try:
        with metadata_path.open("r", encoding="utf-8") as file:
            parsed = json.load(file)
    except Exception:
        return {}

    return parsed if isinstance(parsed, dict) else {}


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

        metadata = load_metadata(self.server.metadata_file)
        online = is_udp_port_listening(self.server.game_port)
        maintenance = parse_bool(metadata.get("maintenance"), self.server.maintenance)
        required_build_id = clean_text(
            metadata.get("required_build_id"),
            self.server.required_build_id,
        )
        required_commit = clean_text(
            metadata.get("required_commit"),
            self.server.required_commit,
        )
        minimum_client_build = clean_text(
            metadata.get("minimum_client_build"),
            required_build_id,
        )
        maintenance_message = clean_text(
            metadata.get("maintenance_message"),
            self.server.maintenance_message,
        )
        server_name = clean_text(metadata.get("server_name"), self.server.realm_name)
        default_accepting = online and not maintenance
        accepting_connections = online and not maintenance and parse_bool(
            metadata.get("accepting_connections"),
            default_accepting,
        )

        if maintenance:
            message = maintenance_message or "Server maintenance is active."
        elif online:
            message = clean_text(metadata.get("message"), "Server is online.")
        else:
            message = "Server is offline."

        self._send_json(
            200,
            {
                "online": online,
                "server_name": server_name,
                "game_port": self.server.game_port,
                "status_port": self.server.server_port,
                "checked_at_utc": utc_now(),
                "accepting_connections": accepting_connections,
                "maintenance": maintenance,
                "maintenance_message": maintenance_message,
                "required_build_id": required_build_id,
                "required_commit": required_commit,
                "minimum_client_build": minimum_client_build,
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
        metadata_file: str,
        maintenance: bool,
        maintenance_message: str,
        required_build_id: str,
        required_commit: str,
    ) -> None:
        super().__init__(server_address, request_handler_class)
        self.realm_name = realm_name
        self.game_port = game_port
        self.server_port = server_address[1]
        self.log_requests = log_requests
        self.metadata_file = metadata_file
        self.maintenance = maintenance
        self.maintenance_message = maintenance_message
        self.required_build_id = required_build_id
        self.required_commit = required_commit


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Serve Elderforge playtest status as JSON.")
    parser.add_argument("--host", default="0.0.0.0", help="Address to bind.")
    parser.add_argument("--port", type=int, default=24567, help="HTTP status port.")
    parser.add_argument("--game-port", type=int, default=24566, help="Godot UDP game port.")
    parser.add_argument("--name", default="Elderforge Playtest", help="Public realm name.")
    parser.add_argument("--metadata-file", default="", help="Optional JSON file with maintenance/build-gate state.")
    parser.add_argument("--maintenance", action="store_true", help="Report maintenance mode.")
    parser.add_argument("--maintenance-message", default="Server maintenance is active.", help="Public maintenance text.")
    parser.add_argument("--required-build-id", default="", help="Build id clients must run.")
    parser.add_argument("--required-commit", default="", help="Commit clients must run when no build id is set.")
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
        metadata_file=args.metadata_file,
        maintenance=args.maintenance,
        maintenance_message=args.maintenance_message,
        required_build_id=args.required_build_id,
        required_commit=args.required_commit,
    )
    print(f"Serving {args.name} status on http://{args.host}:{args.port}/status", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
