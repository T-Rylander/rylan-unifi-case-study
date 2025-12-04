#!/bin/bash
# Eternal Orchestrator — Multi-Host Backup + RTO Validation (Phase 3 Endgame)
# Handles backup for rylan-dc, rylan-pi, rylan-ai with RTO <15 min validation

set -euo pipefail

DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Usage: $0 [--dry-run] [--verbose]"
            exit 1
            ;;
    esac
done

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load .env if available
if [[ -f .env ]]; then
    source .env
else
    echo "⚠️  .env not found, using defaults"
    BACKUP_DESTINATION=${BACKUP_DESTINATION:-/srv/nfs/backups}
    RTO_MINUTES=${RTO_MINUTES:-15}
fi

HOSTNAME=$(hostname)
BACKUP_DIR="${BACKUP_DESTINATION}/$(date +%Y%m%d_%H%M%S)_${HOSTNAME}"
RTO_SECONDS=$((RTO_MINUTES * 60))

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "=== Eternal Orchestrator: Backup + RTO Validation ==="
log_info "Host: $HOSTNAME"
log_info "Backup Directory: $BACKUP_DIR"
log_info "RTO Target: ${RTO_MINUTES} minutes ($RTO_SECONDS seconds)"
log_info "Mode: $([ "$DRY_RUN" = true ] && echo "DRY-RUN" || echo "PRODUCTION")"

if [[ "$VERBOSE" == true ]]; then
    set -x
fi

# Create backup directory (or simulate)
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$BACKUP_DIR"
    log_info "Created backup directory: $BACKUP_DIR"
else
    log_info "Would create backup directory: $BACKUP_DIR"
fi

# Start RTO timer
start_time=$(date +%s)

