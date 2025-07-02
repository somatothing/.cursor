//! Core types and data structures for the MEV FlashSandwich system

use stylus_sdk::{
    alloy_primitives::{Address, U256, Bytes},
    prelude::*,
};
use serde::{Serialize, Deserialize};

/// Main error types for MEV operations
#[derive(Debug, Clone, PartialEq)]
pub enum MEVError {
    /// Insufficient balance for operation
    InsufficientBalance,
    /// Slippage tolerance exceeded
    SlippageExceeded,
    /// Flash loan execution failed
    FlashLoanFailed,
    /// Arbitrage opportunity not profitable
    InsufficientProfit,
    /// Pool liquidity insufficient
    InsufficientLiquidity,
    /// Invalid token pair
    InvalidTokenPair,
    /// Gas price too high
    GasPriceTooHigh,
    /// Transaction deadline exceeded
    DeadlineExceeded,
    /// Unauthorized access
    Unauthorized,
    /// Emergency shutdown active
    EmergencyShutdown,
    /// Already initialized
    AlreadyInitialized,
    /// Risk limits exceeded
    RiskLimitExceeded,
    /// Compliance violation
    ComplianceViolation,
    /// Network congestion
    NetworkCongestion,
    /// Invalid parameters
    InvalidParameters,
    /// External call failed
    ExternalCallFailed,
    /// Sequencer unavailable
    SequencerUnavailable,
    /// Timeboost auction failed
    TimeboostFailed,
}

/// Trading pair information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TradingPair {
    pub token_a: Address,
    pub token_b: Address,
    pub fee: u32,
    pub pool_address: Address,
    pub protocol: ProtocolType,
}

/// Supported protocol types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ProtocolType {
    UniswapV3,
    SushiSwap,
    Curve,
    BalancerV2,
    Camelot,
    TraderJoe,
}

/// Pool state information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PoolState {
    pub reserve_a: U256,
    pub reserve_b: U256,
    pub fee_rate: u32,
    pub sqrt_price_x96: U256,
    pub liquidity: U256,
    pub tick: i32,
}

/// Arbitrage opportunity data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArbitrageOpportunity {
    pub token_in: Address,
    pub token_out: Address,
    pub amount_in: U256,
    pub expected_profit: U256,
    pub protocol_a: Address,
    pub protocol_b: Address,
    pub gas_cost: U256,
    pub time_sensitivity: u8, // 1-10 scale
}

/// MEV strategy types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum StrategyType {
    FlashSandwich,
    Arbitrage,
    Liquidation,
    JustInTime,
}

/// MEV transaction data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MEVTransaction {
    pub strategy_type: StrategyType,
    pub token_in: Address,
    pub token_out: Address,
    pub amount_in: U256,
    pub amount_out: U256,
    pub profit: U256,
    pub gas_used: U256,
    pub timestamp: u64,
    pub block_number: u64,
}

/// Risk management parameters
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RiskParams {
    pub max_position_size: U256,
    pub max_slippage_bp: u32,
    pub max_gas_price: U256,
    pub max_daily_loss: U256,
    pub max_drawdown_bp: u32,
    pub kelly_factor: u32, // Kelly criterion multiplier (basis points)
}

/// Performance metrics
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    pub total_profit: U256,
    pub total_trades: u64,
    pub win_rate: u32, // basis points
    pub sharpe_ratio: i32, // scaled by 10000
    pub max_drawdown: u32, // basis points
    pub avg_profit_per_trade: U256,
    pub gas_efficiency: u32, // profit per gas ratio
}

/// Network conditions
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NetworkConditions {
    pub gas_price: U256,
    pub block_time: u64,
    pub pending_tx_count: u64,
    pub sequencer_latency: u64,
    pub congestion_level: u8, // 1-10 scale
}

/// Timeboost auction data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TimeboostAuction {
    pub express_lane_controller: Address,
    pub current_round: u64,
    pub round_duration: u64,
    pub min_bid: U256,
    pub current_highest_bid: U256,
    pub auction_end_time: u64,
}

