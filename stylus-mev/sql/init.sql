-- MEV Analytics Database Schema
-- Optimized for high-frequency transaction analysis and compliance reporting

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create schemas
CREATE SCHEMA IF NOT EXISTS mev;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Set search path
SET search_path TO mev, compliance, analytics, public;

-- =============================================
-- MEV CORE TABLES
-- =============================================

-- MEV Transactions table
CREATE TABLE mev.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tx_hash BYTEA NOT NULL,
    block_number BIGINT NOT NULL,
    block_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    strategy_type VARCHAR(50) NOT NULL CHECK (strategy_type IN ('flash_sandwich', 'arbitrage', 'liquidation', 'jit')),
    token_in BYTEA NOT NULL,
    token_out BYTEA NOT NULL,
    amount_in NUMERIC(78,0) NOT NULL,
    amount_out NUMERIC(78,0) NOT NULL,
    profit_wei NUMERIC(78,0) NOT NULL,
    profit_usd NUMERIC(18,6),
    gas_used BIGINT NOT NULL,
    gas_price NUMERIC(78,0) NOT NULL,
    gas_cost_wei NUMERIC(78,0) NOT NULL,
    execution_time_ms INTEGER,
    slippage_bp INTEGER,
    success BOOLEAN NOT NULL DEFAULT true,
    error_message TEXT,
    protocol_a BYTEA,
    protocol_b BYTEA,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Indexes
    CONSTRAINT unique_tx_hash UNIQUE (tx_hash)
);

-- Create indexes for performance
CREATE INDEX idx_transactions_block_number ON mev.transactions (block_number DESC);
CREATE INDEX idx_transactions_timestamp ON mev.transactions (block_timestamp DESC);
CREATE INDEX idx_transactions_strategy ON mev.transactions (strategy_type, block_timestamp DESC);
CREATE INDEX idx_transactions_profit ON mev.transactions (profit_wei DESC) WHERE profit_wei > 0;
CREATE INDEX idx_transactions_tokens ON mev.transactions USING GIN (token_in, token_out);

-- Flash Sandwich specific data
CREATE TABLE mev.flash_sandwiches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID NOT NULL REFERENCES mev.transactions(id),
    victim_tx_hash BYTEA NOT NULL,
    front_run_tx_hash BYTEA NOT NULL,
    back_run_tx_hash BYTEA NOT NULL,
    flash_loan_amount NUMERIC(78,0) NOT NULL,
    flash_loan_provider VARCHAR(50) NOT NULL,
    flash_loan_fee NUMERIC(78,0) NOT NULL,
    target_slippage_bp INTEGER NOT NULL,
    actual_slippage_bp INTEGER,
    sandwich_profit NUMERIC(78,0) NOT NULL,
    victim_loss NUMERIC(78,0),
    execution_sequence INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_flash_sandwiches_victim ON mev.flash_sandwiches (victim_tx_hash);
CREATE INDEX idx_flash_sandwiches_profit ON mev.flash_sandwiches (sandwich_profit DESC);

-- Arbitrage opportunities
CREATE TABLE mev.arbitrage_opportunities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID REFERENCES mev.transactions(id),
    protocol_a_address BYTEA NOT NULL,
    protocol_a_name VARCHAR(50) NOT NULL,
    protocol_b_address BYTEA NOT NULL,
    protocol_b_name VARCHAR(50) NOT NULL,
    token_pair VARCHAR(100) NOT NULL,
    price_difference_bp INTEGER NOT NULL,
    opportunity_size NUMERIC(78,0) NOT NULL,
    estimated_profit NUMERIC(78,0) NOT NULL,
    actual_profit NUMERIC(78,0),
    gas_cost NUMERIC(78,0) NOT NULL,
    confidence_score INTEGER CHECK (confidence_score BETWEEN 0 AND 100),
    execution_delay_ms INTEGER,
    expired_at TIMESTAMP WITH TIME ZONE,
    executed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_arbitrage_opportunities_profit ON mev.arbitrage_opportunities (estimated_profit DESC);
