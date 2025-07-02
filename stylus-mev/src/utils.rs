//! Utility Functions for MEV Operations
//! 
//! This module provides helper functions for mathematical calculations,
//! unit conversions, and common operations used throughout the MEV system.

use stylus_sdk::alloy_primitives::{Address, U256, Bytes};
use crate::types::*;

/// Mathematical utility functions
pub mod math {
    use super::*;

    /// Calculate square root using Newton's method
    /// Used for AMM calculations and volatility computations
    pub fn sqrt(value: U256) -> U256 {
        if value.is_zero() {
            return U256::ZERO;
        }

        if value < U256::from(4) {
            return U256::from(1);
        }

        let mut x = value;
        let mut y = (value + U256::from(1)) / U256::from(2);

        while y < x {
            x = y;
            y = (x + value / x) / U256::from(2);
        }

        x
    }

    /// Calculate power using binary exponentiation
    pub fn pow(base: U256, exponent: U256) -> U256 {
        if exponent.is_zero() {
            return U256::from(1);
        }

        let mut result = U256::from(1);
        let mut base = base;
        let mut exp = exponent;

        while !exp.is_zero() {
            if exp & U256::from(1) == U256::from(1) {
                result = result * base;
            }
            base = base * base;
            exp = exp >> 1;
        }

        result
    }

    /// Calculate percentage with basis points precision
    pub fn calculate_percentage_bp(value: U256, percentage_bp: U256) -> U256 {
        value * percentage_bp / U256::from(10000)
    }

    /// Calculate compound interest
    pub fn compound_interest(principal: U256, rate_bp: U256, periods: U256) -> U256 {
        let rate = U256::from(10000) + rate_bp; // 1 + rate
        let multiplier = pow(rate, periods);
        principal * multiplier / pow(U256::from(10000), periods)
    }

    /// Calculate moving average
    pub fn moving_average(current_avg: U256, new_value: U256, weight: U256) -> U256 {
        (current_avg * (U256::from(100) - weight) + new_value * weight) / U256::from(100)
    }

    /// Calculate volatility using standard deviation approximation
    pub fn calculate_volatility(prices: &[U256]) -> U256 {
        if prices.len() < 2 {
            return U256::ZERO;
        }

        let mean = calculate_mean(prices);
        let variance = calculate_variance(prices, mean);
        sqrt(variance)
    }

    /// Calculate mean of values
    pub fn calculate_mean(values: &[U256]) -> U256 {
        if values.is_empty() {
            return U256::ZERO;
        }

        let sum: U256 = values.iter().fold(U256::ZERO, |acc, &x| acc + x);
        sum / U256::from(values.len())
    }

    /// Calculate variance
    pub fn calculate_variance(values: &[U256], mean: U256) -> U256 {
        if values.len() < 2 {
            return U256::ZERO;
        }

        let sum_squared_diff: U256 = values
            .iter()
            .map(|&x| {
                let diff = if x > mean { x - mean } else { mean - x };
                diff * diff
            })
            .fold(U256::ZERO, |acc, x| acc + x);

        sum_squared_diff / U256::from(values.len() - 1)
    }

    /// Calculate Sharpe ratio
    pub fn calculate_sharpe_ratio(returns: &[U256], risk_free_rate: U256) -> U256 {
        if returns.is_empty() {
            return U256::ZERO;
        }

        let mean_return = calculate_mean(returns);
        let excess_return = if mean_return > risk_free_rate {
            mean_return - risk_free_rate
        } else {
            return U256::ZERO;
        };

        let volatility = calculate_volatility(returns);
        if volatility.is_zero() {
            return U256::ZERO;
        }

        excess_return * U256::from(10000) / volatility // Return in basis points
    }
}

/// AMM utility functions
pub mod amm {
    use super::*;

