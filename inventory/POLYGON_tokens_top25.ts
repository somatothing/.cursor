const POLYGON_TOKENS = [
    // Stablecoins
    {
        "name": "USD Coin",
        "address": "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
        "decimals": 6,
        "symbol": "USDC",
        "category": "stablecoin"
    },
    {
        "name": "Tether USD",
        "address": "0xc2132D05D31c914a87C6611C10748AEb04B58e8F",
        "decimals": 6,
        "symbol": "USDT",
        "category": "stablecoin"
    },
    {
        "name": "Dai Stablecoin",
        "address": "0x8F3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
        "decimals": 18,
        "symbol": "DAI",
        "category": "stablecoin"
    },

    // Wrapped Assets
    {
        "name": "Wrapped Ether",
        "address": "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
        "decimals": 18,
        "symbol": "WETH",
        "category": "wrapped"
    },
    {
        "name": "Wrapped Bitcoin",
        "address": "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6",
        "decimals": 8,
        "symbol": "WBTC",
        "category": "wrapped"
    },
    {
        "name": "Wrapped MATIC",
        "address": "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
        "decimals": 18,
        "symbol": "WMATIC",
        "category": "wrapped"
    },

    // DeFi Protocol Tokens
    {
        "name": "Aave",
        "address": "0xD6DF932A45C0f255f85145f286eA0b292B21C90B",
        "decimals": 18,
        "symbol": "AAVE",
        "category": "defi"
    },
    {
        "name": "Curve DAO Token",
        "address": "0x172370d5Cd63279eFa6d502DAB29171933a610AF",
        "decimals": 18,
        "symbol": "CRV",
        "category": "defi"
    },
    {
        "name": "SushiToken",
        "address": "0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a",
        "decimals": 18,
        "symbol": "SUSHI",
        "category": "defi"
    },

    // Aave Market Tokens
    {
        "name": "Aave Polygon USDC",
        "address": "0x1a13F4cA1d028320A707D99520AbFefca3998b7F",
        "decimals": 6,
        "symbol": "amUSDC",
        "category": "aave"
    },
    {
        "name": "Aave Polygon USDT",
        "address": "0x60D55F02A771d515e077c9C2403a1ef324885CeC",
        "decimals": 6,
        "symbol": "amUSDT",
        "category": "aave"
    },
    {
        "name": "Aave Polygon DAI",
        "address": "0x27F8D03b3a2196956ED754baDc28D73be8830A6e",
        "decimals": 18,
        "symbol": "amDAI",
        "category": "aave"
    },
    {
        "name": "Aave Polygon WETH",
        "address": "0x28424507fefb6f7f8E9D3860F56504E4e5f5f390",
        "decimals": 18,
        "symbol": "amWETH",
        "category": "aave"
    },
    {
        "name": "Aave Polygon WBTC",
        "address": "0x5c2ed810328349100A66B82b78a1791B101C9D61",
        "decimals": 8,
        "symbol": "amWBTC",
        "category": "aave"
    },
    {
        "name": "Aave Polygon WMATIC",
        "address": "0x8dF3aad3a84da6b69A4dA8aEC3ea40d9091B2Ac4",
        "decimals": 18,
        "symbol": "amMATIC",
        "category": "aave"
    },

    // Popular Gaming & Metaverse Tokens
    {
        "name": "ChainLink Token",
        "address": "0x53E0bca35eC356BD5ddDFebbD1Fc0fd03FaBad39",
        "decimals": 18,
        "symbol": "LINK",
        "category": "oracle"
    },
    {
        "name": "Decentraland",
        "address": "0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4",
        "decimals": 18,
        "symbol": "MANA",
        "category": "gaming"
    },
    {
        "name": "The Sandbox",
        "address": "0xBbba073C31bF03b8ACf7c28EF0738DeCF3695683",
        "decimals": 18,
        "symbol": "SAND",
        "category": "gaming"
    },

    // Governance Tokens
    {
        "name": "Uniswap",
        "address": "0xb33EaAd8d922B1083446DC23f610c2567fB5180f",
        "decimals": 18,
        "symbol": "UNI",
        "category": "governance"
    },
    {
        "name": "QuickSwap",
        "address": "0x831753DD7087CaC61aB5644b308642cc1c33Dc13",
        "decimals": 18,
        "symbol": "QUICK",
        "category": "governance"
    },

    // Lending Protocols
    {
        "name": "Compound",
        "address": "0x8505b9d2254A7Ae468c0E9dd10Ccea3A837aef5c",
        "decimals": 18,
        "symbol": "COMP",
        "category": "lending"
    },
    {
        "name": "1inch",
        "address": "0x9c2C5fd7b07E95EE044DDeba0E97a665F142394f",
        "decimals": 18,
        "symbol": "1INCH",
        "category": "dex"
    },

    // Yield Farming
    {
        "name": "Harvest Finance",
        "address": "0xab0b2ddB9C7e440fAc8E140A89c0dbCBf2d7Bbff",
        "decimals": 18,
        "symbol": "FARM",
        "category": "farming"
    },
    {
        "name": "Balancer",
        "address": "0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3",
        "decimals": 18,
        "symbol": "BAL",
        "category": "farming"
    },
    {
        "name": "Ren",
        "address": "0x19782D3Dc4701cEeeDcD90f0993f0A9126ed89d0",
        "decimals": 18,
        "symbol": "REN",
        "category": "bridge"
    }
];



// Utility functions for token operations
const getTokenBySymbol = (symbol) => {
    return POLYGON_TOKENS.find(token => token.symbol.toLowerCase() === symbol.toLowerCase());
};

const getTokenByAddress = (address) => {
    return POLYGON_TOKENS.find(token => token.address.toLowerCase() === address.toLowerCase());
};

const getTokensByCategory = (category) => {
    return POLYGON_TOKENS.filter(token => token.category === category);
};

module.exports = {
    POLYGON_TOKENS,
    getTokenBySymbol,
    getTokenByAddress,
    getTokensByCategory
};