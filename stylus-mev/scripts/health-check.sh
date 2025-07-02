#!/bin/bash

# MEV System Health Check Script
# Comprehensive monitoring and diagnostics for Arbitrum MEV infrastructure

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_ROOT}/logs/health-check-$(date +%Y%m%d).log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
ALERT_THRESHOLD_LATENCY=1000
MIN_PROFIT_THRESHOLD=${MIN_PROFIT_THRESHOLD:-0.001}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Health check functions
check_system_resources() {
    log "INFO" "Checking system resources..."
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        log "WARN" "High CPU usage: ${cpu_usage}%"
        echo -e "${YELLOW}⚠️  CPU Usage: ${cpu_usage}%${NC}"
    else
        echo -e "${GREEN}✅ CPU Usage: ${cpu_usage}%${NC}"
    fi
    
    # Memory Usage
    local memory_info=$(free | grep Mem)
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_usage=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    if (( $(echo "$memory_usage > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        log "WARN" "High memory usage: ${memory_usage}%"
        echo -e "${YELLOW}⚠️  Memory Usage: ${memory_usage}%${NC}"
    else
        echo -e "${GREEN}✅ Memory Usage: ${memory_usage}%${NC}"
    fi
    
    # Disk Usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log "WARN" "High disk usage: ${disk_usage}%"
        echo -e "${YELLOW}⚠️  Disk Usage: ${disk_usage}%${NC}"
    else
        echo -e "${GREEN}✅ Disk Usage: ${disk_usage}%${NC}"
    fi
}

check_docker_services() {
    log "INFO" "Checking Docker services..."
    
    local services=("mev-bot" "postgres" "redis" "prometheus" "grafana" "analytics" "risk-manager" "compliance")
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "arbitrum-${service}\|mev-${service}"; then
            local status=$(docker inspect --format='{{.State.Status}}' "arbitrum-${service}" 2>/dev/null || docker inspect --format='{{.State.Status}}' "mev-${service}" 2>/dev/null)
            if [ "$status" = "running" ]; then
                echo -e "${GREEN}✅ ${service}: Running${NC}"
            else
                log "ERROR" "${service} is not running (status: ${status})"
                echo -e "${RED}❌ ${service}: ${status}${NC}"
            fi
        else
            log "ERROR" "${service} container not found"
            echo -e "${RED}❌ ${service}: Not found${NC}"
        fi
    done
}

check_database_health() {
    log "INFO" "Checking database health..."
    
    # PostgreSQL connection test
    if docker exec mev-postgres pg_isready -U mev_user -d mev_analytics >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL: Connected${NC}"
        
        # Check database size
        local db_size=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "SELECT pg_size_pretty(pg_database_size('mev_analytics'));" | xargs)
        log "INFO" "Database size: ${db_size}"
        echo -e "${BLUE}📊 Database size: ${db_size}${NC}"
        
        # Check recent transactions
        local recent_txs=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "SELECT COUNT(*) FROM mev.transactions WHERE created_at > NOW() - INTERVAL '1 hour';" | xargs)
        log "INFO" "Recent transactions (1h): ${recent_txs}"
        echo -e "${BLUE}📈 Recent transactions (1h): ${recent_txs}${NC}"
        
    else
        log "ERROR" "PostgreSQL connection failed"
        echo -e "${RED}❌ PostgreSQL: Connection failed${NC}"
    fi
    
    # Redis connection test
    if docker exec mev-redis redis-cli ping >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis: Connected${NC}"
        
        # Check Redis memory usage
        local redis_memory=$(docker exec mev-redis redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        log "INFO" "Redis memory usage: ${redis_memory}"
        echo -e "${BLUE}💾 Redis memory: ${redis_memory}${NC}"
    else
        log "ERROR" "Redis connection failed"
        echo -e "${RED}❌ Redis: Connection failed${NC}"
    fi
}

check_network_connectivity() {
    log "INFO" "Checking network connectivity..."
    
    # Arbitrum RPC endpoint
    if curl -s -f -m 10 "https://arb1.arbitrum.io/rpc" >/dev/null; then
        echo -e "${GREEN}✅ Arbitrum RPC: Reachable${NC}"
    else
        log "ERROR" "Arbitrum RPC endpoint unreachable"
        echo -e "${RED}❌ Arbitrum RPC: Unreachable${NC}"
    fi
    
    # Test latency to Arbitrum
    local latency=$(curl -o /dev/null -s -w "%{time_total}" "https://arb1.arbitrum.io/rpc" | awk '{print $1*1000}')
    if (( $(echo "$latency > $ALERT_THRESHOLD_LATENCY" | bc -l) )); then
        log "WARN" "High network latency: ${latency}ms"
        echo -e "${YELLOW}⚠️  Network latency: ${latency}ms${NC}"
    else
        echo -e "${GREEN}✅ Network latency: ${latency}ms${NC}"
    fi
}

check_mev_performance() {
    log "INFO" "Checking MEV performance metrics..."
    
    # Query recent performance from database
    if docker exec mev-postgres pg_isready -U mev_user -d mev_analytics >/dev/null 2>&1; then
        # Success rate (last 24h)
        local success_rate=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT ROUND(
                CASE WHEN COUNT(*) = 0 THEN 0 
                ELSE (COUNT(CASE WHEN success THEN 1 END)::NUMERIC / COUNT(*)::NUMERIC) * 100 
                END, 2
            ) FROM mev.transactions WHERE created_at > NOW() - INTERVAL '24 hours';" | xargs)
        
        if (( $(echo "$success_rate < 70" | bc -l) )); then
            log "WARN" "Low success rate: ${success_rate}%"
            echo -e "${YELLOW}⚠️  Success rate (24h): ${success_rate}%${NC}"
        else
            echo -e "${GREEN}✅ Success rate (24h): ${success_rate}%${NC}"
        fi
        
        # Total profit (last 24h)
        local total_profit=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT COALESCE(SUM(profit_wei), 0) FROM mev.transactions 
            WHERE created_at > NOW() - INTERVAL '24 hours' AND profit_wei > 0;" | xargs)
        
        local profit_eth=$(echo "scale=6; $total_profit / 1000000000000000000" | bc)
        log "INFO" "Total profit (24h): ${profit_eth} ETH"
        echo -e "${BLUE}💰 Total profit (24h): ${profit_eth} ETH${NC}"
        
        # Average execution time
        local avg_exec_time=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT ROUND(AVG(execution_time_ms), 2) FROM mev.transactions 
            WHERE created_at > NOW() - INTERVAL '24 hours' AND execution_time_ms IS NOT NULL;" | xargs)
        
        if [ "$avg_exec_time" != "" ] && (( $(echo "$avg_exec_time > 500" | bc -l) )); then
            log "WARN" "High average execution time: ${avg_exec_time}ms"
            echo -e "${YELLOW}⚠️  Avg execution time: ${avg_exec_time}ms${NC}"
        else
            echo -e "${GREEN}✅ Avg execution time: ${avg_exec_time}ms${NC}"
        fi
    fi
}

check_risk_metrics() {
    log "INFO" "Checking risk management metrics..."
    
    if docker exec mev-postgres pg_isready -U mev_user -d mev_analytics >/dev/null 2>&1; then
        # Current drawdown
        local current_drawdown=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT COALESCE(current_drawdown_bp, 0) FROM mev.daily_risk_metrics 
            ORDER BY date DESC LIMIT 1;" | xargs)
        
        if [ "$current_drawdown" -gt 1000 ]; then  # 10%
            log "WARN" "High drawdown: ${current_drawdown} basis points"
            echo -e "${YELLOW}⚠️  Current drawdown: $((current_drawdown/100))%${NC}"
        else
            echo -e "${GREEN}✅ Current drawdown: $((current_drawdown/100))%${NC}"
        fi
        
        # Check for open positions
        local open_positions=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT COUNT(*) FROM mev.positions WHERE status = 'open';" | xargs)
        
        log "INFO" "Open positions: ${open_positions}"
        echo -e "${BLUE}📊 Open positions: ${open_positions}${NC}"
    fi
}

check_compliance_status() {
    log "INFO" "Checking compliance status..."
    
    if docker exec mev-postgres pg_isready -U mev_user -d mev_analytics >/dev/null 2>&1; then
        # High-risk transactions (last 24h)
        local high_risk_txs=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT COUNT(*) FROM compliance.transaction_monitoring 
            WHERE created_at > NOW() - INTERVAL '24 hours' 
            AND suspicious_activity_score > 70;" | xargs)
        
        if [ "$high_risk_txs" -gt 0 ]; then
            log "WARN" "High-risk transactions detected: ${high_risk_txs}"
            echo -e "${YELLOW}⚠️  High-risk transactions (24h): ${high_risk_txs}${NC}"
        else
            echo -e "${GREEN}✅ High-risk transactions (24h): ${high_risk_txs}${NC}"
        fi
        
        # Flagged transactions
        local flagged_txs=$(docker exec mev-postgres psql -U mev_user -d mev_analytics -t -c "
            SELECT COUNT(*) FROM compliance.transaction_monitoring 
            WHERE created_at > NOW() - INTERVAL '24 hours' 
            AND regulatory_status = 'flagged';" | xargs)
        
        if [ "$flagged_txs" -gt 0 ]; then
            log "WARN" "Flagged transactions: ${flagged_txs}"
            echo -e "${YELLOW}⚠️  Flagged transactions (24h): ${flagged_txs}${NC}"
        else
            echo -e "${GREEN}✅ Flagged transactions (24h): ${flagged_txs}${NC}"
        fi
    fi
}

generate_summary_report() {
    log "INFO" "Generating summary report..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S UTC')
    local report_file="${PROJECT_ROOT}/logs/health-summary-$(date +%Y%m%d-%H%M).txt"
    
    cat > "$report_file" << EOF
====================================
MEV SYSTEM HEALTH SUMMARY REPORT
====================================
Generated: ${timestamp}

SYSTEM STATUS:
$(check_system_resources 2>/dev/null | grep -E "✅|⚠️|❌")

SERVICES STATUS:
$(check_docker_services 2>/dev/null | grep -E "✅|❌")

DATABASE STATUS:
$(check_database_health 2>/dev/null | grep -E "✅|❌|📊|📈|💾")

NETWORK STATUS:
$(check_network_connectivity 2>/dev/null | grep -E "✅|⚠️|❌")

MEV PERFORMANCE:
$(check_mev_performance 2>/dev/null | grep -E "✅|⚠️|💰|📊")

RISK METRICS:
$(check_risk_metrics 2>/dev/null | grep -E "✅|⚠️|📊")

COMPLIANCE STATUS:
$(check_compliance_status 2>/dev/null | grep -E "✅|⚠️")

====================================
Full logs available at: ${LOG_FILE}
====================================
EOF

    echo -e "\n${BLUE}📋 Summary report generated: ${report_file}${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🔍 Starting MEV System Health Check...${NC}\n"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "INFO" "Starting health check at $(date)"
    
    # Run all checks
    check_system_resources
    echo
    check_docker_services
    echo
    check_database_health
    echo
    check_network_connectivity
    echo
    check_mev_performance
    echo
    check_risk_metrics
    echo
    check_compliance_status
    echo
    
    # Generate summary
    generate_summary_report
    
    log "INFO" "Health check completed at $(date)"
    echo -e "\n${GREEN}✅ Health check completed successfully!${NC}"
}

# Run health check if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi