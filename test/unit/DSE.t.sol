// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DspDeploy.s.sol";
import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";

contract StablecoinEngineTest is Test {
    StablecoinEngine public stablecoinEngine;
    Stablecoin public stablecoin;
    address public weth;
    address public wbtc;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 startingUserBalance = 100e8;

    uint256 depositAmount = 80e8;

    function setUp() public {
        DeployScript deployScript = new DeployScript();
        (stablecoin, stablecoinEngine, weth, wbtc, , ) = deployScript.run();

        //mint initial collateral tokens to test addresses thus, weth/wbtc
        vm.prank(alice);
        ERC20Mock(weth).mint(alice, startingUserBalance);

        vm.prank(bob);
        ERC20Mock(wbtc).mint(bob, startingUserBalance);
    }

    modifier DepositWethCollateral() {
        vm.startPrank(alice);
        ERC20Mock(weth).approve(address(stablecoinEngine), depositAmount);
        stablecoinEngine.depositCollateral(weth, depositAmount);
        vm.stopPrank();
        _;
    }

    modifier DepositWbtcCollateral() {
        vm.startPrank(bob);
        ERC20Mock(wbtc).approve(address(stablecoinEngine), depositAmount);
        stablecoinEngine.depositCollateral(wbtc, depositAmount);
        vm.stopPrank();
        _;
    }

    function testDepositCollateral() public DepositWethCollateral {
        assertEq(
            stablecoinEngine.s_collateralBalances(alice, weth),
            depositAmount
        );
    }

    function testWithdrawCollateral() public DepositWethCollateral {
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(alice);
        stablecoinEngine.withdrawCollateral(weth, withdrawAmount);
        assertEq(
            stablecoinEngine.s_collateralBalances(alice, weth),
            depositAmount - withdrawAmount
        );
    }

    function testMintStablecoin() public DepositWbtcCollateral {
        uint256 mintAmount = 40;
        // Debugging: Print the price feed values
        uint256 wbtcPrice = stablecoinEngine.getLatestPrice(
            stablecoinEngine.s_wbtcPriceFeed()
        );
        console.log("WBTC Price:", wbtcPrice);

        // Debugging: Print the total collateral value
        uint256 totalCollateralValue = stablecoinEngine.getTotalCollateralValue(
            bob
        );
        console.log("Total Collateral Value (Bob):", totalCollateralValue);

        // Debugging: Print the required collateral value
        uint256 requiredCollateral = (mintAmount *
            stablecoinEngine.s_collateralizationRatio() *
            stablecoinEngine.COLLATERAL_DECIMALS()) / 100;
        console.log("Required Collateral Value (Bob):", requiredCollateral);
        stablecoinEngine.mintStablecoin(mintAmount);
        assertEq(stablecoin.balanceOf(bob), mintAmount);
    }

    // function testBurnStablecoin() public {
    //     uint256 mintAmount = 1000 * 10 ** 18;
    //     uint256 burnAmount = 500 * 10 ** 18;
    //     stablecoinEngine.mintStablecoin(mintAmount);
    //     stablecoinEngine.burnStablecoin(burnAmount);
    //     assertEq(stablecoin.balanceOf(address(this)), mintAmount - burnAmount);
    // }

    // function testLiquidate() public {
    //     // Set up a user with collateral and debt
    //     address user = address(1);

    //     uint256 mintAmount = 500 * 10 ** 18;

    //     stablecoinEngine.depositCollateral(weth, depositAmount);
    //     stablecoinEngine.mintStablecoin(mintAmount);

    //     // Lower the user's collateral to make them under-collateralized
    //     stablecoinEngine.withdrawCollateral(weth, 800 * 10 ** 18);

    //     // Liquidate the user
    //     stablecoinEngine.liquidate(user);

    //     // Verify the user's debt is cleared and liquidator received the collateral
    //     assertEq(stablecoinEngine.s_stablecoinDebt(user), 0);
    //     assertGt(stablecoinEngine.s_collateralBalances(address(this), weth), 0);
    // }
}
