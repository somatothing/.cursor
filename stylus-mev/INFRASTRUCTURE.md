# MEV Infrastructure Documentation

## Overview

This document provides comprehensive guidance for deploying, monitoring, and maintaining the Arbitrum MEV FlashSandwich system infrastructure. The system is designed for high-performance, regulatory-compliant MEV extraction on Arbitrum with enterprise-grade observability and risk management.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEV System Architecture                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   MEV Bot   │  │ Analytics   │  │ Risk Mgmt   │             │
│  │  (Stylus)   │  │  Service    │  │  Service    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                 │                 │                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Compliance  │  │ PostgreSQL  │  │    Redis    │             │
│  │  Service    │  │ Database    │  │   Cache     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                 │                 │                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Prometheus  │  │   Grafana   │  │  Jaeger     │             │
│  │  Metrics    │  │ Dashboard   │  │  Tracing    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker & Docker Compose v2.0+
- 32GB+ RAM recommended
- 500GB+ SSD storage
- Linux environment (Ubuntu 20.04+ recommended)
- Network access to Arbitrum RPC endpoints

### Initial Deployment

1. **Clone and Configure**
   ```bash
   git clone <repository>
   cd stylus-mev
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Deploy Infrastructure**
   ```bash
   ./deploy.sh --environment production --setup-infrastructure
   ```

3. **Verify Deployment**
   ```bash
   ./scripts/health-check.sh
   ```

## Component Details

### Core MEV System

#### MEV Bot (Stylus Contract)
- **Technology**: Rust compiled to WASM via Arbitrum Stylus
- **Performance**: 10-100x gas savings vs Solidity
- **Execution Time**: <250ms target
- **Strategies**: Flash sandwich, arbitrage, liquidation

#### Analytics Service
- **Port**: 8081
- **Function**: Real-time performance analysis
- **Database**: PostgreSQL with optimized schemas
- **Metrics**: Profit tracking, success rates, execution times

#### Risk Management Service
- **Port**: 8082
- **Function**: Real-time risk monitoring and controls
- **Features**: Kelly Criterion sizing, VaR calculations, circuit breakers
- **Alerts**: Automated risk threshold notifications

#### Compliance Service
- **Port**: 8083
- **Function**: Regulatory compliance monitoring
- **Features**: Transaction screening, suspicious activity detection
- **Reporting**: Automated CTR/SAR generation

### Data Layer

#### PostgreSQL Database
- **Version**: 15-alpine
- **Schemas**: `mev`, `compliance`, `analytics`
- **Performance**: Optimized indexes for high-frequency data
- **Backup**: Automated with 30-day retention

#### Redis Cache
- **Version**: 7-alpine
- **Function**: Real-time data caching and session storage
- **Performance**: Sub-millisecond access times
- **Persistence**: AOF enabled for durability

### Monitoring Stack

#### Prometheus
- **Port**: 9091
- **Function**: Metrics collection and alerting
- **Retention**: 30 days, 50GB limit
- **Targets**: All services, system metrics, external APIs

#### Grafana
- **Port**: 3000
- **Function**: Visualization and dashboards
- **Dashboards**: MEV performance, system health, compliance
- **Alerts**: Integrated with AlertManager

#### Jaeger
- **Port**: 16686
- **Function**: Distributed tracing
- **Sampling**: 10% for performance optimization
- **Integration**: Full request lifecycle tracking

#### AlertManager
- **Port**: 9093
- **Function**: Alert routing and notification
- **Channels**: Email, Slack, PagerDuty
- **Escalation**: Severity-based routing

## Configuration Management

### Environment Variables

Critical environment variables that must be configured:

```bash
# Core Configuration
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
PRIVATE_KEY=<encrypted_private_key>
POSTGRES_PASSWORD=<secure_password>
REDIS_PASSWORD=<secure_password>

# Risk Management
MAX_POSITION_SIZE=50
RISK_TOLERANCE=conservative
MIN_PROFIT_THRESHOLD=0.001

