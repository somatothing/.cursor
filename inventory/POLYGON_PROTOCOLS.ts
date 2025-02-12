// Polygon DeFi Protocol Addresses
const POLYGON_PROTOCOLS = {
    // === AAVE Protocol ===
    aave: {
        v3: {
            pool: "0x794a61358D6845594F94dc1DB02A252b5b4814aD",
            poolAddressProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
            poolDataProvider: "0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654",
            uiPoolDataProvider: "0x67aA72f5c6DB7164894Bc95A622185e4Cc7538E3",
            oracle: "0xb023e699F5a33916Ea823A16485e259257cA8Bd1",
            wethGateway: "0x1e4b7A6b903680eab0c5dAbcb8fD429cD2a9598c",
            flashLoan: "0x794a61358D6845594F94dc1DB02A252b5b4814aD"
        },
        incentives: {
            rewardsController: "0x929EC64c34a17401F460460D4B9390518E5B473e",
            emissionManager: "0x048f2228D7Bf6776f99aB50cB1b1eaB4D1d4cA73"
        }
    },

    // === Balancer Protocol ===
    balancer: {
        core: {
            vault: "0xBA12222222228d8Ba445958a75a0704d566BF2C8",
            weightedPoolFactory: "0x298eff8af1ecEbbF2511B6cdC1995870968228A7",
            composablePoolFactory: "0x136FD06Fa01eCF624C7F2B3CB15742c1339dC2c4",
            liquidityGaugeFactory: "0x3B8cA519122CdD8efb272b0D3085453404B25bD0"
        },
        pools: {
            stablePool: "0x06Df3b2bbB68adc8B0e302443692037ED9f91b42",
            wmaticUSDC: "0x0297e37f1873D2DAb4487Aa67cD56B58E2F27875",
            wethBalPool: "0x3d468AB2329F296e1b9d8476Bb54Dd77D8c2320f",
            boostedAaveUSD: "0x48e6B98ef6329f8f0A30eBB8c7C960330d648085"
        }
    },

    // === Uniswap Protocol ===
    uniswap: {
        v3: {
            factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
            router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
            quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6",
            nftPositionManager: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
        },
        pools: {
            usdcUsdt: "0x3416cF6C708Da44DB2624D63ea0AAef7113527C6",
            wethUsdc: "0x45dDa9cb7c25131DF268515131f647d726f50608",
            wbtcWeth: "0x50eaEDB835021E4A108B7290636d62E9765cc6d7"
        }
    },

    // === PancakeSwap on Polygon ===
    pancakeswap: {
        factory: "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f",
        router: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
        masterChef: "0x9a31A1B8d3225C3A833FA58174FE42FFE025D38E"
    },

    // === DODO Exchange ===
    dodo: {
        v2Proxy: "0xa222e6a71D1A1Dd5F279805fbe38d5329C1d0e70",
        dodoV2Helper: "0x6B9A9F7BD1787467B04E6dF85e1e13F8Acb9170B",
        factory: "0x4F4DAB54D754eBF85245F790Df89C1DcEfC3Ff35",
        pools: {
            usdcUsdt: "0x813FddecCD0401c4Fa73B092b074802440544E52",
            wethUsdc: "0x90E6C403c02f72986a98E8b8B6429a763B14b14A"
        }
    },

    // === 0x Protocol ===
    zeroEx: {
        exchange: "0xDef1C0ded9bec7F1a1670819833240f027b25EfF"
    },

    // === LayerZero ===
    layerZero: {
        endpoint: "0x3c2269811836af69497E5F486A85D7316753cf62",
        ultraLightNode: "0x4D73AdB72bC3DD368966edD0f0b2148401A178E2"
    },

    // === Equalizer Exchange ===
    equalizer: {
        factory: "0x1A26c88976A0243Fe25555C80e61acce85B45015",
        router: "0xf0e4f1765194842485C6BcE469A500989235c700"
    },

    // === DeFi Saver ===
    defiSaver: {
        registry: "0xD8612A33079000B3FA2Ef552De42Dc3eBB8B4Be2",
    },

    // === Smart Money Addresses ===
    smartMoney: {
        wallets: [
            "0x7265bd52764c119440536824E54757D9724F736c",
            "0x4B3B4120d4D7975455d8C2894228789c91a247F8",
            "0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56"
        ]
    },

    // === Oracle Services ===
    oracles: {
        chainlink: {
            feedRegistry: "0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf",
            ethUsd: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
            btcUsd: "0xc907E116054Ad103354f2D350FD2514433D57F6f",
            maticUsd: "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0"
        },
        uniswapV3: {
            factory: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
            quoter: "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6"
        }
    }
};

// === Utility Functions ===
const utils = {
    // Get AAVE related addresses
    getAaveAddress: (version, component) => {
        return POLYGON_PROTOCOLS.aave[version][component];
    },

    // Get Balancer pool address
    getBalancerPool: (poolName) => {
        return POLYGON_PROTOCOLS.balancer.pools[poolName];
    },

    // Get Uniswap pool address
    getUniswapPool: (poolName) => {
        return POLYGON_PROTOCOLS.uniswap.pools[poolName];
    },

    // Get oracle price feed
    getOracleFeed: (platform, pair) => {
        return POLYGON_PROTOCOLS.oracles[platform][pair];
    },

    // Get smart money wallet
    getSmartMoneyWallet: (index) => {
        return POLYGON_PROTOCOLS.smartMoney.wallets[index];
    },

    // Get protocol router
    getRouter: (protocol) => {
        return POLYGON_PROTOCOLS[protocol].router;
    }
};

module.exports = {
    POLYGON_PROTOCOLS,
    utils
};