    /// Calculate output amount for constant product AMM (Uniswap V2 style)
    pub fn calculate_constant_product_output(
        amount_in: U256,
        reserve_in: U256,
        reserve_out: U256,
        fee_bp: u32,
    ) -> Result<U256, MEVError> {
        if reserve_in.is_zero() || reserve_out.is_zero() {
            return Err(MEVError::InsufficientLiquidity);
        }

        let amount_in_with_fee = amount_in * U256::from(10000 - fee_bp) / U256::from(10000);
        let numerator = amount_in_with_fee * reserve_out;
        let denominator = reserve_in + amount_in_with_fee;

        if denominator.is_zero() {
            return Err(MEVError::InsufficientLiquidity);
        }

        Ok(numerator / denominator)
    }

    /// Calculate price impact for a trade
    pub fn calculate_price_impact(
        amount_in: U256,
        reserve_in: U256,
        reserve_out: U256,
        fee_bp: u32,
    ) -> Result<U256, MEVError> {
        let amount_out = calculate_constant_product_output(amount_in, reserve_in, reserve_out, fee_bp)?;
        
        let price_before = reserve_out * U256::from(10000) / reserve_in;
        let new_reserve_in = reserve_in + amount_in;
        let new_reserve_out = reserve_out - amount_out;
        
        if new_reserve_out.is_zero() || new_reserve_in.is_zero() {
            return Err(MEVError::InsufficientLiquidity);
        }

        let price_after = new_reserve_out * U256::from(10000) / new_reserve_in;
        
        let price_impact = if price_before > price_after {
            (price_before - price_after) * U256::from(10000) / price_before
        } else {
            (price_after - price_before) * U256::from(10000) / price_before
        };

        Ok(price_impact)
    }

    /// Calculate optimal arbitrage amount between two pools
    pub fn calculate_optimal_arbitrage_amount(
        reserve_a_in: U256,
        reserve_a_out: U256,
        reserve_b_in: U256,
        reserve_b_out: U256,
        fee_a_bp: u32,
        fee_b_bp: u32,
    ) -> Result<U256, MEVError> {
        // Simplified calculation - in production would use more sophisticated optimization
        let price_a = reserve_a_out * U256::from(10000) / reserve_a_in;
        let price_b = reserve_b_out * U256::from(10000) / reserve_b_in;

        if price_a == price_b {
            return Ok(U256::ZERO); // No arbitrage opportunity
        }

        // Estimate optimal amount as percentage of smaller reserve
        let min_reserve = reserve_a_in.min(reserve_b_in);
        Ok(min_reserve / U256::from(20)) // 5% of smaller reserve
    }

    /// Calculate slippage for a trade
    pub fn calculate_slippage(
        expected_output: U256,
        actual_output: U256,
    ) -> U256 {
        if expected_output.is_zero() {
            return U256::ZERO;
        }

        if actual_output >= expected_output {
            return U256::ZERO; // No negative slippage
        }

        let slippage = (expected_output - actual_output) * U256::from(10000) / expected_output;
        slippage
    }
}

/// Conversion utility functions
pub mod conversions {
    use super::*;

    /// Convert wei to ETH (18 decimals)
    pub fn wei_to_eth(wei: U256) -> U256 {
        wei / U256::from(10).pow(U256::from(18))
    }

    /// Convert ETH to wei
    pub fn eth_to_wei(eth: U256) -> U256 {
        eth * U256::from(10).pow(U256::from(18))
    }

    /// Convert basis points to percentage
    pub fn bp_to_percentage(bp: U256) -> U256 {
        bp / U256::from(100)
    }

    /// Convert percentage to basis points
    pub fn percentage_to_bp(percentage: U256) -> U256 {
        percentage * U256::from(100)
    }

    /// Convert timestamp to days
    pub fn timestamp_to_days(timestamp: u64) -> u64 {
        timestamp / 86400 // 24 * 60 * 60
    }

    /// Convert gas price from gwei to wei
    pub fn gwei_to_wei(gwei: U256) -> U256 {
        gwei * U256::from(10).pow(U256::from(9))
    }

    /// Convert wei to gwei
    pub fn wei_to_gwei(wei: U256) -> U256 {
        wei / U256::from(10).pow(U256::from(9))
    }
}