# Monitoring
GRAFANA_PASSWORD=<secure_password>
SLACK_WEBHOOK_URL=<webhook_url>
PAGERDUTY_ROUTING_KEY=<routing_key>

# Compliance
COMPLIANCE_LEVEL=strict
ENABLE_ADDRESS_SCREENING=true
```

### Configuration Files

- `config/production.toml`: Main application configuration
- `monitoring/prometheus.yml`: Metrics collection rules
- `monitoring/alertmanager.yml`: Alert routing configuration
- `docker-compose.yml`: Service orchestration

## Deployment Procedures

### Production Deployment

1. **Infrastructure Setup**
   ```bash
   # Create production environment
   ./deploy.sh --environment production --setup-infrastructure
   
   # Verify all services
   docker-compose ps
   ```

2. **Database Initialization**
   ```bash
   # Database will be automatically initialized via init.sql
   # Verify schema creation
   docker exec mev-postgres psql -U mev_user -d mev_analytics -c "\dt mev.*"
   ```

3. **Contract Deployment**
   ```bash
   # Build and deploy Stylus contracts
   cargo stylus deploy --private-key $PRIVATE_KEY
   ```

4. **Health Verification**
   ```bash
   ./scripts/health-check.sh
   ```

### Rolling Updates

For zero-downtime updates:

1. **Prepare New Version**
   ```bash
   git pull origin main
   docker-compose build
   ```

2. **Rolling Update**
   ```bash
   docker-compose up -d --no-deps mev-bot
   docker-compose up -d --no-deps analytics
   docker-compose up -d --no-deps risk-manager
   ```

3. **Verify Update**
   ```bash
   ./scripts/health-check.sh
   ```

## Monitoring and Alerting

### Key Metrics

#### MEV Performance
- **Profit Rate**: ETH/hour profit generation
- **Success Rate**: Percentage of successful transactions
- **Execution Time**: Average transaction execution time
- **Gas Efficiency**: Profit per gas unit consumed

#### Risk Metrics
- **Current Drawdown**: Portfolio decline from peak
- **VaR 95%**: Value at Risk at 95% confidence
- **Position Concentration**: Largest position as % of portfolio
- **Sharpe Ratio**: Risk-adjusted returns

#### System Health
- **CPU Usage**: System CPU utilization
- **Memory Usage**: RAM consumption
- **Disk Usage**: Storage utilization
- **Network Latency**: RPC endpoint response times

### Alert Thresholds

#### Critical Alerts (Immediate Response)
- System down/unreachable
- Database connection failures
- Drawdown >10%
- Compliance violations

#### Warning Alerts (Monitor Closely)
- Success rate <70%
- High execution times >500ms
- Resource usage >80%
- Network latency >1s

### Dashboard Access

- **Grafana**: http://localhost:3000
  - Username: admin
  - Password: Set via `GRAFANA_PASSWORD`

- **Prometheus**: http://localhost:9091
- **Jaeger**: http://localhost:16686
- **AlertManager**: http://localhost:9093

## Backup and Recovery

### Automated Backups

The system includes automated backup procedures:

```bash
# Manual backup execution
./scripts/backup.sh

