pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./interfaces/AaveLendingPoolV2.sol";
import "./interfaces/AaveLendingPoolProviderV2.sol";
import "./interfaces/IWETHGateway.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IQuoter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/aave/FlashLoanReceiverBase.sol";

contract strategy is FlashLoanReceiverBase {

    using SafeERC20 for IERC20;
    address public lendingPoolAddress = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9; // mainnet
    // address public lendingPoolAddress = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf; // polygon

    address public constant ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Mainnet
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // Mainnet
    address public constant aaveToken = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // Mainnet
    
    AaveLendingPoolProviderV2 public provider;
    bool public initialized;
    address public underlying;
    address public aWBTC;
    uint256 public val;

    constructor(address _WBTC, address _aWBTC, ILendingPoolAddressesProvider _addressesProvider) public FlashLoanReceiverBase(_addressesProvider) {
        
        underlying = _WBTC;
        aWBTC = _aWBTC;

        provider = AaveLendingPoolProviderV2(address(_addressesProvider));
        
        IERC20(underlying).safeApprove(provider.getLendingPool(), type(uint256).max);
        IERC20(WETH).safeApprove(provider.getLendingPool(), type(uint256).max);

        IERC20(underlying).safeApprove(ROUTER, type(uint256).max);
        IERC20(WETH).safeApprove(ROUTER, type(uint256).max);    
    }
                                                                         
    receive() external payable {}

    function depositInVault(uint256 amount) external {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        depositAmount();
        getAAVEUserDetails();
        borrowAndRebalance();
    }

    function borrowAndRebalance() internal {
        uint256 borrowedAmount = borrowAmount();
        while (borrowedAmount > 0) {
            uniswapperV3(0, WETH, underlying, borrowedAmount, 0);
            depositAmount();
            borrowedAmount = borrowAmount();
        }
    }

    function depositAmount() internal {
        AaveLendingPoolV2 lendingPool = AaveLendingPoolV2(provider.getLendingPool());
        lendingPool.deposit(underlying, IERC20(underlying).balanceOf(address(this)), address(this), 0); // 29 -> referral
    }

    function borrowAmount() internal returns(uint256) {
        (,,uint256 borrowedAmount,,,) = AaveLendingPoolV2(provider.getLendingPool()).getUserAccountData(address(this));
        if(borrowedAmount <= 3e18) {
            borrowedAmount = 0;
        } else {
            AaveLendingPoolV2(provider.getLendingPool()).borrow(WETH, borrowedAmount, 2, 0, address(this));
        }
        return borrowedAmount;
    }

    function uniswapperV3(uint256 swapFlag, address _token0, address _token1, uint256 borrowedAmount, uint256 _amountout) internal {
        if(swapFlag == 0) {
            ISwapRouter.ExactInputSingleParams memory fromWethToWbtcParams =
            ISwapRouter.ExactInputSingleParams(
                _token0,
                _token1,
                10000,
                address(this),
                block.timestamp,
                borrowedAmount,
                0,
                0
            );
            ISwapRouter(ROUTER).exactInputSingle(fromWethToWbtcParams);
            uint256 wbtcTokensUniswapper = IERC20(_token1).balanceOf(address(this));
            console.log('WbtcTokens--: ', wbtcTokensUniswapper);
            val = wbtcTokensUniswapper;
        } else {
            ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams(
                _token0,
                _token1,
                10000,
                address(this),
                block.timestamp,
                _amountout,
                IERC20(WBTC).balanceOf(address(this)),
                0
            );
            ISwapRouter(ROUTER).exactOutputSingle(params);
        }
    }

    function repay(uint totalDebtETH) internal {
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).safeApprove(provider.getLendingPool(), 0);
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).safeApprove(provider.getLendingPool(), type(uint256).max);
        AaveLendingPoolV2(provider.getLendingPool()).repay(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, totalDebtETH, 2, address(this));
    }

    function withdrawWBTC(uint256 a) internal {
        AaveLendingPoolV2(provider.getLendingPool()).withdraw(underlying, a, address(this));
    }

    function flashLoan(address asset) external {
        (,uint256 totalDebtETH,,,,) = getAAVEUserDetails();
        console.log('totalDebtETH-: ', totalDebtETH);

        address receiver = address(this);

        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint[] memory amounts = new uint[](1);
        amounts[0] = totalDebtETH;

        // 0 = no debt, 1 = stable, 2 = variable
        // 0 = pay all loaned
        uint[] memory modes = new uint[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);

        bytes memory params = ""; // extra data to pass abi.encode(...)
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiver,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint[] calldata amounts,
        uint[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        repay(amounts[0]);
        (uint256 a,,,,,) = getAAVEUserDetails();
        uint256 aWBTCBal = IERC20(aWBTC).balanceOf(address(this));
        withdrawWBTC(aWBTCBal);
        uint amountOwing = amounts[0] + premiums[0];
        uniswapperV3(1, WBTC, WETH, 0, amountOwing);
        IERC20(assets[0]).approve(address(LENDING_POOL), amountOwing);
        // And repay Aave here automatically
        return true;
    }


    function getAAVEUserDetails() public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 a,uint256 b, uint256 c,uint256 d,uint256 e,uint256 f) = 
                    AaveLendingPoolV2(provider.getLendingPool()).getUserAccountData(address(this));
        return (a, b, c, d, e, f);
    }
}