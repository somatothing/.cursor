// types.ts
export interface APIConfig {
    // Previous config remains...
    marketData: {
        coingecko: {
            baseUrl: string;
            proEndpoint: string;
            free: {
                rateLimit: number; // requests per minute
                endpoints: {
                    simplePrice: string;
                    tokenList: string;
                    marketChart: string;
                    trending: string;
                };
            };
        };
        defiLlama: {
            baseUrl: string;
            endpoints: {
                tvl: string;
                protocols: string;
                coins: string;
                yields: string;
                stablecoins: string;
            };
        };
        coinMarketCap: {
            baseUrl: string;
            apiKey?: string; // Optional paid API key
        };
    };
    dex: {
        zeroX: {
            baseUrl: string;
            apiKeys: string[];
            endpoints: {
                quote: string;
                price: string;
                sources: string;
            };
            networks: Record<string, string>; // Network-specific endpoints
        };
        matcha: {
            baseUrl: string;
            websocket: string;
            endpoints: {
                orders: string;
                markets: string;
            };
        };
        oneInch: {
            baseUrl: string;
            endpoints: {
                swap: string;
                tokens: string;
                protocols: string;
            };
            supportedChains: number[];
        };
    };
    freeAI: {
        ollama: {
            baseUrl: string;
            models: string[];
        };
        localAI: {
            baseUrl: string;
            models: string[];
        };
        huggingFace: {
            inference: string;
            freeEndpoints: string[];
        };
        meta: {
            llama2: {
                endpoints: string[];
                models: string[];
            };
        };
    };
    chainData: {
        etherscan: {
            baseUrl: string;
            apiKey: string;
            endpoints: {
                transactions: string;
                accounts: string;
                contracts: string;
            };
        };
        polygonscan: {
            baseUrl: string;
            apiKey: string;
            endpoints: Record<string, string>;
        };
        covalent: {
            baseUrl: string;
            apiKey?: string;
            freeEndpoints: string[];
        };
    };
    ipfs: {
        gateways: string[];
        pinning: {
            pinata?: {
                apiKey: string;
                secret: string;
            };
            web3Storage?: string;
            nftStorage?: string;
        };
    };
    environment: 'development' | 'staging' | 'production';
}

// config.ts
export const config: APIConfig = {
    // Previous config remains...
    marketData: {
        coingecko: {
            baseUrl: 'https://api.coingecko.com/api/v3',
            proEndpoint: 'https://pro-api.coingecko.com/api/v3',
            free: {
                rateLimit: 50,
                endpoints: {
                    simplePrice: '/simple/price',
                    tokenList: '/coins/list',
                    marketChart: '/coins/{id}/market_chart',
                    trending: '/search/trending'
                }
            }
        },
        defiLlama: {
            baseUrl: 'https://api.llama.fi',
            endpoints: {
                tvl: '/protocols',
                protocols: '/protocol/{protocol}',
                coins: '/coins',
                yields: '/yields',
                stablecoins: '/stablecoins'
            }
        },
        coinMarketCap: {
            baseUrl: 'https://pro-api.coinmarketcap.com/v1'
        }
    },
    dex: {
        zeroX: {
            baseUrl: 'https://api.0x.org',
            apiKeys: [
                "bbb57dcf-70bf-4545-b5ba-028b7cefd5a2",
                "f4e72178-beef-478b-afab-3a262066553b"
            ],
            endpoints: {
                quote: '/swap/v1/quote',
                price: '/price',
                sources: '/sources'
            },
            networks: {
                ethereum: 'https://api.0x.org',
                polygon: 'https://polygon.api.0x.org',
                arbitrum: 'https://arbitrum.api.0x.org'
            }
        },
        matcha: {
            baseUrl: 'https://api.matcha.xyz',
            websocket: 'wss://api.matcha.xyz/ws',
            endpoints: {
                orders: '/orders',
                markets: '/markets'
            }
        },
        oneInch: {
            baseUrl: 'https://api.1inch.io/v5.0',
            endpoints: {
                swap: '/swap',
                tokens: '/tokens',
                protocols: '/liquidity-sources'
            },
            supportedChains: [1, 56, 137, 42161] // ETH, BSC, Polygon, Arbitrum
        }
    },
    freeAI: {
        ollama: {
            baseUrl: 'http://localhost:11434',
            models: [
                'llama2',
                'codellama',
                'mistral',
                'neural-chat'
            ]
        },
        localAI: {
            baseUrl: 'http://localhost:8080',
            models: [
                'gpt4all-j',
                'ggml-vicuna-7b-q4_0'
            ]
        },
        huggingFace: {
            inference: 'https://api-inference.huggingface.co/models',
            freeEndpoints: [
                'gpt2',
                'facebook/bart-large-cnn',
                'sentence-transformers/all-MiniLM-L6-v2'
            ]
        },
        meta: {
            llama2: {
                endpoints: [
                    'https://huggingface.co/meta-llama',
                    'https://replicate.com/meta/llama-2'
                ],
                models: [
                    'llama-2-7b',
                    'llama-2-13b',
                    'codellama-7b'
                ]
            }
        }
    },
    ipfs: {
        gateways: [
            'https://ipfs.io/ipfs/',
            'https://gateway.pinata.cloud/ipfs/',
            'https://cloudflare-ipfs.com/ipfs/',
            'https://gateway.ipfs.io/ipfs/'
        ],
        pinning: {
            web3Storage: 'free-tier-available',
            nftStorage: 'free-tier-available'
        }
    },
    environment: process.env.NODE_ENV === 'production' ? 'production' : 'development'
};

// Additional utility functions
export const getMarketData = async (
    source: 'coingecko' | 'defiLlama',
    endpoint: string,
    params: Record<string, any>
): Promise<any> => {
    const baseUrl = config.marketData[source].baseUrl;
    const url = new URL(`${baseUrl}${endpoint}`);
    Object.entries(params).forEach(([key, value]) => {
        url.searchParams.append(key, value);
    });
    
    const response = await fetch(url.toString());
    return response.json();
};

export const getDexQuote = async (
    dex: 'zeroX' | 'oneInch',
    params: {
        sellToken: string;
        buyToken: string;
        sellAmount: string;
        chainId?: number;
    }
): Promise<any> => {
    const dexConfig = config.dex[dex];
    const baseUrl = dexConfig.baseUrl;
    const endpoint = dexConfig.endpoints.quote;
    
    const response = await fetch(`${baseUrl}${endpoint}`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json',
            ...(dex === 'zeroX' && {
                '0x-api-key': dexConfig.apiKeys[0]
            })
        },
        body: JSON.stringify(params)
    });
    
    return response.json();
};

export const getLocalAIInference = async (
    model: string,
    prompt: string
): Promise<any> => {
    const { baseUrl } = config.freeAI.ollama;
    
    const response = await fetch(`${baseUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model,
            prompt,
            max_tokens: 500
        })
    });
    
    return response.json();
};

// Environment-specific configurations
export const getEnvConfig = () => {
    switch (config.environment) {
        case 'production':
            return {
                useCache: true,
                rateLimiting: true,
                errorLogging: true
            };
        case 'staging':
            return {
                useCache: true,
                rateLimiting: false,
                errorLogging: true
            };
        default:
            return {
                useCache: false,
                rateLimiting: false,
                errorLogging: true
            };
    }
};

export default {
    config,
    getMarketData,
    getDexQuote,
    getLocalAIInference,
    getEnvConfig
};