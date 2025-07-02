#!/bin/bash

# Arbitrum MEV FlashSandwich System Deployment Script
# This script handles the complete deployment process for the MEV system

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="arbitrum-mev-stylus"
WASM_TARGET="wasm32-unknown-unknown"
BUILD_DIR="target/${WASM_TARGET}/release"
WASM_FILE="${BUILD_DIR}/${PROJECT_NAME//-/_}.wasm"

# Default values
NETWORK="mainnet"
PRIVATE_KEY=""
RPC_URL=""
GAS_LIMIT="10000000"
VERIFY_CONTRACT="false"
INITIALIZE_SYSTEM="true"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --network NETWORK     Target network (mainnet, testnet, local) [default: mainnet]"
    echo "  -k, --private-key KEY     Private key for deployment (without 0x prefix)"
    echo "  -r, --rpc-url URL         RPC endpoint URL"
    echo "  -g, --gas-limit LIMIT     Gas limit for deployment [default: 10000000]"
    echo "  -v, --verify              Verify contract after deployment"
    echo "  --no-init                 Skip system initialization"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  PRIVATE_KEY               Private key (alternative to --private-key)"
    echo "  ARBITRUM_RPC_URL          RPC URL (alternative to --rpc-url)"
    echo ""
    echo "Examples:"
    echo "  $0 --network testnet --private-key abc123..."
    echo "  $0 --network mainnet --verify"
    echo "  PRIVATE_KEY=abc123... $0 --network mainnet"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--network)
            NETWORK="$2"
            shift 2
            ;;
        -k|--private-key)
            PRIVATE_KEY="$2"
            shift 2
            ;;
        -r|--rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        -g|--gas-limit)
            GAS_LIMIT="$2"
            shift 2
            ;;
        -v|--verify)
            VERIFY_CONTRACT="true"
            shift
            ;;
        --no-init)
            INITIALIZE_SYSTEM="false"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Load environment variables if .env exists
if [[ -f .env ]]; then
    print_status "Loading environment variables from .env"
    export $(grep -v '^#' .env | xargs)
fi

# Set default values from environment if not provided
if [[ -z "$PRIVATE_KEY" ]]; then
    PRIVATE_KEY="$PRIVATE_KEY"
fi

if [[ -z "$RPC_URL" ]]; then
    case $NETWORK in
        mainnet)
            RPC_URL="${ARBITRUM_RPC_URL:-https://arb1.arbitrum.io/rpc}"
            ;;
        testnet)
            RPC_URL="${ARBITRUM_TESTNET_RPC_URL:-https://goerli-rollup.arbitrum.io/rpc}"
            ;;
        local)
            RPC_URL="http://localhost:8545"
            ;;
        *)
            print_error "Unknown network: $NETWORK"
            exit 1
            ;;
    esac
fi

# Validate required parameters
if [[ -z "$PRIVATE_KEY" ]]; then
    print_error "Private key is required. Use --private-key or set PRIVATE_KEY environment variable."
    exit 1
fi

if [[ -z "$RPC_URL" ]]; then
    print_error "RPC URL is required. Use --rpc-url or set appropriate environment variable."
    exit 1
fi

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Rust is installed
    if ! command -v rustc &> /dev/null; then
        print_error "Rust is not installed. Please install Rust from https://rustup.rs/"
        exit 1
    fi
    
    # Check if wasm32 target is installed
    if ! rustup target list --installed | grep -q "$WASM_TARGET"; then
        print_status "Installing wasm32-unknown-unknown target..."
        rustup target add "$WASM_TARGET"
    fi
    
    # Check if cargo-stylus is installed
    if ! command -v cargo-stylus &> /dev/null; then
        print_status "Installing cargo-stylus..."
        cargo install cargo-stylus
    fi
    
    # Check if stylus CLI is installed
    if ! command -v stylus &> /dev/null; then
        print_warning "Stylus CLI not found. Installing..."
        cargo install --git https://github.com/OffchainLabs/cargo-stylus.git stylus-cli
    fi
    
    print_success "Prerequisites check completed"
}

# Function to build the project
build_project() {
    print_status "Building project for deployment..."
    
    # Clean previous builds
    cargo clean
    
    # Build optimized WASM binary
    RUSTFLAGS="-C link-arg=-zstack-size=8192" \
    cargo build \
        --release \
        --target "$WASM_TARGET" \
        --features "export-abi"
    
    # Check if WASM file was created
    if [[ ! -f "$WASM_FILE" ]]; then
        print_error "WASM file not found at $WASM_FILE"
        exit 1
    fi
    
    # Get file size
    WASM_SIZE=$(wc -c < "$WASM_FILE")
    print_success "Built WASM binary: $WASM_FILE (${WASM_SIZE} bytes)"
    
    # Optimize WASM binary
    if command -v wasm-opt &> /dev/null; then
        print_status "Optimizing WASM binary..."
        wasm-opt -Oz "$WASM_FILE" -o "${WASM_FILE}.opt"
        mv "${WASM_FILE}.opt" "$WASM_FILE"
        OPTIMIZED_SIZE=$(wc -c < "$WASM_FILE")
        print_success "Optimized WASM binary (${OPTIMIZED_SIZE} bytes)"
    else
        print_warning "wasm-opt not found. Install binaryen for better optimization."
    fi
}

