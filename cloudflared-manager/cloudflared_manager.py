#!/usr/bin/env python3
"""cloudflared_manager.py

Small CLI tool to manage ~/.cloudflared/config.yml

Features:
 - list ingress mappings
 - add mapping (hostname, service, optional path)
 - remove mapping by index or hostname
 - backup and restore config
 - validate config (basic checks)

This script is intentionally small and dependency-light. It requires PyYAML.
"""
import argparse
import shutil
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import re
import json
import subprocess

try:
    import yaml
except Exception:
    print("Missing dependency: pyyaml. Install with: pip install pyyaml", file=sys.stderr)
    raise


DEFAULT_CONFIG = Path.home() / ".cloudflared" / "config.yml"


def load_config(path: Path):
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def write_config(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)


def list_ingress(cfg):
    ingress = cfg.get("ingress") or []
    if not ingress:
        print("No ingress rules in config.")
        return
    for idx, rule in enumerate(ingress, start=1):
        hostname = rule.get("hostname", "<none>")
        path = rule.get("path", "<none>")
        service = rule.get("service", "<none>")
        print(f"[{idx}] hostname={hostname} path={path} service={service}")


def add_ingress(cfg, hostname, service, path_pattern=None):
    ingress = cfg.setdefault("ingress", [])
    new = {"service": service}
    if hostname:
        new["hostname"] = hostname
    if path_pattern:
        new["path"] = path_pattern
    ingress.append(new)
    return cfg


def remove_ingress(cfg, index=None, hostname=None):
    ingress = cfg.get("ingress") or []
    if index is not None:
        if index < 1 or index > len(ingress):
            raise IndexError("index out of range")
        ingress.pop(index - 1)
        return cfg
    if hostname:
        new_ingress = [r for r in ingress if r.get("hostname") != hostname]
        if len(new_ingress) == len(ingress):
            raise KeyError("hostname not found")
        cfg["ingress"] = new_ingress
        return cfg
    raise ValueError("either index or hostname must be provided")


def backup_config(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"config not found: {path}")
    ts = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    dest = path.with_suffix(path.suffix + f".bak.{ts}")
    shutil.copy2(path, dest)
    return dest


def restore_config(path: Path, backup_path: Path):
    if not backup_path.exists():
        raise FileNotFoundError("backup not found")
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(backup_path, path)
    return path


def validate_config(cfg, path: Path):
    errors = []
    if not cfg.get("tunnel"):
        errors.append("missing 'tunnel' field")
    cred = cfg.get("credentials-file")
    if not cred:
        errors.append("missing 'credentials-file' field")
    else:
        cred_path = Path(cred).expanduser()
        if not cred_path.exists():
            errors.append(f"credentials-file does not exist: {cred_path}")
    ingress = cfg.get("ingress", [])
    for i, rule in enumerate(ingress, start=1):
        if "service" not in rule:
            errors.append(f"ingress[{i}]: missing service")
        if "path" in rule:
            try:
                re.compile(rule["path"])
            except re.error as e:
                errors.append(f"ingress[{i}]: invalid path regex: {e}")
    return errors


def find_credentials_files(search_dir: Path = Path.home() / ".cloudflared"):
    """Return a list of credential file paths in the cloudflared directory.

    Looks for files with .json extension and common credential names.
    """
    out = []
    d = search_dir.expanduser()
    if not d.exists():
        return out
    for p in d.iterdir():
        if p.is_file() and p.suffix == ".json":
            out.append(p)
    # also try credentials in current directory as fallback
    for p in Path('.').iterdir():
        if p.is_file() and p.suffix == '.json' and p not in out:
            out.append(p)
    return sorted(out)


def read_tunnels_from_credentials(cred_path: Path):
    """Try to parse the credentials JSON and extract any tunnel IDs/names."""
    try:
        j = json.loads(cred_path.read_text(encoding='utf-8'))
    except Exception:
        return []
    # credentials created by cloudflared typically have a "TunnelID" or "tunnel" field
    candidates = []
    if isinstance(j, dict):
        for k in ("TunnelID", "tunnel", "Tunnel", "tunnel_id", "id"):
            v = j.get(k)
            if isinstance(v, str):
                candidates.append(v)
    # de-dup and return
    return sorted(set(candidates))


def prompt_choose(prompt: str, options: list):
    """Simple numbered prompt. Returns selected index or None."""
    if not options:
        return None
    print(prompt)
    for i, o in enumerate(options, start=1):
        print(f"  [{i}] {o}")
    print("  [0] Cancel")
    while True:
        choice = input("Select number: ").strip()
        if not choice.isdigit():
            print("Please enter a number")
            continue
        n = int(choice)
        if n == 0:
            return None
        if 1 <= n <= len(options):
            return options[n - 1]
        print("Out of range")


def run_cloudflared(args: list):
    """Run cloudflared with given args and return (returncode, stdout, stderr)."""
    cmd = ["cloudflared"] + args
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, text=True)
        return p.returncode, p.stdout, p.stderr
    except FileNotFoundError:
        return 127, "", "cloudflared not found in PATH"