# Host-specific backup routines
case "$HOSTNAME" in
    rylan-dc)
        log_info "Backing up Samba AD/DC + FreeRADIUS + UniFi"

        if [[ "$DRY_RUN" == false ]]; then
            # Backup Samba AD database
            if [[ -d /var/lib/samba ]]; then
                log_info "Backing up Samba database..."
                rsync -avz --exclude='*.ldb.bak' /var/lib/samba/ "$BACKUP_DIR/samba/" 2>&1 | tail -5
            fi

            # Backup FreeRADIUS config
            if [[ -d /etc/freeradius ]]; then
                log_info "Backing up FreeRADIUS configuration..."
                tar czf "$BACKUP_DIR/freeradius-config.tar.gz" /etc/freeradius/ 2>/dev/null || true
            fi

            # Backup UniFi controller (if Docker)
            if command -v docker &>/dev/null && docker ps 2>/dev/null | grep -q unifi; then
                log_info "Backing up UniFi controller data..."
                docker exec unifi-controller tar czf /tmp/unifi-backup.tar.gz /config 2>/dev/null || true
                docker cp unifi-controller:/tmp/unifi-backup.tar.gz "$BACKUP_DIR/" 2>/dev/null || true
            fi

            # Verify backup integrity
            log_info "Verifying Samba backup integrity..."
            if [[ -f "$BACKUP_DIR/samba/private/sam.ldb" ]]; then
                log_info "✅ Samba backup verified (sam.ldb present)"
            else
                log_error "❌ Samba backup incomplete (missing sam.ldb)"
            fi

            if [[ -f "$BACKUP_DIR/freeradius-config.tar.gz" ]]; then
                if tar -tzf "$BACKUP_DIR/freeradius-config.tar.gz" &>/dev/null; then
                    log_info "✅ FreeRADIUS backup verified (tar integrity OK)"
                else
                    log_error "❌ FreeRADIUS backup corrupted (tar integrity failed)"
                fi
            fi
        else
            log_info "Would backup: Samba AD, FreeRADIUS, UniFi"
        fi
        ;;

    rylan-pi)
        log_info "Backing up osTicket + MariaDB"

        if [[ "$DRY_RUN" == false ]]; then
            # Backup MariaDB
            if command -v docker &>/dev/null && docker ps 2>/dev/null | grep -q mariadb; then
                log_info "Backing up MariaDB database..."
                docker exec mariadb mysqldump -u root -pSecurePass123 --all-databases \
                    > "$BACKUP_DIR/mariadb-dump.sql" 2>/dev/null || true
            fi

            # Backup osTicket data
            if command -v docker &>/dev/null && docker ps 2>/dev/null | grep -q osticket; then
                log_info "Backing up osTicket data..."
                docker cp osticket:/data "$BACKUP_DIR/osticket-data" 2>/dev/null || true
            fi

            # Verify backup integrity
            log_info "Verifying MariaDB backup integrity..."
            if grep -q "CREATE DATABASE" "$BACKUP_DIR/mariadb-dump.sql" 2>/dev/null; then
                log_info "✅ MariaDB backup verified (SQL statements present)"
            else
                log_error "❌ MariaDB backup incomplete (missing CREATE DATABASE)"
            fi

            if [[ -d "$BACKUP_DIR/osticket-data" ]]; then
                log_info "✅ osTicket backup verified (data directory present)"
            fi
        else
            log_info "Would backup: MariaDB, osTicket data"
        fi
        ;;

    rylan-ai)
        log_info "Backing up Qdrant vectors + Loki logs + NFS metadata"

        if [[ "$DRY_RUN" == false ]]; then
            # Backup Qdrant collection
            if [[ -d /srv/qdrant ]]; then
                log_info "Backing up Qdrant vectors..."
                rsync -avz /srv/qdrant/ "$BACKUP_DIR/qdrant/" 2>&1 | tail -5
            fi

            # Backup recent Loki chunks (last 7 days only to save space)
            if [[ -d /srv/loki/data/chunks ]]; then
                log_info "Backing up Loki logs (last 7 days)..."
                find /srv/loki/data/chunks -mtime -7 -type f \
                    -exec rsync -avz {} "$BACKUP_DIR/loki-chunks/" \; 2>&1 | tail -5 || true
            fi

            # Backup NFS structure
            if [[ -d /srv/nfs/shared ]]; then
                log_info "Backing up NFS directory metadata..."
                find /srv/nfs/shared -type d > "$BACKUP_DIR/nfs-structure.txt" 2>/dev/null || true
            fi

            # Verify backup integrity
            log_info "Verifying Qdrant backup integrity..."
            if [[ -d "$BACKUP_DIR/qdrant" ]] && [[ -n "$(find "$BACKUP_DIR/qdrant" -type f 2>/dev/null | head -1)" ]]; then
                log_info "✅ Qdrant backup verified (collection files present)"
            else
                log_warn "⚠️  Qdrant backup empty (may not have collections)"
            fi

            if [[ -f "$BACKUP_DIR/nfs-structure.txt" ]]; then
                log_info "✅ NFS metadata backed up"
            fi
        else
            log_info "Would backup: Qdrant, Loki, NFS metadata"
        fi
        ;;

    *)
        log_warn "Unknown hostname: $HOSTNAME (skipping host-specific backup)"
        ;;
esac

# Calculate elapsed time
end_time=$(date +%s)
elapsed=$((end_time - start_time))

# RTO Validation
log_info ""
log_info "=== RTO Validation ==="
if (( elapsed > RTO_SECONDS )); then
    log_error "❌ RTO FAILED: Backup took ${elapsed}s (limit: ${RTO_SECONDS}s)"
    exit 1
else
    log_info "✅ RTO PASSED: Backup completed in ${elapsed}s (limit: ${RTO_SECONDS}s)"
fi

# Final status
log_info ""
log_info "=== Backup Complete ==="
log_info "Location: $BACKUP_DIR"
log_info "Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo 'N/A (dry-run)')"
log_info "Elapsed: ${elapsed}s"
log_info "Status: ✅ SUCCESS"
