#!/usr/bin/env bash
# =============================================================================
# Agentic Server Platform — Snapshot & Restore Tool
# =============================================================================

set -e

ACTION="${1:-backup}"
BACKUP_DIR="${2:-/home/gavadala/backups/migration-$(date +%Y%m%d)}"

if [ "$ACTION" = "backup" ]; then
    echo "[+] Starting full backup to: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"

    echo "  1. Dumping Multica PostgreSQL..."
    docker exec $(docker ps -q -f name=postgres) pg_dump -U multica -d multica -F c -b -f /tmp/multica_dump.pgcustom
    docker cp $(docker ps -q -f name=postgres):/tmp/multica_dump.pgcustom "$BACKUP_DIR/multica_dump.pgcustom"
    docker exec $(docker ps -q -f name=postgres) rm -f /tmp/multica_dump.pgcustom

    echo "  2. Backing up ~/.multica configuration..."
    if [ -d "/home/gavadala/.multica" ]; then
        tar -czf "$BACKUP_DIR/multica_config_backup.tar.gz" -C /home/gavadala .multica
    fi

    echo "  3. Backing up OmniRoute state..."
    if [ -d "/home/gavadala/.omniroute" ]; then
        tar -czf "$BACKUP_DIR/omniroute_backup.tar.gz" -C /home/gavadala .omniroute
    fi

    echo "[✓] Backup completed successfully in $BACKUP_DIR"

elif [ "$ACTION" = "restore" ]; then
    echo "[+] Starting restore from: $BACKUP_DIR"
    
    if [ -f "$BACKUP_DIR/omniroute_backup.tar.gz" ]; then
        echo "  1. Restoring OmniRoute..."
        tar -xzf "$BACKUP_DIR/omniroute_backup.tar.gz" -C /home/gavadala/
    fi

    if [ -f "$BACKUP_DIR/multica_dump.pgcustom" ]; then
        echo "  2. Restoring PostgreSQL database..."
        PG_CONTAINER=$(docker ps -q -f name=postgres)
        docker cp "$BACKUP_DIR/multica_dump.pgcustom" ${PG_CONTAINER}:/tmp/multica_dump.pgcustom
        docker exec -i ${PG_CONTAINER} pg_restore -U multica -d multica --clean --if-exists -v /tmp/multica_dump.pgcustom || true
        docker exec ${PG_CONTAINER} rm -f /tmp/multica_dump.pgcustom
    fi

    if [ -f "$BACKUP_DIR/multica_config_backup.tar.gz" ]; then
        echo "  3. Restoring Multica config..."
        tar -xzf "$BACKUP_DIR/multica_config_backup.tar.gz" -C /home/gavadala/
    fi

    echo "[✓] Restore completed successfully!"
else
    echo "Usage: $0 [backup|restore] [optional_backup_dir]"
    exit 1
fi
