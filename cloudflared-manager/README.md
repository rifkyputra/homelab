cloudflared-manager

Small CLI to manage ~/.cloudflared/config.yml

Usage examples:

List ingress rules:

  python3 cloudflared_manager.py list

Add rule:

  python3 cloudflared_manager.py add -n example.com -s https://localhost:8000

Backup config:

  python3 cloudflared_manager.py backup

Validate:

  python3 cloudflared_manager.py validate

Generate a starter config (interactive):

  python3 cloudflared_manager.py generate

Install dependencies into a per-project virtualenv and run the CLI (recommended):

  ./install-and-run.sh generate

Notes:

- The script requires PyYAML. Use the included `requirements.txt` or run via `install-and-run.sh` which creates `.venv` and installs dependencies.
- `generate` will attempt to detect credential JSON files in `~/.cloudflared` and offer them for selection; it will also try to extract tunnel IDs from a chosen credential file. If detection fails you'll be prompted to enter a credential path and/or tunnel ID manually.