/// Time utility functions
pub mod time {
    use super::*;

    /// Check if timestamp is within a certain window
    pub fn is_within_window(timestamp: u64, window_seconds: u64) -> bool {
        let current_time = get_current_timestamp();
        let time_diff = if current_time > timestamp {
            current_time - timestamp
        } else {
            timestamp - current_time
        };
        time_diff <= window_seconds
    }

    /// Get current timestamp (mock for Stylus environment)
    pub fn get_current_timestamp() -> u64 {
        // In actual Stylus, this would use block::timestamp()
        1000000000 // Mock timestamp
    }

    /// Calculate time until expiry
    pub fn time_until_expiry(expiry_timestamp: u64) -> u64 {
        let current_time = get_current_timestamp();
        if expiry_timestamp > current_time {
            expiry_timestamp - current_time
        } else {
            0
        }
    }

    /// Check if deadline has passed
    pub fn is_deadline_passed(deadline: u64) -> bool {
        get_current_timestamp() > deadline
    }
}

/// Address utility functions
pub mod addresses {
    use super::*;

    /// Check if address is zero address
    pub fn is_zero_address(address: Address) -> bool {
        address == Address::ZERO
    }

    /// Validate address is not zero
    pub fn validate_non_zero_address(address: Address) -> Result<(), MEVError> {
        if is_zero_address(address) {
            Err(MEVError::InvalidTokenPair)
        } else {
            Ok(())
        }
    }

    /// Generate deterministic address from components
    pub fn generate_pair_address(token_a: Address, token_b: Address, fee: u32) -> Address {
        // Simplified implementation - would use proper CREATE2 calculation
        Address::ZERO
    }
}

/// Validation utility functions
pub mod validation {
    use super::*;

    /// Validate amount is not zero
    pub fn validate_non_zero_amount(amount: U256) -> Result<(), MEVError> {
        if amount.is_zero() {
            Err(MEVError::InsufficientLiquidity)
        } else {
            Ok(())
        }
    }

    /// Validate slippage is within acceptable range
    pub fn validate_slippage(slippage_bp: U256, max_slippage_bp: U256) -> Result<(), MEVError> {
        if slippage_bp > max_slippage_bp {
            Err(MEVError::SlippageExceeded)
        } else {
            Ok(())
        }
    }

    /// Validate deadline has not passed
    pub fn validate_deadline(deadline: u64) -> Result<(), MEVError> {
        if time::is_deadline_passed(deadline) {
            Err(MEVError::DeadlineExceeded)
        } else {
            Ok(())
        }
    }

    /// Validate profit meets minimum threshold
    pub fn validate_minimum_profit(profit: U256, min_profit: U256) -> Result<(), MEVError> {
        if profit < min_profit {
            Err(MEVError::InsufficientProfit)
        } else {
            Ok(())
        }
    }

    /// Validate position size is within limits
    pub fn validate_position_size(amount: U256, max_amount: U256) -> Result<(), MEVError> {
        if amount > max_amount {
            Err(MEVError::RiskLimitExceeded)
        } else {
            Ok(())
        }
    }
}

/// Encoding/Decoding utilities
pub mod encoding {
    use super::*;

    /// Encode function call data
    pub fn encode_function_call(
        function_selector: [u8; 4],
        parameters: &[U256],
    ) -> Bytes {
        let mut data = Vec::new();
        data.extend_from_slice(&function_selector);
        
        for param in parameters {
            let param_bytes = param.to_be_bytes::<32>();
            data.extend_from_slice(&param_bytes);
        }
        
        Bytes::from(data)
    }

    /// Decode transaction data
    pub fn decode_swap_data(data: &Bytes) -> Result<SwapData, MEVError> {
        if data.len() < 4 {
            return Err(MEVError::InvalidTokenPair);
        }

        // Simplified decoding - would need full ABI parsing in production
        Ok(SwapData {
            function_selector: [data[0], data[1], data[2], data[3]],
            token_in: Address::ZERO,
            token_out: Address::ZERO,
            amount_in: U256::ZERO,
            amount_out_min: U256::ZERO,
            deadline: 0,
        })
    }
}

