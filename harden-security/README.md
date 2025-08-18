harden-security

This directory contains small, atomic, idempotent hardening scripts for Linux.
Each change has a paired enable and disable script so changes can be reverted where possible.

Usage:
- List available scripts: ls -1 *.enable.sh
- Run a single enable script: sudo ./01-password-policy.enable.sh
- Undo a change: sudo ./01-password-policy.disable.sh
- Run all enables: sudo ./run-enable-all.sh
- Run all disables: sudo ./run-disable-all.sh

Notes:
- Some actions cannot be perfectly reverted (package upgrades, autoremove). Disable scripts will attempt best-effort undo and will record state/backups in /var/lib/harden-security and logs in /var/log/harden-security.
- All scripts are standalone; they source `lib/harden-lib.sh` for helpers.
