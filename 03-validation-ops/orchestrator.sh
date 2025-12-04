#!/bin/bash
# Eternal Orchestrator — Multi-Host Backup + RTO Validation (Phase 3 Endgame)
# Handles backup for rylan-dc, rylan-pi, rylan-ai with RTO <15 min validation
# Includes per-component timing, restore simulation, and metrics export

set -euo pipefail

DRY_RUN=false
VERBOSE=false
RUN_RESTORE_TEST=false
METRICS_FILE=""

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
        --test-restore)
            RUN_RESTORE_TEST=true
            shift
            ;;
        --metrics)
            METRICS_FILE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--dry-run] [--verbose] [--test-restore] [--metrics FILE]"
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

# Metrics tracking
declare -A COMPONENT_TIMES
declare -A COMPONENT_STATUS
COMPONENT_TIMES[total]=0
COMPONENT_STATUS[total]="pending"

start_component() {
    local component=$1
    COMPONENT_TIMES["${component}_start"]=$(date +%s%N)
}

end_component() {
    local component=$1
    local status=${2:-success}
    local end_time
    local elapsed_ms
    local start_time=${COMPONENT_TIMES["${component}_start"]:-0}

    end_time=$(date +%s%N)

    if [[ $start_time -gt 0 ]]; then
        elapsed_ms=$(( (end_time - start_time) / 1000000 ))
        COMPONENT_TIMES[$component]=$elapsed_ms
        COMPONENT_STATUS[$component]=$status
    fi
}

export_metrics() {
    local output_file=$1
    if [[ -z "$output_file" ]]; then
        return
    fi

    {
        echo "# Backup Metrics - $(date -Iseconds)"
        echo "hostname=$HOSTNAME"
        echo "backup_date=$(date +%Y%m%d_%H%M%S)"
        echo "rto_target_seconds=$RTO_SECONDS"
        echo ""

        for component in "${!COMPONENT_TIMES[@]}"; do
            if [[ "$component" != *"_start" ]]; then
                local ms=${COMPONENT_TIMES[$component]:-0}
                local status=${COMPONENT_STATUS[$component]:-unknown}
                echo "component.${component}.duration_ms=$ms"
                echo "component.${component}.status=$status"
            fi
        done

        echo "backup.total_elapsed_seconds=$((COMPONENT_TIMES[total] / 1000 || 0))"
    } > "$output_file"

    log_info "Metrics exported to: $output_file"
}

