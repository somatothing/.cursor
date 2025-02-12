// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
/*
Contract TriangularArbitrage
address _contractPolygon = 0xaFcd6e2f4bD3C8bCa7efC418218938973a7581FD;    // Polygon Contract Deployment
address _addressesProvider = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;  // AAVE V3 Pool Address Provider
address _swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;         // Uniswap V3 SwapRouter
address _priceOracle = 0xb023e699F5a33916Ea823A16485e259257cA8Bd1;        // AAVE Price Oracle
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
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IPriceOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract TriangularArbitrage is IFlashLoanSimpleReceiver, Ownable {
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;
    ISwapRouter public immutable swapRouter;
    IPriceOracle public immutable priceOracle;

    struct Route {
        address[] tokens;
        uint24[] fees;
    }

    mapping(bytes32 => Route) private routes;
    address[] public tokensList;

    event ArbitrageExecuted(uint256 profit, bytes32 routeId);

    constructor(address _addressesProvider, address _swapRouter, address _priceOracle) {
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressesProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        swapRouter = ISwapRouter(_swapRouter);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function getRoute(bytes32 routeId) external view returns (address[] memory tokens, uint24[] memory fees) {
        Route storage route = routes[routeId];
        return (route.tokens, route.fees);
    }

    function addRoute(bytes32 routeId, address[] calldata _tokens, uint24[] calldata _fees) external onlyOwner {
        require(_tokens.length == 4 && _fees.length == 3, "Invalid route parameters");
        routes[routeId] = Route(_tokens, _fees);
    }

    function addToken(address token) external onlyOwner {
        tokensList.push(token);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be lending pool");
        
        // Decode params
        (bytes32 routeId, uint256[] memory minAmountsOut) = abi.decode(params, (bytes32, uint256[]));
        
        Route memory route = routes[routeId];
        require(route.tokens.length == 4, "Invalid route");

        // Approve the SwapRouter to spend the borrowed asset
        IERC20(asset).approve(address(swapRouter), amount);

        // Perform the triangular arbitrage
        bytes memory path = abi.encodePacked(
            route.tokens[0], route.fees[0],
            route.tokens[1], route.fees[1],
            route.tokens[2], route.fees[2],
            route.tokens[3]
        );
        
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: minAmountsOut[2]
        });

        uint256 amountOut = swapRouter.exactInput(swapParams);

        // Ensure we have enough to repay the flash loan
        uint256 amountOwed = amount + premium;
        require(amountOut >= amountOwed, "Arbitrage didn't yield enough profit");

        // Approve the Pool contract allowance to *pull* the owed amount
        IERC20(asset).approve(address(POOL), amountOwed);

        // Transfer the profit to the contract owner
        uint256 profit = amountOut - amountOwed;
        IERC20(asset).transfer(owner(), profit);

        emit ArbitrageExecuted(profit, routeId);

        return true;
    }

    function requestFlashLoan(
        address _asset,
        uint256 _amount,
        bytes32 _routeId,
        uint256[] calldata _minAmountsOut
    ) external onlyOwner {
        require(_minAmountsOut.length == 3, "Invalid min amounts out");
        
        address receiverAddress = address(this);
        bytes memory params = abi.encode(_routeId, _minAmountsOut);
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            _asset,
            _amount,
            params,
            referralCode
        );
    }

    function checkArbitrageOpportunity(bytes32 routeId) external view returns (bool, uint256) {
        Route memory route = routes[routeId];
        require(route.tokens.length == 4, "Invalid route");

        uint256 startAmount = 1e18; // 1 token
        uint256 price1 = priceOracle.getAssetPrice(route.tokens[0]);
        uint256 price2 = priceOracle.getAssetPrice(route.tokens[1]);
        uint256 price3 = priceOracle.getAssetPrice(route.tokens[2]);
        uint256 price4 = priceOracle.getAssetPrice(route.tokens[3]);

        uint256 amount1to2 = (startAmount * price1) / price2;
        uint256 amount2to3 = (amount1to2 * price2) / price3;
        uint256 amount3to4 = (amount2to3 * price3) / price4;

        bool profitable = amount3to4 > startAmount;
        uint256 profit = profitable ? amount3to4 - startAmount : 0;

        return (profitable, profit);
    }

    function getTokenLiquidity(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(POOL));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}
}