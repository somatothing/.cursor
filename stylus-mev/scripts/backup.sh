#!/bin/bash

# MEV System Backup Script
# Automated backup solution for database, configuration, and critical data

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="${PROJECT_ROOT}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
COMPRESSION_LEVEL=${COMPRESSION_LEVEL:-6}

# Backup destinations
DB_BACKUP_DIR="${BACKUP_ROOT}/database"
CONFIG_BACKUP_DIR="${BACKUP_ROOT}/config"
LOGS_BACKUP_DIR="${BACKUP_ROOT}/logs"
FULL_BACKUP_DIR="${BACKUP_ROOT}/full"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${PROJECT_ROOT}/logs/backup-${TIMESTAMP}.log"

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Create backup directories
create_backup_dirs() {
    log "INFO" "Creating backup directories..."
    mkdir -p "$DB_BACKUP_DIR" "$CONFIG_BACKUP_DIR" "$LOGS_BACKUP_DIR" "$FULL_BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
}

# Database backup functions
backup_postgresql() {
    log "INFO" "Starting PostgreSQL backup..."
    
    local backup_file="${DB_BACKUP_DIR}/postgres_${TIMESTAMP}.sql.gz"
    
    if docker exec mev-postgres pg_isready -U mev_user -d mev_analytics >/dev/null 2>&1; then
        # Create compressed database dump
        docker exec mev-postgres pg_dump -U mev_user -d mev_analytics --verbose --clean --no-owner --no-privileges | gzip -${COMPRESSION_LEVEL} > "$backup_file"
        
        local backup_size=$(du -h "$backup_file" | cut -f1)
        log "INFO" "PostgreSQL backup completed: ${backup_file} (${backup_size})"
        echo -e "${GREEN}✅ PostgreSQL backup: ${backup_size}${NC}"
        
        # Verify backup integrity
        if gzip -t "$backup_file" 2>/dev/null; then
            log "INFO" "PostgreSQL backup integrity verified"
        else
            log "ERROR" "PostgreSQL backup integrity check failed"
            echo -e "${RED}❌ PostgreSQL backup integrity check failed${NC}"
            return 1
        fi
        
        # Export analytics views separately
        local analytics_file="${DB_BACKUP_DIR}/analytics_views_${TIMESTAMP}.sql.gz"
        docker exec mev-postgres psql -U mev_user -d mev_analytics -c "
            \copy (SELECT * FROM analytics.daily_performance) TO STDOUT WITH CSV HEADER;
            \copy (SELECT * FROM analytics.strategy_performance) TO STDOUT WITH CSV HEADER;
            \copy (SELECT * FROM compliance.daily_summary) TO STDOUT WITH CSV HEADER;
        " | gzip -${COMPRESSION_LEVEL} > "$analytics_file"
        
        log "INFO" "Analytics views exported: ${analytics_file}"
        
    else
        log "ERROR" "PostgreSQL is not accessible for backup"
        echo -e "${RED}❌ PostgreSQL backup failed - database not accessible${NC}"
        return 1
    fi
}

backup_redis() {
    log "INFO" "Starting Redis backup..."
    
    local backup_file="${DB_BACKUP_DIR}/redis_${TIMESTAMP}.rdb.gz"
    
    if docker exec mev-redis redis-cli ping >/dev/null 2>&1; then
        # Force Redis to save current state
        docker exec mev-redis redis-cli BGSAVE
        
        # Wait for background save to complete
        while [ "$(docker exec mev-redis redis-cli LASTSAVE)" = "$(docker exec mev-redis redis-cli LASTSAVE)" ]; do
            sleep 1
        done
        
        # Copy and compress Redis dump
        docker cp mev-redis:/data/dump.rdb - | gzip -${COMPRESSION_LEVEL} > "$backup_file"
        
        local backup_size=$(du -h "$backup_file" | cut -f1)
        log "INFO" "Redis backup completed: ${backup_file} (${backup_size})"
        echo -e "${GREEN}✅ Redis backup: ${backup_size}${NC}"
        
    else
        log "ERROR" "Redis is not accessible for backup"
        echo -e "${RED}❌ Redis backup failed - service not accessible${NC}"
        return 1
    fi
}