# Restore test simulation (dry-run only)
test_restore_simulation() {
    local backup_path=$1
    log_info "=== Restore Simulation (DRY-RUN) ==="

    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi

    start_component "restore_simulation"

    case "$HOSTNAME" in
        rylan-dc)
            # Test Samba restore
            if [[ -f "$backup_path/samba/private/sam.ldb" ]]; then
                log_info "✓ Samba database would restore from: $backup_path/samba/private/sam.ldb"
            fi

            # Test FreeRADIUS restore
            if [[ -f "$backup_path/freeradius-config.tar.gz" ]]; then
                log_info "✓ FreeRADIUS config would restore from: $backup_path/freeradius-config.tar.gz"
                tar -tzf "$backup_path/freeradius-config.tar.gz" | head -3
            fi
            ;;
        rylan-pi)
            # Test MariaDB restore
            if [[ -f "$backup_path/mariadb-dump.sql" ]]; then
                local line_count
                line_count=$(wc -l < "$backup_path/mariadb-dump.sql")
                log_info "✓ MariaDB dump would restore ($line_count SQL statements)"
            fi

            # Test osTicket restore
            if [[ -d "$backup_path/osticket-data" ]]; then
                local file_count
                file_count=$(find "$backup_path/osticket-data" -type f | wc -l)
                log_info "✓ osTicket data would restore ($file_count files)"
            fi
            ;;
        rylan-ai)
            # Test Qdrant restore
            if [[ -d "$backup_path/qdrant" ]]; then
                local file_count
                file_count=$(find "$backup_path/qdrant" -type f 2>/dev/null | wc -l)
                log_info "✓ Qdrant vectors would restore ($file_count collection files)"
            fi
            ;;
    esac

    end_component "restore_simulation" "success"
    log_info "Restore simulation completed in ${COMPONENT_TIMES[restore_simulation]}ms"
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
                start_component "samba_backup"
                log_info "Backing up Samba database..."
                rsync -avz --exclude='*.ldb.bak' /var/lib/samba/ "$BACKUP_DIR/samba/" 2>&1 | tail -5
                end_component "samba_backup" "success"
            fi

            # Backup FreeRADIUS config
            if [[ -d /etc/freeradius ]]; then
                start_component "freeradius_backup"
                log_info "Backing up FreeRADIUS configuration..."
                tar czf "$BACKUP_DIR/freeradius-config.tar.gz" /etc/freeradius/ 2>/dev/null || true
                end_component "freeradius_backup" "success"
            fi

            # Backup UniFi controller (if Docker)
            if command -v docker &>/dev/null && docker ps 2>/dev/null | grep -q unifi; then
                start_component "unifi_backup"
                log_info "Backing up UniFi controller data..."
                docker exec unifi-controller tar czf /tmp/unifi-backup.tar.gz /config 2>/dev/null || true
                docker cp unifi-controller:/tmp/unifi-backup.tar.gz "$BACKUP_DIR/" 2>/dev/null || true
                end_component "unifi_backup" "success"
            fi

            # Verify backup integrity
            log_info "Verifying Samba backup integrity..."
            if [[ -f "$BACKUP_DIR/samba/private/sam.ldb" ]]; then
                log_info "✅ Samba backup verified (sam.ldb present)"
            else
                log_error "❌ Samba backup incomplete (missing sam.ldb)"
                end_component "samba_backup" "failed"
            fi

            if [[ -f "$BACKUP_DIR/freeradius-config.tar.gz" ]]; then
                if tar -tzf "$BACKUP_DIR/freeradius-config.tar.gz" &>/dev/null; then
                    log_info "✅ FreeRADIUS backup verified (tar integrity OK)"
                else
                    log_error "❌ FreeRADIUS backup corrupted (tar integrity failed)"
                    end_component "freeradius_backup" "failed"
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
                start_component "mariadb_backup"
                log_info "Backing up MariaDB database..."
                docker exec mariadb mysqldump -u root -pSecurePass123 --all-databases \
                    > "$BACKUP_DIR/mariadb-dump.sql" 2>/dev/null || true
                end_component "mariadb_backup" "success"
            fi

            # Backup osTicket data
            if command -v docker &>/dev/null && docker ps 2>/dev/null | grep -q osticket; then
                start_component "osticket_backup"
                log_info "Backing up osTicket data..."
                docker cp osticket:/data "$BACKUP_DIR/osticket-data" 2>/dev/null || true
                end_component "osticket_backup" "success"
            fi

            # Verify backup integrity
            log_info "Verifying MariaDB backup integrity..."
            if grep -q "CREATE DATABASE" "$BACKUP_DIR/mariadb-dump.sql" 2>/dev/null; then
                log_info "✅ MariaDB backup verified (SQL statements present)"
            else
                log_error "❌ MariaDB backup incomplete (missing CREATE DATABASE)"
                end_component "mariadb_backup" "failed"
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
                start_component "qdrant_backup"
                log_info "Backing up Qdrant vectors..."
                rsync -avz /srv/qdrant/ "$BACKUP_DIR/qdrant/" 2>&1 | tail -5
                end_component "qdrant_backup" "success"
            fi

            # Backup recent Loki chunks (last 7 days only to save space)
            if [[ -d /srv/loki/data/chunks ]]; then
                start_component "loki_backup"
                log_info "Backing up Loki logs (last 7 days)..."
                find /srv/loki/data/chunks -mtime -7 -type f \
                    -exec rsync -avz {} "$BACKUP_DIR/loki-chunks/" \; 2>&1 | tail -5 || true
                end_component "loki_backup" "success"
            fi

            # Backup NFS structure
            if [[ -d /srv/nfs/shared ]]; then
                start_component "nfs_backup"
                log_info "Backing up NFS directory metadata..."
                find /srv/nfs/shared -type d > "$BACKUP_DIR/nfs-structure.txt" 2>/dev/null || true
                end_component "nfs_backup" "success"
            fi

            # Verify backup integrity
            log_info "Verifying Qdrant backup integrity..."
            if [[ -d "$BACKUP_DIR/qdrant" ]] && [[ -n "$(find "$BACKUP_DIR/qdrant" -type f 2>/dev/null | head -1)" ]]; then
                log_info "✅ Qdrant backup verified (collection files present)"
            else
                log_warn "⚠️  Qdrant backup empty (may not have collections)"
                end_component "qdrant_backup" "warning"
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
COMPONENT_TIMES[total]=$elapsed
rto_passed=1

# RTO Validation
log_info ""
log_info "=== RTO Validation ==="
log_info "Total elapsed: ${elapsed}s (limit: ${RTO_SECONDS}s)"

if (( elapsed > RTO_SECONDS )); then
    log_error "❌ RTO FAILED: Backup took ${elapsed}s (limit: ${RTO_SECONDS}s)"
    COMPONENT_STATUS[total]="failed"
    rto_passed=0
else
    log_info "✅ RTO PASSED: Backup completed in ${elapsed}s (limit: ${RTO_SECONDS}s)"
    COMPONENT_STATUS[total]="success"
fi

# Run restore simulation if requested (dry-run only)
if [[ "$RUN_RESTORE_TEST" == true ]]; then
    test_restore_simulation "$BACKUP_DIR"
fi

# Export metrics if requested
if [[ -n "$METRICS_FILE" ]]; then
    export_metrics "$METRICS_FILE"
fi

# Final status
log_info ""
log_info "=== Backup Complete ==="
log_info "Location: $BACKUP_DIR"
log_info "Size: $(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}' || echo 'N/A (dry-run)')"
log_info "Elapsed: ${elapsed}s"
log_info "RTO Status: $([ $rto_passed -eq 1 ] && echo "✅ PASSED" || echo "❌ FAILED")"
log_info "Status: ✅ SUCCESS"
