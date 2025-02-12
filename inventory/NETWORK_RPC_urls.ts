const NETWORK_RPC_URLS = {
    // EVM Networks
    ethereum: {
        mainnet: [
            "https://eth.llamarpc.com",
            "https://rpc.ankr.com/eth",
            "https://ethereum.publicnode.com",
            "https://1rpc.io/eth",
            "https://eth.rpc.blxrbdn.com"
        ],
        goerli: [
            "https://rpc.ankr.com/eth_goerli",
            "https://goerli.infura.io/v3/YOUR-PROJECT-ID",
            "https://eth-goerli.public.blastapi.io"
        ],
        sepolia: [
            "https://rpc.sepolia.org",
            "https://sepolia.infura.io/v3/YOUR-PROJECT-ID"
        ]
    },
    
    polygon: {
        mainnet: [
            "https://polygon-rpc.com",
            "https://rpc-mainnet.matic.network",
            "https://matic-mainnet.chainstacklabs.com",
            "https://rpc.ankr.com/polygon",
            "https://polygon.llamarpc.com"
        ],
        mumbai: [
            "https://rpc-mumbai.maticvigil.com",
            "https://polygon-mumbai.infura.io/v3/YOUR-PROJECT-ID",
            "https://matic-mumbai.chainstacklabs.com"
        ]
    },
    
    arbitrum: {
        mainnet: [
            "https://arb1.arbitrum.io/rpc",
            "https://rpc.ankr.com/arbitrum",
            "https://arbitrum.llamarpc.com"
        ],
        goerli: [
            "https://goerli-rollup.arbitrum.io/rpc",
            "https://arbitrum-goerli.public.blastapi.io"
        ]
    },
    
    optimism: {
        mainnet: [
            "https://mainnet.optimism.io",
            "https://rpc.ankr.com/optimism",
            "https://optimism.llamarpc.com"
        ],
        goerli: [
            "https://goerli.optimism.io",
            "https://opt-goerli.g.alchemy.com/v2/YOUR-API-KEY"
        ]
    },
    
    base: {
        mainnet: [
            "https://mainnet.base.org",
            "https://base.llamarpc.com",
            "https://base.gateway.tenderly.co"
        ],
        goerli: [
            "https://goerli.base.org",
            "https://base-goerli.public.blastapi.io"
        ]
    },
    
    avalanche: {
        mainnet: [
            "https://api.avax.network/ext/bc/C/rpc",
            "https://rpc.ankr.com/avalanche",
            "https://avalanche.public-rpc.com"
        ],
        fuji: [
            "https://api.avax-test.network/ext/bc/C/rpc",
            "https://avalanche-fuji.infura.io/v3/YOUR-PROJECT-ID"
        ]
    },
    
    binance: {
        mainnet: [
            "https://bsc-dataseed.binance.org",
            "https://bsc-dataseed1.defibit.io",
            "https://rpc.ankr.com/bsc",
            "https://bsc.publicnode.com"
        ],
        testnet: [
            "https://data-seed-prebsc-1-s1.binance.org:8545",
            "https://data-seed-prebsc-2-s1.binance.org:8545"
        ]
    },

    // Aptos Networks
    aptos: {
        mainnet: [
            "https://fullnode.mainnet.aptoslabs.com/v1",
            "https://aptos-mainnet.pontem.network",
            "https://aptos-mainnet.nodereal.io/v1/YOUR-API-KEY"
        ],
        testnet: [
            "https://fullnode.testnet.aptoslabs.com/v1",
            "https://aptos-testnet.nodereal.io/v1/YOUR-API-KEY"
        ],
        devnet: [
            "https://fullnode.devnet.aptoslabs.com/v1"
        ]
    },

    // Solana Networks
    solana: {
        mainnet: [
            "https://api.mainnet-beta.solana.com",
            "https://solana-mainnet.rpc.extrnode.com",
            "https://rpc.ankr.com/solana",
            "https://solana.public-rpc.com"
        ],
        devnet: [
            "https://api.devnet.solana.com",
            "https://rpc.devnet.solana.com"
        ],
        testnet: [
            "https://api.testnet.solana.com",
            "https://rpc.testnet.solana.com"
        ]
    }
};

// Utility functions
const getRpcUrls = (network, environment = 'mainnet') => {
    if (!NETWORK_RPC_URLS[network]) {
        throw new Error(`Network '${network}' not found`);
    }
    if (!NETWORK_RPC_URLS[network][environment]) {
        throw new Error(`Environment '${environment}' not found for network '${network}'`);
    }
    return NETWORK_RPC_URLS[network][environment];
};

const getRandomRpcUrl = (network, environment = 'mainnet') => {
    const urls = getRpcUrls(network, environment);
    return urls[Math.floor(Math.random() * urls.length)];
};

const getAllNetworks = () => {
    return Object.keys(NETWORK_RPC_URLS);
};

const getNetworkEnvironments = (network) => {
    if (!NETWORK_RPC_URLS[network]) {
        throw new Error(`Network '${network}' not found`);
    }
    return Object.keys(NETWORK_RPC_URLS[network]);
};

module.exports = {
    NETWORK_RPC_URLS,
    getRpcUrls,
    getRandomRpcUrl,
    getAllNetworks,
    getNetworkEnvironments
};