# Configuration backup
backup_configurations() {
    log "INFO" "Starting configuration backup..."
    
    local config_archive="${CONFIG_BACKUP_DIR}/config_${TIMESTAMP}.tar.gz"
    
    # Create list of configuration files and directories
    local config_items=(
        "docker-compose.yml"
        ".env"
        ".env.example"
        "config/"
        "monitoring/"
        "scripts/"
        "sql/"
        "Dockerfile"
        "Cargo.toml"
        "Cargo.lock"
        "README.md"
        "deploy.sh"
    )
    
    # Create tar archive of configuration files
    cd "$PROJECT_ROOT"
    tar -czf "$config_archive" \
        --exclude='*.log' \
        --exclude='target/' \
        --exclude='backups/' \
        --exclude='logs/' \
        --exclude='.git/' \
        "${config_items[@]}" 2>/dev/null || true
    
    local backup_size=$(du -h "$config_archive" | cut -f1)
    log "INFO" "Configuration backup completed: ${config_archive} (${backup_size})"
    echo -e "${GREEN}✅ Configuration backup: ${backup_size}${NC}"
}

# Logs backup
backup_logs() {
    log "INFO" "Starting logs backup..."
    
    local logs_archive="${LOGS_BACKUP_DIR}/logs_${TIMESTAMP}.tar.gz"
    
    if [ -d "${PROJECT_ROOT}/logs" ] && [ "$(ls -A "${PROJECT_ROOT}/logs" 2>/dev/null)" ]; then
        # Archive logs older than 1 day
        find "${PROJECT_ROOT}/logs" -name "*.log" -mtime +1 -print0 | \
        tar -czf "$logs_archive" --null -T - 2>/dev/null || true
        
        if [ -f "$logs_archive" ]; then
            local backup_size=$(du -h "$logs_archive" | cut -f1)
            log "INFO" "Logs backup completed: ${logs_archive} (${backup_size})"
            echo -e "${GREEN}✅ Logs backup: ${backup_size}${NC}"
            
            # Clean up archived logs
            find "${PROJECT_ROOT}/logs" -name "*.log" -mtime +7 -delete
            log "INFO" "Old log files cleaned up"
        else
            log "INFO" "No logs to backup"
            echo -e "${YELLOW}⚠️  No logs to backup${NC}"
        fi
    else
        log "INFO" "Logs directory is empty or doesn't exist"
        echo -e "${YELLOW}⚠️  No logs directory found${NC}"
    fi
}