/// Performance monitoring utilities
pub mod performance {
    use super::*;

    /// Calculate execution time
    pub fn calculate_execution_time(start_time: u64, end_time: u64) -> u64 {
        if end_time > start_time {
            end_time - start_time
        } else {
            0
        }
    }

    /// Calculate win rate
    pub fn calculate_win_rate(winning_trades: u64, total_trades: u64) -> u8 {
        if total_trades == 0 {
            return 0;
        }
        ((winning_trades * 100) / total_trades) as u8
    }

    /// Calculate average profit
    pub fn calculate_average_profit(total_profit: U256, trade_count: u64) -> U256 {
        if trade_count == 0 {
            return U256::ZERO;
        }
        total_profit / U256::from(trade_count)
    }

    /// Calculate profit factor
    pub fn calculate_profit_factor(total_profit: U256, total_loss: U256) -> U256 {
        if total_loss.is_zero() {
            return U256::MAX; // Infinite profit factor
        }
        total_profit * U256::from(10000) / total_loss // Return in basis points
    }
}

/// Helper structures
#[derive(Debug, Clone)]
pub struct SwapData {
    pub function_selector: [u8; 4],
    pub token_in: Address,
    pub token_out: Address,
    pub amount_in: U256,
    pub amount_out_min: U256,
    pub deadline: u64,
}

/// Constants used throughout the system
pub mod constants {
    use super::*;

    /// Zero address constant
    pub const ZERO_ADDRESS: Address = Address::ZERO;
    
    /// Maximum basis points (100%)
    pub const MAX_BASIS_POINTS: u32 = 10000;
    
    /// Seconds per day
    pub const SECONDS_PER_DAY: u64 = 86400;
    
    /// Seconds per hour
    pub const SECONDS_PER_HOUR: u64 = 3600;
    
    /// Wei per ETH
    pub const WEI_PER_ETH: u64 = 1_000_000_000_000_000_000;
    
    /// Gwei per ETH
    pub const GWEI_PER_ETH: u64 = 1_000_000_000;
    
    /// Default gas limit for complex operations
    pub const DEFAULT_GAS_LIMIT: u64 = 2_000_000;
    
    /// Minimum profit threshold (0.001 ETH in wei)
    pub const MIN_PROFIT_WEI: u64 = 1_000_000_000_000_000;
}

/// Error handling utilities
pub mod errors {
    use super::*;

    /// Convert error to string representation
    pub fn error_to_string(error: &MEVError) -> &'static str {
        match error {
            MEVError::InsufficientBalance => "Insufficient balance",
            MEVError::InsufficientProfit => "Insufficient profit",
            MEVError::GasPriceTooHigh => "Gas price too high",
            MEVError::Unauthorized => "Unauthorized access",
            MEVError::EmergencyShutdown => "Emergency shutdown active",
            MEVError::AlreadyInitialized => "Already initialized",
            MEVError::SlippageExceeded => "Slippage exceeded",
            MEVError::RiskLimitExceeded => "Risk limit exceeded",
            MEVError::FlashLoanFailed => "Flash loan failed",
            MEVError::ExternalCallFailed => "External call failed",
            MEVError::InvalidTokenPair => "Invalid token pair",
            MEVError::InsufficientLiquidity => "Insufficient liquidity",
            MEVError::DeadlineExceeded => "Deadline exceeded",
            MEVError::InvalidParameters => "Invalid parameters",
            MEVError::ComplianceViolation => "Compliance violation",
            MEVError::NetworkCongestion => "Network congestion",
            MEVError::SequencerUnavailable => "Sequencer unavailable",
            MEVError::TimeboostFailed => "Timeboost failed",
        }
    }

    /// Check if error is recoverable
    pub fn is_recoverable_error(error: &MEVError) -> bool {
        match error {
            MEVError::NetworkCongestion | 
            MEVError::SequencerUnavailable |
            MEVError::InsufficientLiquidity => true,
            _ => false,
        }
    }
}