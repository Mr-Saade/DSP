// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DspDeploy.s.sol";
import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";
import "../../src/Mocks/MockV3Aggregator.sol";

contract StablecoinEngineTest is Test {
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

    modifier MintStableCoin(address user) {
        vm.prank(user);
        stablecoinEngine.mintStablecoin(MINT_AMOUNT);
        _;
    }

    function testDepositCollateral() public DepositWethCollateral {
        assertEq(stablecoinEngine.s_collateralBalances(alice, weth), depositAmount);
    }

    function testWithdrawCollateral() public DepositWethCollateral {
        uint256 withdrawAmount = depositAmount / 2;
        vm.prank(alice);
        stablecoinEngine.withdrawCollateral(weth, withdrawAmount);
        assertEq(stablecoinEngine.s_collateralBalances(alice, weth), depositAmount - withdrawAmount);
    }

    function testMintStablecoin() public DepositWbtcCollateral MintStableCoin(bob) {
        assertEq(stablecoin.balanceOf(bob), MINT_AMOUNT);
    }

    function testBurnStablecoin() public DepositWbtcCollateral MintStableCoin(bob) {
        uint256 burnAmount = 40 * 10 ** 18;
        vm.prank(bob);
        stablecoinEngine.burnStablecoin(burnAmount);
        assertEq(stablecoin.balanceOf(bob), MINT_AMOUNT - burnAmount);
    }

    function testLiquidate()
        public
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
        vm.prank(bob);
        stablecoinEngine.liquidate(alice);

        // Verify the user's debt is cleared and liquidator received the collateral
        assertEq(stablecoinEngine.s_stablecoinDebt(alice), 0);
        assertGt(stablecoinEngine.s_collateralBalances(bob, weth), 0);
    }
}