# Smart contract and WASM backup
backup_contracts() {
    log "INFO" "Starting contract artifacts backup..."
    
    local contracts_archive="${BACKUP_ROOT}/contracts_${TIMESTAMP}.tar.gz"
    
    if [ -d "${PROJECT_ROOT}/target" ]; then
        cd "$PROJECT_ROOT"
        tar -czf "$contracts_archive" \
            --exclude='target/debug/' \
            --exclude='target/doc/' \
            --exclude='target/.rustc_info.json' \
            target/wasm32-unknown-unknown/release/*.wasm \
            src/ 2>/dev/null || true
        
        if [ -f "$contracts_archive" ]; then
            local backup_size=$(du -h "$contracts_archive" | cut -f1)
            log "INFO" "Contract artifacts backup completed: ${contracts_archive} (${backup_size})"
            echo -e "${GREEN}✅ Contract artifacts backup: ${backup_size}${NC}"
        fi
    else
        log "INFO" "No contract artifacts to backup"
        echo -e "${YELLOW}⚠️  No contract artifacts found${NC}"
    fi
}

# Full system backup
create_full_backup() {
    log "INFO" "Creating full system backup..."
    
    local full_archive="${FULL_BACKUP_DIR}/full_backup_${TIMESTAMP}.tar.gz"
    
    # Create comprehensive backup excluding large/temporary files
    cd "$PROJECT_ROOT"
    tar -czf "$full_archive" \
        --exclude='target/debug/' \
        --exclude='target/doc/' \
        --exclude='backups/' \
        --exclude='logs/*.log' \
        --exclude='.git/' \
        --exclude='node_modules/' \
        --exclude='*.tmp' \
        --exclude='*.temp' \
        . 2>/dev/null || true
    
    local backup_size=$(du -h "$full_archive" | cut -f1)
    log "INFO" "Full backup completed: ${full_archive} (${backup_size})"
    echo -e "${GREEN}✅ Full system backup: ${backup_size}${NC}"
}

# Cleanup old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    local dirs=("$DB_BACKUP_DIR" "$CONFIG_BACKUP_DIR" "$LOGS_BACKUP_DIR" "$FULL_BACKUP_DIR")
    local total_cleaned=0
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local files_before=$(find "$dir" -type f | wc -l)
            find "$dir" -type f -mtime +${RETENTION_DAYS} -delete
            local files_after=$(find "$dir" -type f | wc -l)
            local cleaned=$((files_before - files_after))
            total_cleaned=$((total_cleaned + cleaned))
            
            if [ $cleaned -gt 0 ]; then
                log "INFO" "Cleaned up ${cleaned} old backup files from $(basename "$dir")"
            fi
        fi
    done
    
    if [ $total_cleaned -gt 0 ]; then
        echo -e "${GREEN}✅ Cleaned up ${total_cleaned} old backup files${NC}"
    else
        echo -e "${BLUE}ℹ️  No old backup files to clean up${NC}"
    fi
}

# Backup verification
verify_backups() {
    log "INFO" "Verifying backup integrity..."
    
    local verification_failed=0
    
    # Verify compressed files
    for backup_file in $(find "$BACKUP_ROOT" -name "*.gz" -mtime -1); do
        if ! gzip -t "$backup_file" 2>/dev/null; then
            log "ERROR" "Backup verification failed: $backup_file"
            echo -e "${RED}❌ Verification failed: $(basename "$backup_file")${NC}"
            verification_failed=1
        fi
    done
    
    # Verify tar archives
    for backup_file in $(find "$BACKUP_ROOT" -name "*.tar.gz" -mtime -1); do
        if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
            log "ERROR" "Archive verification failed: $backup_file"
            echo -e "${RED}❌ Archive verification failed: $(basename "$backup_file")${NC}"
            verification_failed=1
        fi
    done
    
    if [ $verification_failed -eq 0 ]; then
        echo -e "${GREEN}✅ All backups verified successfully${NC}"
    else
        echo -e "${RED}❌ Some backup verifications failed${NC}"
        return 1
    fi
}

# Generate backup report
generate_backup_report() {
    log "INFO" "Generating backup report..."
    
    local report_file="${BACKUP_ROOT}/backup_report_${TIMESTAMP}.txt"
    local total_size=$(du -sh "$BACKUP_ROOT" | cut -f1)
    
    cat > "$report_file" << EOF
====================================
MEV SYSTEM BACKUP REPORT
====================================
Backup Date: $(date '+%Y-%m-%d %H:%M:%S UTC')
Total Backup Size: ${total_size}

BACKUP CONTENTS:
$(find "$BACKUP_ROOT" -name "*${TIMESTAMP}*" -type f -exec ls -lh {} \; | awk '{print $9 " - " $5}')

BACKUP LOCATIONS:
- Database: ${DB_BACKUP_DIR}
- Configuration: ${CONFIG_BACKUP_DIR}
- Logs: ${LOGS_BACKUP_DIR}
- Full System: ${FULL_BACKUP_DIR}

RETENTION POLICY:
- Retention Period: ${RETENTION_DAYS} days
- Compression Level: ${COMPRESSION_LEVEL}

VERIFICATION STATUS:
$(verify_backups 2>&1 | grep -E "✅|❌" || echo "Verification pending...")

====================================
EOF

    echo -e "${BLUE}📋 Backup report generated: ${report_file}${NC}"
    log "INFO" "Backup report saved to: ${report_file}"
}

# Send backup notification (if configured)
send_notification() {
    if [ -n "${BACKUP_NOTIFICATION_WEBHOOK:-}" ]; then
        local status="SUCCESS"
        local total_size=$(du -sh "$BACKUP_ROOT" | cut -f1)
        
        curl -X POST "$BACKUP_NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"text\": \"MEV System Backup Completed\",
                \"attachments\": [{
                    \"color\": \"good\",
                    \"fields\": [{
                        \"title\": \"Status\",
                        \"value\": \"${status}\",
                        \"short\": true
                    }, {
                        \"title\": \"Total Size\",
                        \"value\": \"${total_size}\",
                        \"short\": true
                    }, {
                        \"title\": \"Timestamp\",
                        \"value\": \"${TIMESTAMP}\",
                        \"short\": true
                    }]
                }]
            }" >/dev/null 2>&1 || log "WARN" "Failed to send backup notification"
    fi
}

# Main backup function
main() {
    echo -e "${BLUE}💾 Starting MEV System Backup...${NC}\n"
    
    local start_time=$(date +%s)
    
    # Create backup directories
    create_backup_dirs
    
    log "INFO" "Starting backup process at $(date)"
    
    # Perform backups
    backup_postgresql
    backup_redis
    backup_configurations
    backup_logs
    backup_contracts
    
    # Optional full backup (uncomment if needed)
    # create_full_backup
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Verify backups
    verify_backups
    
    # Generate report
    generate_backup_report
    
    # Send notification if configured
    send_notification
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "INFO" "Backup process completed in ${duration} seconds"
    echo -e "\n${GREEN}✅ Backup completed successfully in ${duration}s!${NC}"
    
    # Display summary
    echo -e "\n${BLUE}📊 Backup Summary:${NC}"
    echo -e "Total backup size: $(du -sh "$BACKUP_ROOT" | cut -f1)"
    echo -e "Backup location: ${BACKUP_ROOT}"
    echo -e "Retention period: ${RETENTION_DAYS} days"
}

# Run backup if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi