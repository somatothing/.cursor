// types.ts
export interface APIConfig {
    vercel: {
        apiKey: string;
    };
    baselime: {
        apiKey: string;
    };
    ai: {
        huggingFace: string;
        togetherAI: string[];
        gemini: {
            apiKey: string;
            secret: string;
        };
        openai: string;
        groq: {
            ethereumIDE: string;
            builders: string[];
        };
    };
    blockchain: {
        rpc: {
            arbitrum: string;
            tenderly: {
                wss: string;
                accessToken: string;
            };
            websocket: string;
        };
        scanners: {
            arbitrum: string;
            polygon: string;
            ethereum: string;
        };
        wallet: {
            privateKey: string;
            address: string;
        };
        zerox: string[];
    };
    services: {
        walletConnect: string;
        infura: string;
        thirdweb: string;
        sanity: string;
        cloudConnect: string;
        segment: string;
        netApi: string;
        pinecone: string;
    };
}

// config.ts
export const config: APIConfig = {
    vercel: {
        apiKey: "92jIDPWiZv7rAy29t2ZMkQh8"
    },
    baselime: {
        apiKey: "cf1b7193de1b225d0e5fa7e9e66173d8dd024331"
    },
    ai: {
        huggingFace: "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",
        togetherAI: [
            "e00a7a0e489192ae66f2b047a403fc24d8d5d698ad4eb6981531ad2fd274c401",
            "1c464b395870845a133680907721e036e2311c29c9c7a7bfca067c553e27eba1"
        ],
        gemini: {
            apiKey: "AIzaSyCzfvtoohLzAgnY90Nu-FJ1e8VKkTP6rzs",
            secret: "f8595c5a0ddbff948c79e72c96786577"
        },
        openai: "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",
        groq: {
            ethereumIDE: "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",
            builders: [
                "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",
                "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",
                "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",
                "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"
            ]
        }
    },
    blockchain: {
        rpc: {
            arbitrum: "http://arb-mainnet.g.alchemy.com",
            tenderly: {
                wss: "wss://mainnet.gateway.tenderly.co/6gYgt4WogpQQlEiNYS0wuR",
                accessToken: "3j5G3liRefIJC0ckwjhbyyjFfu43MdZj"
            },
            websocket: "wss://arb-mainnet.g.alchemy.com/v2/u6zbZm1kPhW_c7J6DN6kF1cE6Yn6t0Gv"
        },
        scanners: {
            arbitrum: "P13AYP6E7XJ6SGDDTHVTTWQH2ZVDSQ1V9P",
            polygon: "216J2UDQ3C7BD36114BVTKYVTHHITYWVKX",
            ethereum: "9EPVNC3JT52NPF8F2ESZUAZ2Y5ZNX6T3UY"
        },
        wallet: {
            privateKey: "0x68267c9893e63f73fa416b30571d47059d72eb10c3d59ef78db66d310d982e65",
            address: "0xccff033a0d9cba5e54312688d6de883823759570"
        },
        zerox: [
            "bbb57dcf-70bf-4545-b5ba-028b7cefd5a2",
            "f4e72178-beef-478b-afab-3a262066553b"
        ]
    },
    services: {
        walletConnect: "e6aacc1a07f9974e970229beb46d448e",
        infura: "e2c4b458e7524ae996cbbd36aa931b70",
        thirdweb: "941edc1df0bc0fe577d144550125484c",
        sanity: "skSeir0UidvVcdzLbN3eROgz0ABXgjR4vjQZX438wfNUNji38w7CXbKdFejklD3F0NZfex0ow6w4u5xR3jcMVB0l7it6IAc2OUv2SbMrHPwpsuSRGzditSD5GqW79ZTWjZ4TagafJauygayHAb0gxSYSjahMAo7fArwp8NpyzojTbAWQG1uF",
        cloudConnect: "247fa414e597da21de5f92b15a54c2ff",
        segment: "Cd4ctU9cBrFdHJFQce5qJ2iJKvwzQlLl",
        netApi: "zWQlXfPENswBEm01qIrHEf5euPlSCruD",
        pinecone: "pcsk_5SB3op_DhiyZjN5sK6JmLBZWryTRDbx76aUkyVnd4xC6LrsHqpg4RBLhgDTcVBYkFXjjq4"
    }
};

// Usage example
export const getApiKey = (
    category: keyof APIConfig,
    service: string,
    subCategory?: string
): string => {
    const config = getConfig();
    if (subCategory) {
        return config[category][service][subCategory];
    }
    return config[category][service];
};

// Helper functions
export const getConfig = (): APIConfig => {
    return config;
};

export const getBlockchainConfig = () => config.blockchain;
export const getAIConfig = () => config.ai;
export const getServicesConfig = () => config.services;

// Validation
export const validateConfig = (): boolean => {
    try {
        const requiredFields: (keyof APIConfig)[] = [
            'vercel',
            'baselime',
            'ai',
            'blockchain',
            'services'
        ];
        
        return requiredFields.every(field => 
            config[field] !== undefined && 
            Object.keys(config[field]).length > 0
        );
    } catch (error) {
        console.error('Config validation failed:', error);
        return false;
    }
};