/// Express lane bid
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ExpressLaneBid {
    pub bidder: Address,
    pub amount: U256,
    pub round: u64,
    pub timestamp: u64,
}

/// Compliance monitoring data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ComplianceData {
    pub transaction_count: u64,
    pub daily_volume: U256,
    pub suspicious_activity_score: u8,
    pub regulatory_flags: Vec<String>,
    pub reporting_threshold_reached: bool,
    pub last_audit_timestamp: u64,
}

/// Flash loan provider information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FlashLoanProvider {
    pub protocol: FlashLoanProtocol,
    pub pool_address: Address,
    pub fee_rate: u32, // basis points
    pub max_amount: U256,
    pub available_tokens: Vec<Address>,
}

/// Flash loan protocols
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum FlashLoanProtocol {
    AaveV3,
    BalancerV2,
    UniswapV3,
    dYdX,
}

/// Sequencer status information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SequencerStatus {
    pub is_active: bool,
    pub last_update: u64,
    pub tx_queue_size: u64,
    pub avg_block_time: u64,
    pub estimated_next_block: u64,
}

/// Gas estimation data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GasEstimate {
    pub base_fee: U256,
    pub priority_fee: U256,
    pub total_gas: U256,
    pub estimated_cost: U256,
    pub confidence: u8, // 1-100
}

/// Protocol fee structure
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ProtocolFees {
    pub swap_fee: u32,      // basis points
    pub flash_loan_fee: u32, // basis points
    pub protocol_fee: u32,   // basis points
    pub gas_subsidy: U256,   // wei
}

/// Market maker position
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MarketMakerPosition {
    pub token_a_balance: U256,
    pub token_b_balance: U256,
    pub unclaimed_fees: U256,
    pub position_value: U256,
    pub impermanent_loss: U256,
}

/// Cross-chain bridge information
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BridgeInfo {
    pub source_chain: u64,
    pub destination_chain: u64,
    pub bridge_address: Address,
    pub fee_rate: u32,
    pub min_amount: U256,
    pub max_amount: U256,
    pub estimated_time: u64,
}

/// Oracle price data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PriceData {
    pub token: Address,
    pub price_usd: U256,
    pub timestamp: u64,
    pub confidence: u8,
    pub source: PriceSource,
}

/// Price oracle sources
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum PriceSource {
    Chainlink,
    UniswapTWAP,
    BalancerTWAP,
    CurveTWAP,
    Pyth,
}

/// Liquidation opportunity
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LiquidationOpportunity {
    pub protocol: Address,
    pub borrower: Address,
    pub collateral_token: Address,
    pub debt_token: Address,
    pub collateral_amount: U256,
    pub debt_amount: U256,
    pub liquidation_bonus: u32, // basis points
    pub health_factor: U256,
}

/// MEV bundle data
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MEVBundle {
    pub transactions: Vec<Bytes>,
    pub block_number: u64,
    pub min_timestamp: u64,
    pub max_timestamp: u64,
    pub reverting_tx_hashes: Vec<[u8; 32]>,
    pub replacement_uuid: Option<String>,
}

/// Constants for calculations
pub const BASIS_POINTS: u32 = 10000;
pub const WAD: U256 = U256::from_limbs([1000000000000000000, 0, 0, 0]); // 1e18
pub const RAY: U256 = U256::from_limbs([1000000000000000000000000000, 0, 0, 0]); // 1e27

/// Helper trait for basis point calculations
pub trait BasisPoints {
    fn from_bp(bp: u32) -> Self;
    fn to_bp(&self) -> u32;
}

impl BasisPoints for U256 {
    fn from_bp(bp: u32) -> Self {
        U256::from(bp) * WAD / U256::from(BASIS_POINTS)
    }

    fn to_bp(&self) -> u32 {
        (*self * U256::from(BASIS_POINTS) / WAD).as_limbs()[0] as u32
    }
}