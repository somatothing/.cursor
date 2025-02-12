// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/*
Contract FlashLoanArbitrage
Deployed on Polygon with address: 0x12151839d0D1d5F9d5DC3E2D4C6C1B8155666f9e
Swap address: Uniswap V3 0xE592427A0AEce92De3Edee1F18E0157C05861564
Provider Address Aave V3 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
*/

import "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    address payable owner;
    ISwapRouter public immutable swapRouter;

    constructor(address _addressProvider, address _swapRouter) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = payable(msg.sender);
        swapRouter = ISwapRouter(_swapRouter);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // This contract now has the funds requested.
        // Perform arbitrage operations here
        
        // Decode params
        (address tokenIn, address tokenOut, uint24 fee, uint256 amountOutMinimum) = abi.decode(params, (address, address, uint24, uint256));
        
        // Approve the SwapRouter to spend the borrowed asset
        IERC20(asset).approve(address(swapRouter), amount);

        // Perform the swap
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: asset,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(swapParams);

        // Perform reverse swap to repay the flash loan
        IERC20(tokenOut).approve(address(swapRouter), amountOut);
        ISwapRouter.ExactOutputSingleParams memory reverseSwapParams = ISwapRouter.ExactOutputSingleParams({
            tokenIn: tokenOut,
            tokenOut: asset,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: amount + premium,
            amountInMaximum: amountOut,
            sqrtPriceLimitX96: 0
        });
        uint256 amountIn = swapRouter.exactOutputSingle(reverseSwapParams);

        // Approve the Pool contract allowance to *pull* the owed amount
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount, address _tokenOut, uint24 _fee, uint256 _amountOutMinimum) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = abi.encode(_token, _tokenOut, _fee, _amountOutMinimum);
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    receive() external payable {}
}