def parse_args():
    p = argparse.ArgumentParser(description="Manage ~/.cloudflared/config.yml")
    p.add_argument("--config", "-c", type=Path, default=DEFAULT_CONFIG, help="Path to config.yml")
    sub = p.add_subparsers(dest="cmd")

    sub.add_parser("list", help="List ingress mappings")

    a_add = sub.add_parser("add", help="Add an ingress mapping")
    a_add.add_argument("--hostname", "-n", help="Hostname (optional)")
    a_add.add_argument("--service", "-s", required=True, help="Service (e.g. https://localhost:8000)")
    a_add.add_argument("--path", "-p", help="Path regex (optional)")

    a_rm = sub.add_parser("remove", help="Remove an ingress mapping")
    a_rm.add_argument("--index", "-i", type=int, help="1-based index from 'list'")
    a_rm.add_argument("--hostname", "-n", help="Remove by hostname")

    sub.add_parser("backup", help="Create a timestamped backup of the config")

    r_restore = sub.add_parser("restore", help="Restore a specific backup to active config")
    r_restore.add_argument("backup_path", type=Path, help="Backup file to restore from")

    sub.add_parser("generate", help="Generate a new config interactively")
    sub.add_parser("tunnel-list", help="List Cloudflare tunnels (requires cloudflared)")
    t_create = sub.add_parser("tunnel-create", help="Create a Cloudflare tunnel (requires cloudflared)")
    t_create.add_argument("--name", "-n", help="Tunnel name to create", required=True)

    sub.add_parser("validate", help="Basic validation of config fields and paths")

    return p.parse_args()


def main():
    args = parse_args()
    cfg_path: Path = args.config.expanduser()

    if args.cmd == "list":
        cfg = load_config(cfg_path)
        list_ingress(cfg)
        return

    if args.cmd == "add":
        cfg = load_config(cfg_path)
        cfg = add_ingress(cfg, args.hostname, args.service, args.path)
        write_config(cfg_path, cfg)
        print("ingress rule added")
        return

    if args.cmd == "remove":
        cfg = load_config(cfg_path)
        try:
            cfg = remove_ingress(cfg, index=args.index, hostname=args.hostname)
        except Exception as e:
            print(f"Error removing ingress: {e}", file=sys.stderr)
            sys.exit(2)
        write_config(cfg_path, cfg)
        print("ingress rule removed")
        return

    if args.cmd == "backup":
        try:
            dest = backup_config(cfg_path)
            print(f"backup created: {dest}")
        except Exception as e:
            print(f"Backup failed: {e}", file=sys.stderr)
            sys.exit(2)
        return

    if args.cmd == "restore":
        try:
            restored = restore_config(cfg_path, args.backup_path.expanduser())
            print(f"restored: {restored}")
        except Exception as e:
            print(f"Restore failed: {e}", file=sys.stderr)
            sys.exit(2)
        return

    if args.cmd == "generate":
        # interactive generation of a minimal config
        creds = find_credentials_files()
        chosen_cred = None
        if creds:
            chosen_cred = prompt_choose("Choose a credentials file:", [str(p) for p in creds])
        if not chosen_cred:
            # prompt for path
            t = input("Enter path to credentials JSON (or leave blank to skip): ").strip()
            if t:
                chosen_cred = t

        # attempt to detect tunnels
        detected_tunnels = []
        if chosen_cred:
            try:
                detected_tunnels = read_tunnels_from_credentials(Path(chosen_cred))
            except Exception:
                detected_tunnels = []

        chosen_tunnel = None
        if detected_tunnels:
            chosen_tunnel = prompt_choose("Detected tunnels in credentials, choose one:", detected_tunnels)
        if not chosen_tunnel:
            chosen_tunnel = input("Enter tunnel ID/name (or leave blank to create later): ").strip() or None

        # build config
        new_cfg = {}
        if chosen_tunnel:
            new_cfg["tunnel"] = chosen_tunnel
        if chosen_cred:
            new_cfg["credentials-file"] = str(Path(chosen_cred).expanduser())

        # default ingress sample
        new_cfg["ingress"] = [
            {"hostname": "example.com", "service": "http://localhost:8000"},
            {"service": "http_status:404"},
        ]

        write_config(cfg_path, new_cfg)
        print(f"Generated config at {cfg_path}")
        return

    if args.cmd == "tunnel-list":
        rc, out, err = run_cloudflared(["tunnel", "list", "--no-color"])
        if rc == 127:
            print(err, file=sys.stderr)
            sys.exit(4)
        if rc != 0:
            print(err or out, file=sys.stderr)
            sys.exit(rc)
        print(out)
        return

    if args.cmd == "tunnel-create":
        name = args.name
        rc, out, err = run_cloudflared(["tunnel", "create", name])
        if rc == 127:
            print(err, file=sys.stderr)
            sys.exit(4)
        if rc != 0:
            print(err or out, file=sys.stderr)
            sys.exit(rc)
        print(out)
        return

    if args.cmd == "validate":
        cfg = load_config(cfg_path)
        errors = validate_config(cfg, cfg_path)
        if not errors:
            print("OK: config looks valid (basic checks)")
            return
        print("Validation errors:")
        for e in errors:
            print(f" - {e}")
        sys.exit(3)

    print("No command specified. Use --help for usage.")


if __name__ == "__main__":
    main()