# Automated via cron (recommended)
0 */6 * * * /path/to/stylus-mev/scripts/backup.sh
```

### Backup Components

1. **Database**: Complete PostgreSQL dump with compression
2. **Configuration**: All config files and environment settings
3. **Logs**: Historical log files with rotation
4. **Contracts**: WASM artifacts and source code

### Recovery Procedures

1. **Database Recovery**
   ```bash
   # Stop services
   docker-compose down
   
   # Restore database
   gunzip -c backups/database/postgres_TIMESTAMP.sql.gz | \
   docker exec -i mev-postgres psql -U mev_user -d mev_analytics
   
   # Restart services
   docker-compose up -d
   ```

2. **Configuration Recovery**
   ```bash
   # Extract configuration backup
   tar -xzf backups/config/config_TIMESTAMP.tar.gz
   
   # Restart with restored config
   docker-compose up -d
   ```

## Security Considerations

### Access Control

- **Private Keys**: Encrypted storage with rotation
- **Database**: Role-based access with limited privileges
- **API Access**: Rate limiting and authentication
- **Network**: Firewall rules for essential ports only

### Audit Logging

All system activities are logged with:
- Transaction details and outcomes
- Risk management decisions
- Compliance screening results
- System access and configuration changes

### Compliance Features

- **Address Screening**: OFAC sanctions and PEP checks
- **Transaction Monitoring**: Suspicious activity detection
- **Reporting**: Automated CTR/SAR generation
- **Audit Trail**: 7-year retention for regulatory compliance

## Performance Optimization

### System Tuning

1. **Database Optimization**
   ```sql
   -- Optimize PostgreSQL for high-frequency inserts
   ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
   ALTER SYSTEM SET max_connections = 100;
   ALTER SYSTEM SET shared_buffers = '4GB';
   ALTER SYSTEM SET effective_cache_size = '12GB';
   ```

2. **Redis Optimization**
   ```bash
   # Optimize Redis for low latency
   echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
   ```

3. **Network Optimization**
   ```bash
   # Optimize network for low latency
   echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
   echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
   ```

### Scaling Considerations

#### Horizontal Scaling
- Multiple MEV bot instances with load balancing
- Read replicas for analytics database
- Redis clustering for cache distribution

#### Vertical Scaling
- Increased CPU cores for parallel processing
- Additional RAM for larger cache sizes
- NVMe SSDs for faster database operations

## Troubleshooting

### Common Issues

#### High Memory Usage
```bash
# Check memory usage by service
docker stats

# Restart memory-intensive services
docker-compose restart mev-bot analytics
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
docker exec mev-postgres pg_isready -U mev_user

# View connection logs
docker logs mev-postgres | tail -50
```

#### Network Connectivity Problems
```bash
# Test RPC connectivity
curl -X POST https://arb1.arbitrum.io/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Log Analysis

#### Application Logs
```bash
# View MEV bot logs
docker logs mev-bot | grep ERROR

# View analytics service logs
docker logs mev-analytics | tail -100
```

#### System Logs
```bash
# View health check results
cat logs/health-check-$(date +%Y%m%d).log

# View backup logs
cat logs/backup-*.log | tail -50
```

## Maintenance Procedures

### Regular Maintenance

#### Daily
- Health check execution
- Performance metrics review
- Alert acknowledgment and resolution

#### Weekly
- Log rotation and cleanup
- Database maintenance and optimization
- Security patch review

#### Monthly
- Full system backup verification
- Performance tuning review
- Compliance report generation

### Emergency Procedures

#### Emergency Shutdown
```bash
# Immediate system shutdown
docker-compose down

# Emergency circuit breaker activation
curl -X POST http://localhost:8080/emergency/shutdown
```

#### Incident Response
1. Assess impact and severity
2. Activate emergency procedures if needed
3. Investigate root cause
4. Implement fixes
5. Document incident and lessons learned

## Contact and Support

### Team Responsibilities

- **MEV Team**: Strategy optimization, profit analysis
- **Risk Team**: Risk management, compliance monitoring
- **Operations Team**: Infrastructure maintenance, monitoring
- **Compliance Team**: Regulatory adherence, reporting

### Emergency Contacts

- **Critical Issues**: PagerDuty escalation
- **Compliance Issues**: compliance@arbitrum-mev.com
- **Infrastructure Issues**: ops@arbitrum-mev.com

### Documentation Updates

This documentation should be updated whenever:
- New features are deployed
- Configuration changes are made
- Procedures are modified
- Incidents require process updates

---

**Last Updated**: $(date)
**Version**: 1.0
**Maintained By**: Infrastructure Team