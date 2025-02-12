// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
/*
Contract SimpleArbitrage
Deployed on Polygon with 0xbb16f309BA429273d3bBa69711FecFAfd4f4d3Ac

// Constructor parameters
address AAVE_POOL_ADDRESS_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
address UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

// Example tokens
address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
address WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

// Common pool fees
uint24 FEE_LOW = 500;     // 0.05%
uint24 FEE_MEDIUM = 3000; // 0.3%
uint24 FEE_HIGH = 10000;  // 1%
*/
// IERC20 Interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Ownable Interface
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(msg.sender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
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

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
}

contract SimpleArbitrage is IFlashLoanSimpleReceiver, Ownable {
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;
    ISwapRouter public immutable swapRouter;

    constructor(address _addressesProvider, address _swapRouter) {
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressesProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        swapRouter = ISwapRouter(_swapRouter);
    }

    struct SwapVars {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amountOutMinimum;
        uint256 amountIn;
    }

    function performInitialSwap(SwapVars memory vars) internal returns (uint256) {
        IERC20(vars.tokenIn).approve(address(swapRouter), vars.amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: vars.tokenIn,
            tokenOut: vars.tokenOut,
            fee: vars.fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: vars.amountIn,
            amountOutMinimum: vars.amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    function performReverseSwap(
        SwapVars memory vars,
        uint256 amountOut,
        uint256 repayAmount
    ) internal returns (uint256) {
        IERC20(vars.tokenOut).approve(address(swapRouter), amountOut);

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: vars.tokenOut,
            tokenOut: vars.tokenIn,
            fee: vars.fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: repayAmount,
            amountInMaximum: amountOut,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactOutputSingle(params);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be Pool");

        // Decode params
        (address tokenOut, uint24 fee, uint256 amountOutMinimum) = abi.decode(
            params,
            (address, uint24, uint256)
        );

        SwapVars memory vars = SwapVars({
            tokenIn: asset,
            tokenOut: tokenOut,
            fee: fee,
            amountOutMinimum: amountOutMinimum,
            amountIn: amount
        });

        // Perform initial swap
        uint256 amountOut = performInitialSwap(vars);

        // Calculate repayment amount
        uint256 repayAmount = amount + premium;

        // Perform reverse swap
        performReverseSwap(vars, amountOut, repayAmount);

        // Approve repayment
        IERC20(asset).approve(address(POOL), repayAmount);

        // Handle profit
        uint256 finalBalance = IERC20(asset).balanceOf(address(this));
        if (finalBalance > repayAmount) {
            IERC20(asset).transfer(owner(), finalBalance - repayAmount);
        }

        return true;
    }

    function requestFlashLoan(
        address _asset,
        uint256 _amount,
        address _tokenOut,
        uint24 _fee,
        uint256 _amountOutMinimum
    ) external onlyOwner {
        bytes memory params = abi.encode(_tokenOut, _fee, _amountOutMinimum);
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

    receive() external payable {}
}