CREATE INDEX idx_arbitrage_opportunities_executed ON mev.arbitrage_opportunities (executed, created_at DESC);

-- =============================================
-- RISK MANAGEMENT TABLES
-- =============================================

-- Daily risk metrics
CREATE TABLE mev.daily_risk_metrics (
    date DATE PRIMARY KEY,
    total_transactions INTEGER NOT NULL DEFAULT 0,
    successful_transactions INTEGER NOT NULL DEFAULT 0,
    total_profit_wei NUMERIC(78,0) NOT NULL DEFAULT 0,
    total_loss_wei NUMERIC(78,0) NOT NULL DEFAULT 0,
    max_drawdown_bp INTEGER NOT NULL DEFAULT 0,
    current_drawdown_bp INTEGER NOT NULL DEFAULT 0,
    var_95_wei NUMERIC(78,0) NOT NULL DEFAULT 0,
    sharpe_ratio NUMERIC(10,4),
    win_rate_bp INTEGER NOT NULL DEFAULT 0,
    avg_profit_per_trade NUMERIC(78,0),
    gas_efficiency_ratio NUMERIC(10,4),
    portfolio_value_wei NUMERIC(78,0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Position tracking
CREATE TABLE mev.positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token_address BYTEA NOT NULL,
    token_symbol VARCHAR(20),
    position_size NUMERIC(78,0) NOT NULL,
    entry_price NUMERIC(78,0) NOT NULL,
    current_price NUMERIC(78,0),
    unrealized_pnl NUMERIC(78,0),
    position_type VARCHAR(20) CHECK (position_type IN ('long', 'short', 'neutral')),
    opened_at TIMESTAMP WITH TIME ZONE NOT NULL,
    closed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'closed', 'liquidated')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_positions_token ON mev.positions (token_address, status);
CREATE INDEX idx_positions_status ON mev.positions (status, opened_at DESC);

-- =============================================
-- COMPLIANCE TABLES
-- =============================================

-- Compliance monitoring
CREATE TABLE compliance.transaction_monitoring (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID REFERENCES mev.transactions(id),
    counterparty_address BYTEA NOT NULL,
    transaction_value_usd NUMERIC(18,6) NOT NULL,
    suspicious_activity_score INTEGER CHECK (suspicious_activity_score BETWEEN 0 AND 100),
    compliance_flags TEXT[],
    regulatory_status VARCHAR(50) DEFAULT 'pending' CHECK (regulatory_status IN ('pending', 'approved', 'flagged', 'blocked')),
    reviewed_by VARCHAR(100),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_compliance_monitoring_score ON compliance.transaction_monitoring (suspicious_activity_score DESC);
CREATE INDEX idx_compliance_monitoring_status ON compliance.transaction_monitoring (regulatory_status, created_at DESC);

-- Address whitelist/blacklist
CREATE TABLE compliance.address_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address BYTEA NOT NULL,
    list_type VARCHAR(20) NOT NULL CHECK (list_type IN ('whitelist', 'blacklist', 'watchlist')),
    reason TEXT,
    added_by VARCHAR(100) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_address_list_type UNIQUE (address, list_type)
);

CREATE INDEX idx_address_lists_address ON compliance.address_lists (address, list_type, active);

-- Regulatory reports
CREATE TABLE compliance.regulatory_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('CTR', 'SAR', 'AUDIT', 'DAILY')),
    report_period_start DATE NOT NULL,
    report_period_end DATE NOT NULL,
    total_transactions INTEGER NOT NULL,
    total_volume_usd NUMERIC(18,6) NOT NULL,
    flagged_transactions INTEGER NOT NULL DEFAULT 0,
    report_data JSONB NOT NULL,
    filed_with VARCHAR(100),
    filed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'filed', 'approved', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_regulatory_reports_type ON compliance.regulatory_reports (report_type, report_period_end DESC);

-- =============================================
-- ANALYTICS TABLES
-- =============================================

