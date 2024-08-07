// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DspDeploy.s.sol";
import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";
import "../../src/Mocks/MockV3Aggregator.sol";
import "../../src/IWETH.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract StablecoinEngineTest is StdCheats, Test {
    StablecoinEngine public stablecoinEngine;
    Stablecoin public stablecoin;
    address public wethUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 constant MINT_AMOUNT = 10000 * 10 ** 18;
    uint256 startingUserBalance = 100e18;

    uint256 depositAmount = 10e18;

    function setUp() public {
        DeployScript deployScript = new DeployScript();

        (stablecoin, stablecoinEngine, weth, wbtc, wethUsdPriceFeed,) = deployScript.run();

        //mint initial collateral tokens to test addresses thus, weth/wbtc
        if (block.chainid == 31337) {
            // Local chain setup
            vm.prank(alice);
            ERC20Mock(weth).mint(alice, startingUserBalance);

            vm.prank(bob);
            ERC20Mock(wbtc).mint(bob, startingUserBalance);
        } else if (block.chainid == 11155111) {
            console.log("Forked network setup (Sepolia)");
            // Forked network setup (Sepolia)
            hoax(alice, startingUserBalance);
            IWETH9(weth).deposit{value: startingUserBalance}();

            //How de get wbtc on sepolia for a forked sepolia test??
        }
    }

    /*Since we dont have an implemetation yet on how to get wbtc on the sepolia testnet, we
    skip every wbtc test only when running a forked test*/

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

    modifier MintStableCoin(address user) {
        if (block.chainid == 31337 || user == alice) {
            vm.prank(user);
            stablecoinEngine.mintStablecoin(MINT_AMOUNT);
        }
        _;
    }

    modifier skipOnForkedNetwork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testDepositCollateralWithEth() public DepositWethCollateral {
        assertEq(stablecoinEngine.s_collateralBalances(alice, weth), depositAmount);
    }

    function testDepositCollateralWithBtc() public skipOnForkedNetwork DepositWbtcCollateral {
        assertEq(stablecoinEngine.s_collateralBalances(bob, wbtc), depositAmount);
    }

    function testWithdrawCollateralWithEth() public DepositWethCollateral {
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(alice);
        stablecoinEngine.withdrawCollateral(weth, withdrawAmount);
        assertEq(stablecoinEngine.s_collateralBalances(alice, weth), depositAmount - withdrawAmount);
    }

    function testWithdrawCollateralWithBtc() public skipOnForkedNetwork DepositWbtcCollateral {
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(bob);
        stablecoinEngine.withdrawCollateral(wbtc, withdrawAmount);
        assertEq(stablecoinEngine.s_collateralBalances(bob, wbtc), depositAmount - withdrawAmount);
    }

    function testMintStablecoinWithBtc() public skipOnForkedNetwork DepositWbtcCollateral MintStableCoin(bob) {
        assertEq(stablecoin.balanceOf(bob), MINT_AMOUNT);
    }

    function testMintStablecoinWithEth() public DepositWethCollateral MintStableCoin(alice) {
        assertEq(stablecoin.balanceOf(alice), MINT_AMOUNT);
    }

    function testBurnStablecoinWithBtc() public skipOnForkedNetwork DepositWbtcCollateral MintStableCoin(bob) {
        uint256 burnAmount = 40 * 10 ** 18;
        vm.prank(bob);
        stablecoinEngine.burnStablecoin(burnAmount);
        assertEq(stablecoin.balanceOf(bob), MINT_AMOUNT - burnAmount);
    }

    function testBurnStablecoinWithEth() public DepositWethCollateral MintStableCoin(alice) {
        uint256 burnAmount = 40 * 10 ** 18;
        vm.prank(alice);
        stablecoinEngine.burnStablecoin(burnAmount);
        assertEq(stablecoin.balanceOf(alice), MINT_AMOUNT - burnAmount);
    }

    function testLiquidate()
        public
        skipOnForkedNetwork
        DepositWethCollateral
        DepositWbtcCollateral
        MintStableCoin(alice)
        MintStableCoin(bob)
    {
        // Simulate the user's position being under-collateralized by plummeting eth price
        // Check Alice's collateral value before updating the price
        uint256 collateralValueBefore = stablecoinEngine.getTotalCollateralValue(alice);
        console.log("Collateral Value Before:", collateralValueBefore);

        // Update the price feed to simulate a plummeting ETH price
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(500 * 10 ** 8); // Set ETH price to $500

        // Check Alice's collateral value after the price drop
        uint256 collateralValueAfter = stablecoinEngine.getTotalCollateralValue(alice);
        console.log("Collateral Value After:", collateralValueAfter);

        // Ensure Alice's position is now under-collateralized
        assertFalse(stablecoinEngine.isAboveCollateralizationRatio(alice, MINT_AMOUNT));

        // Liquidate Alice's position
        vm.startPrank(bob);
        ERC20Mock(address(stablecoin)).approve(address(stablecoinEngine), MINT_AMOUNT);
        stablecoinEngine.liquidate(alice);
        vm.stopPrank();

        // Verify the user's debt is cleared and liquidator received the collateral
        assertEq(stablecoinEngine.s_stablecoinDebt(alice), 0);
        assertGt(stablecoinEngine.s_collateralBalances(bob, weth), 0);
    }

    function testDepositUnsupportedCollateral() public {
        vm.prank(alice);
        vm.expectRevert("Unsupported collateral token");
        stablecoinEngine.depositCollateral(address(0), depositAmount);
    }

    function testWithdrawMoreThanDeposited() public DepositWethCollateral {
        uint256 withdrawAmount = depositAmount + 1e18;
        vm.prank(alice);
        vm.expectRevert("Insufficient collateral balance");
        stablecoinEngine.withdrawCollateral(weth, withdrawAmount);
    }

    function testWithdrawBelowCollateralizationRatio() public DepositWethCollateral MintStableCoin(alice) {
        uint256 withdrawAmount = depositAmount;
        vm.prank(alice);
        vm.expectRevert("Withdrawal would cause undercollateralization");
        stablecoinEngine.withdrawCollateral(weth, withdrawAmount);
    }

    function testMintStablecoinBelowCollateralizationRatio() public DepositWethCollateral {
        uint256 mintAmount = (depositAmount * 100e18) / 200; // intentionally large mint amount
        vm.prank(alice);
        vm.expectRevert("Below collateralization ratio");
        stablecoinEngine.mintStablecoin(mintAmount);
    }

    function testBurnMoreThanMinted() public DepositWethCollateral MintStableCoin(alice) {
        uint256 burnAmount = MINT_AMOUNT + 1e18;
        vm.prank(alice);
        vm.expectRevert("Exceeds debt amount");
        stablecoinEngine.burnStablecoin(burnAmount);
    }

    function testLiquidateAboveCollateralizationRatio() public DepositWethCollateral MintStableCoin(alice) {
        vm.prank(bob);
        vm.expectRevert("Above collateralization ratio");
        stablecoinEngine.liquidate(alice);
    }

    function testLiquidateWithoutSufficientStablecoinBalance() public DepositWethCollateral MintStableCoin(alice) {
        // Simulate the user's position being under-collateralized by plummeting eth price
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(500 * 10 ** 8); // Set ETH price to $500
        vm.startPrank(bob);
        vm.expectRevert("Insufficient stablecoin balance to cover debt");
        stablecoinEngine.liquidate(alice);
        vm.stopPrank();
    }
}
