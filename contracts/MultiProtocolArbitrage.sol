// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/* 
Contract MultiProtocolArbitrage
Deployed on Polygon with address: 0x1431de8Bf08379ba2641CE01E9264769866B6c1D

Addresses:
const arbitrage = await MultiProtocolArbitrage.deploy(
    "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb", // AAVE V3 Pool Address Provider
    "0xE592427A0AEce92De3Edee1F18E0157C05861564", // Uniswap V3 Router
    "0xBA12222222228d8Ba445958a75a0704d566BF2C8"  // Balancer V2 Vault
);
*/
// IERC20 Interface instead of importing OpenZeppelin
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Flash Loan interfaces
interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

// Uniswap interfaces
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

// Balancer interfaces
interface IAsset {
    // Empty interface used by Balancer
}

interface IVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }
    
    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }
    
    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }
    
    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);
}

contract MultiProtocolArbitrage is IFlashLoanSimpleReceiver {
    address payable owner;
    IPool public immutable POOL;
    ISwapRouter public immutable uniswapRouter;
    IVault public immutable balancerVault;

    enum Protocol { Uniswap, Balancer, Curve }

    constructor(
        address _addressProvider,
        address _uniswapRouter,
        address _balancerVault
    ) {
        owner = payable(msg.sender);
        POOL = IPool(IPoolAddressesProvider(_addressProvider).getPool());
        uniswapRouter = ISwapRouter(_uniswapRouter);
        balancerVault = IVault(_balancerVault);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be lending pool");

        (
            address tokenMiddle,
            address tokenFinal,
            uint24[3] memory fees,
            uint256[3] memory minAmountsOut,
            Protocol[3] memory protocols
        ) = abi.decode(params, (address, address, uint24[3], uint256[3], Protocol[3]));

        uint256 amountOut = amount;
        for (uint i = 0; i < 3; i++) {
            amountOut = executeSwap(
                i == 0 ? asset : (i == 1 ? tokenMiddle : tokenFinal),
                i == 2 ? asset : (i == 1 ? tokenFinal : tokenMiddle),
                amountOut,
                fees[i],
                minAmountsOut[i],
                protocols[i]
            );
        }

        require(amountOut >= amount + premium, "Insufficient profit");

        IERC20(asset).approve(address(POOL), amount + premium);

        uint256 profit = amountOut - (amount + premium);
        IERC20(asset).transfer(owner, profit);

        return true;
    }

    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee,
        uint256 minAmountOut,
        Protocol protocol
    ) internal returns (uint256) {
        if (protocol == Protocol.Uniswap) {
            return executeUniswapSwap(tokenIn, tokenOut, amountIn, fee, minAmountOut);
        } else if (protocol == Protocol.Balancer) {
            return executeBalancerSwap(tokenIn, tokenOut, amountIn, minAmountOut);
        } else {
            revert("Unsupported protocol");
        }
    }

    function executeUniswapSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee,
        uint256 minAmountOut
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        return uniswapRouter.exactInputSingle(params);
    }

    function executeBalancerSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(address(balancerVault), amountIn);

        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: bytes32(0), // You need to specify the correct pool ID
            kind: IVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(tokenIn),
            assetOut: IAsset(tokenOut),
            amount: amountIn,
            userData: ""
        });

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        return balancerVault.swap(singleSwap, funds, minAmountOut, block.timestamp);
    }

    function requestFlashLoan(
        address _asset,
        uint256 _amount,
        address _tokenMiddle,
        address _tokenFinal,
        uint24[3] memory _fees,
        uint256[3] memory _minAmountsOut,
        Protocol[3] memory _protocols
    ) external onlyOwner {
        bytes memory params = abi.encode(_tokenMiddle, _tokenFinal, _fees, _minAmountsOut, _protocols);
        POOL.flashLoanSimple(
            address(this),
            _asset,
            _amount,
            params,
            0
        );
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    receive() external payable {}
}