-- Protocol performance metrics
CREATE TABLE analytics.protocol_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    protocol_address BYTEA NOT NULL,
    protocol_name VARCHAR(50) NOT NULL,
    date DATE NOT NULL,
    total_volume NUMERIC(78,0) NOT NULL DEFAULT 0,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    avg_gas_cost NUMERIC(78,0),
    success_rate_bp INTEGER NOT NULL DEFAULT 0,
    avg_slippage_bp INTEGER,
    liquidity_score INTEGER CHECK (liquidity_score BETWEEN 0 AND 100),
    reliability_score INTEGER CHECK (reliability_score BETWEEN 0 AND 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_protocol_date UNIQUE (protocol_address, date)
);

CREATE INDEX idx_protocol_performance_date ON analytics.protocol_performance (date DESC, protocol_name);

-- Market conditions tracking
CREATE TABLE analytics.market_conditions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    gas_price_gwei NUMERIC(10,4) NOT NULL,
    block_utilization_bp INTEGER NOT NULL,
    mempool_size INTEGER NOT NULL,
    sequencer_latency_ms INTEGER NOT NULL,
    network_congestion_level INTEGER CHECK (network_congestion_level BETWEEN 1 AND 10),
    volatility_index NUMERIC(10,4),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_market_conditions_timestamp ON analytics.market_conditions (timestamp DESC);

-- Token pair analytics
CREATE TABLE analytics.token_pair_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    token_a BYTEA NOT NULL,
    token_b BYTEA NOT NULL,
    date DATE NOT NULL,
    total_arbitrage_volume NUMERIC(78,0) NOT NULL DEFAULT 0,
    avg_price_difference_bp INTEGER,
    max_price_difference_bp INTEGER,
    arbitrage_count INTEGER NOT NULL DEFAULT 0,
    total_profit NUMERIC(78,0) NOT NULL DEFAULT 0,
    liquidity_depth NUMERIC(78,0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_token_pair_date UNIQUE (token_a, token_b, date)
);

CREATE INDEX idx_token_pair_metrics_profit ON analytics.token_pair_metrics (total_profit DESC, date DESC);

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Function to update daily risk metrics
CREATE OR REPLACE FUNCTION mev.update_daily_risk_metrics()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO mev.daily_risk_metrics (
        date, 
        total_transactions, 
        successful_transactions, 
        total_profit_wei, 
        total_loss_wei
    )
    VALUES (
        DATE(NEW.block_timestamp),
        1,
        CASE WHEN NEW.success THEN 1 ELSE 0 END,
        CASE WHEN NEW.profit_wei > 0 THEN NEW.profit_wei ELSE 0 END,
        CASE WHEN NEW.profit_wei < 0 THEN ABS(NEW.profit_wei) ELSE 0 END
    )
    ON CONFLICT (date) DO UPDATE SET
        total_transactions = daily_risk_metrics.total_transactions + 1,
        successful_transactions = daily_risk_metrics.successful_transactions + 
            CASE WHEN NEW.success THEN 1 ELSE 0 END,
        total_profit_wei = daily_risk_metrics.total_profit_wei + 
            CASE WHEN NEW.profit_wei > 0 THEN NEW.profit_wei ELSE 0 END,
        total_loss_wei = daily_risk_metrics.total_loss_wei + 
            CASE WHEN NEW.profit_wei < 0 THEN ABS(NEW.profit_wei) ELSE 0 END,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for daily risk metrics
CREATE TRIGGER trigger_update_daily_risk_metrics
    AFTER INSERT ON mev.transactions
    FOR EACH ROW
    EXECUTE FUNCTION mev.update_daily_risk_metrics();