# Function to deploy contract
deploy_contract() {
    print_status "Deploying contract to $NETWORK..."
    
    # Deploy using cargo-stylus
    DEPLOY_OUTPUT=$(cargo stylus deploy \
        --wasm-file "$WASM_FILE" \
        --private-key "$PRIVATE_KEY" \
        --endpoint "$RPC_URL" \
        --gas-limit "$GAS_LIMIT" 2>&1)
    
    # Extract contract address from output
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -o "0x[a-fA-F0-9]\{40\}" | head -1)
    
    if [[ -z "$CONTRACT_ADDRESS" ]]; then
        print_error "Failed to extract contract address from deployment output:"
        echo "$DEPLOY_OUTPUT"
        exit 1
    fi
    
    print_success "Contract deployed at: $CONTRACT_ADDRESS"
    
    # Save deployment info
    DEPLOYMENT_FILE="deployments/${NETWORK}-deployment.json"
    mkdir -p deployments
    
    cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$NETWORK",
  "contractAddress": "$CONTRACT_ADDRESS",
  "deploymentTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "gasLimit": "$GAS_LIMIT",
  "wasmSize": $(wc -c < "$WASM_FILE"),
  "rpcUrl": "$RPC_URL"
}
EOF
    
    print_success "Deployment info saved to $DEPLOYMENT_FILE"
}

# Function to verify contract
verify_contract() {
    if [[ "$VERIFY_CONTRACT" == "true" ]]; then
        print_status "Verifying contract..."
        
        # Verify using cargo-stylus
        cargo stylus verify \
            --wasm-file "$WASM_FILE" \
            --contract-address "$CONTRACT_ADDRESS" \
            --endpoint "$RPC_URL"
        
        print_success "Contract verification completed"
    fi
}

# Function to initialize system
initialize_system() {
    if [[ "$INITIALIZE_SYSTEM" == "true" ]]; then
        print_status "Initializing MEV system..."
        
        # Create initialization script
        cat > "scripts/initialize.js" << 'EOF'
const { ethers } = require('ethers');
const fs = require('fs');

async function initialize() {
    const deploymentFile = process.argv[2];
    const privateKey = process.argv[3];
    const rpcUrl = process.argv[4];
    
    const deployment = JSON.parse(fs.readFileSync(deploymentFile, 'utf8'));
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    
    // Contract ABI (simplified for initialization)
    const abi = [
        "function initialize(address owner, uint256 maxSlippageBp, uint256 minProfitWei) external",
        "function getSystemStatus() external view returns (address, bool, uint256, uint256, uint256)"
    ];
    
    const contract = new ethers.Contract(deployment.contractAddress, abi, wallet);
    
    console.log('Initializing MEV system...');
    const tx = await contract.initialize(
        wallet.address,
        500,  // 5% max slippage
        ethers.utils.parseEther('0.001')  // 0.001 ETH min profit
    );
    
    console.log('Transaction hash:', tx.hash);
    await tx.wait();
    
    console.log('System initialized successfully!');
    
    // Check system status
    const status = await contract.getSystemStatus();
    console.log('System status:', {
        owner: status[0],
        emergencyShutdown: status[1],
        maxSlippage: status[2].toString(),
        minProfitThreshold: status[3].toString(),
        totalProfits: status[4].toString()
    });
}

initialize().catch(console.error);
EOF
        
        # Run initialization if Node.js is available
        if command -v node &> /dev/null; then
            if [[ -f package.json ]] || npm list ethers &> /dev/null; then
                node "scripts/initialize.js" "$DEPLOYMENT_FILE" "$PRIVATE_KEY" "$RPC_URL"
                print_success "System initialization completed"
            else
                print_warning "ethers.js not found. Run 'npm install ethers' to enable initialization."
            fi
        else
            print_warning "Node.js not found. Manual initialization required."
            print_status "Save the following for manual initialization:"
            echo "Contract Address: $CONTRACT_ADDRESS"
            echo "Owner: $(echo $PRIVATE_KEY | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -rmd160 -binary | xxd -p -c 20)"
        fi
    fi
}

# Function to show post-deployment instructions
show_post_deployment() {
    print_success "Deployment completed successfully!"
    echo ""
    echo "📋 Deployment Summary:"
    echo "  Network: $NETWORK"
    echo "  Contract Address: $CONTRACT_ADDRESS"
    echo "  RPC URL: $RPC_URL"
    echo "  Deployment File: $DEPLOYMENT_FILE"
    echo ""
    echo "🚀 Next Steps:"
    echo "  1. Fund the contract with initial capital"
    echo "  2. Configure flash loan providers"
    echo "  3. Set up monitoring and alerting"
    echo "  4. Test with small amounts first"
    echo ""
    echo "📖 Documentation:"
    echo "  - README.md for usage examples"
    echo "  - .env.example for configuration"
    echo "  - docs/ folder for detailed guides"
    echo ""
    echo "⚠️  Security Reminders:"
    echo "  - Keep your private key secure"
    echo "  - Enable multi-signature if possible"
    echo "  - Monitor risk metrics continuously"
    echo "  - Ensure regulatory compliance"
}

# Main execution
main() {
    print_status "Starting Arbitrum MEV FlashSandwich deployment..."
    print_status "Network: $NETWORK"
    print_status "RPC URL: $RPC_URL"
    
    check_prerequisites
    build_project
    deploy_contract
    verify_contract
    initialize_system
    show_post_deployment
}

# Run main function
main