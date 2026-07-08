# Server Status Endpoint

`elderforge_status_server.py` is the tiny HTTP endpoint used by the playtest
launcher. It returns public JSON at `/status` so testers can see whether the
Azure Godot server is listening.

Example:

```bash
python3 elderforge_status_server.py --game-port 24566 --port 24567 --name "Elderforge Azure Playtest"
```

The endpoint does not store or expose the playtest code, player names, SSH keys,
or deployment credentials.