-- Function to calculate win rate
CREATE OR REPLACE FUNCTION analytics.calculate_win_rate(start_date DATE, end_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    total_trades INTEGER;
    winning_trades INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_trades
    FROM mev.transactions
    WHERE DATE(block_timestamp) BETWEEN start_date AND end_date;
    
    SELECT COUNT(*) INTO winning_trades
    FROM mev.transactions
    WHERE DATE(block_timestamp) BETWEEN start_date AND end_date
    AND profit_wei > 0;
    
    IF total_trades = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN (winning_trades::NUMERIC / total_trades::NUMERIC) * 10000; -- Return in basis points
END;
$$ LANGUAGE plpgsql;

-- Function to calculate Sharpe ratio
CREATE OR REPLACE FUNCTION analytics.calculate_sharpe_ratio(start_date DATE, end_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    avg_return NUMERIC;
    return_std NUMERIC;
    risk_free_rate NUMERIC := 0.02; -- 2% annual risk-free rate
BEGIN
    WITH daily_returns AS (
        SELECT 
            DATE(block_timestamp) as trade_date,
            SUM(profit_wei) as daily_profit
        FROM mev.transactions
        WHERE DATE(block_timestamp) BETWEEN start_date AND end_date
        GROUP BY DATE(block_timestamp)
    )
    SELECT 
        AVG(daily_profit),
        STDDEV(daily_profit)
    INTO avg_return, return_std
    FROM daily_returns;
    
    IF return_std = 0 OR return_std IS NULL THEN
        RETURN 0;
    END IF;
    
    RETURN (avg_return - (risk_free_rate / 365)) / return_std;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- VIEWS FOR REPORTING
-- =============================================

-- Daily performance summary
CREATE OR REPLACE VIEW analytics.daily_performance AS
SELECT 
    date,
    total_transactions,
    successful_transactions,
    ROUND((successful_transactions::NUMERIC / NULLIF(total_transactions, 0)) * 100, 2) as success_rate_pct,
    total_profit_wei,
    total_loss_wei,
    (total_profit_wei - total_loss_wei) as net_profit_wei,
    max_drawdown_bp / 100.0 as max_drawdown_pct,
    win_rate_bp / 100.0 as win_rate_pct,
    sharpe_ratio,
    avg_profit_per_trade
FROM mev.daily_risk_metrics
ORDER BY date DESC;

-- Top performing strategies
CREATE OR REPLACE VIEW analytics.strategy_performance AS
SELECT 
    strategy_type,
    COUNT(*) as total_trades,
    SUM(CASE WHEN profit_wei > 0 THEN 1 ELSE 0 END) as winning_trades,
    ROUND(AVG(CASE WHEN profit_wei > 0 THEN 1.0 ELSE 0.0 END) * 100, 2) as win_rate_pct,
    SUM(profit_wei) as total_profit_wei,
    AVG(profit_wei) as avg_profit_wei,
    MAX(profit_wei) as max_profit_wei,
    SUM(gas_cost_wei) as total_gas_cost_wei,
    AVG(execution_time_ms) as avg_execution_time_ms
FROM mev.transactions
WHERE block_timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY strategy_type
ORDER BY total_profit_wei DESC;

-- Compliance summary
CREATE OR REPLACE VIEW compliance.daily_summary AS
SELECT 
    DATE(tm.created_at) as date,
    COUNT(*) as total_monitored,
    COUNT(CASE WHEN tm.suspicious_activity_score > 70 THEN 1 END) as high_risk_transactions,
    COUNT(CASE WHEN tm.regulatory_status = 'flagged' THEN 1 END) as flagged_transactions,
    COUNT(CASE WHEN tm.regulatory_status = 'blocked' THEN 1 END) as blocked_transactions,
    AVG(tm.suspicious_activity_score) as avg_suspicion_score,
    SUM(tm.transaction_value_usd) as total_volume_usd
FROM compliance.transaction_monitoring tm
GROUP BY DATE(tm.created_at)
ORDER BY date DESC;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA mev TO mev_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA compliance TO mev_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO mev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA mev TO mev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA compliance TO mev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO mev_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA mev TO mev_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA analytics TO mev_user;

-- Create initial data
INSERT INTO compliance.address_lists (address, list_type, reason, added_by) VALUES
('\x0000000000000000000000000000000000000000'::bytea, 'blacklist', 'Null address', 'system'),
('\x000000000000000000000000000000000000dead'::bytea, 'blacklist', 'Burn address', 'system');

COMMIT;