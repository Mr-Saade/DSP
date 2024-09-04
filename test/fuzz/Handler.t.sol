// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";
import "../../src/Mocks/MockV3Aggregator.sol";
import {Test, console} from "forge-std/Test.sol";

contract StablecoinEngineHandler is Test {
    StablecoinEngine public stablecoinEngine;
    Stablecoin public stablecoin;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    // Ghost Variables
    uint256 public totalCollateralDeposited;
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    uint256 public constant MIN_REALISTIC_PRICE = 1e8; // e.g., $1
    uint256 public constant MAX_REALISTIC_PRICE = 1000000000e8; // e.g., $1,000,000,000

    constructor(
        StablecoinEngine _engine,
        Stablecoin _stablecoin,
        address _weth,
        address _wbtc,
        address _wethUsdPriceFeed,
        address _wbtcUsdPriceFeed
    ) {
        stablecoinEngine = _engine;
        stablecoin = _stablecoin;
        weth = ERC20Mock(_weth);
        wbtc = ERC20Mock(_wbtc);
        wethUsdPriceFeed = MockV3Aggregator(_wethUsdPriceFeed);
        wbtcUsdPriceFeed = MockV3Aggregator(_wbtcUsdPriceFeed);
    }

    function depositCollateral(address collateralToken, uint256 collateralAmount) external {
        address boundedCollateralToken = boundCollateralToken(collateralToken);

        uint256 boundedCollateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);
        if (boundedCollateralToken == address(weth)) {
            console.log("Depositing weth...");
            vm.startPrank(msg.sender);
            weth.mint(msg.sender, boundedCollateralAmount);
            weth.approve(address(stablecoinEngine), boundedCollateralAmount);
            stablecoinEngine.depositCollateral(address(weth), boundedCollateralAmount);
            vm.stopPrank();
            totalCollateralDeposited += boundedCollateralAmount;
        } else if (boundedCollateralToken == address(wbtc)) {
            console.log("Depositing wbtc...");
            vm.startPrank(msg.sender);
            wbtc.mint(msg.sender, boundedCollateralAmount);
            wbtc.approve(address(stablecoinEngine), boundedCollateralAmount);
            stablecoinEngine.depositCollateral(address(wbtc), boundedCollateralAmount);
            vm.stopPrank();
            totalCollateralDeposited += boundedCollateralAmount;
        }
    }

    function redeemCollateral(address collateralToken, uint256 withdrawalAmount) external {
        address boundedCollateralToken = boundCollateralToken(collateralToken);
        uint256 userCollateralBalance = stablecoinEngine.s_collateralBalances(msg.sender, boundedCollateralToken);
        if (userCollateralBalance == 0) {
            return;
        }
        uint256 boundedWithdrawalAmount = bound(withdrawalAmount, 1, userCollateralBalance);
        vm.prank(msg.sender);
        stablecoinEngine.withdrawCollateral(boundedCollateralToken, boundedWithdrawalAmount);
        totalCollateralDeposited -= boundedWithdrawalAmount;
    }

    function mintStablecoins(uint256 amount) external {
        console.log("minting stablecoins...");
        vm.assume(amount > 0);
        uint256 totalCollateralValue = stablecoinEngine.getTotalCollateralValue(msg.sender);
        if (totalCollateralValue == 0) {
            return;
        }
        uint256 maxMintableAmount = (totalCollateralValue * 100) / stablecoinEngine.s_collateralizationRatio();

        if (maxMintableAmount == 0) {
            return;
        }

        // Bound the mintable amount to be within the maximum mintable amount
        uint256 boundedAmount = bound(amount, 1, maxMintableAmount);
        vm.prank(msg.sender);
        stablecoinEngine.mintStablecoin(boundedAmount);
    }

    function updatePrice(address priceFeedAddress, uint256 newPrice) external {
        address[2] memory priceFeeds = [address(wethUsdPriceFeed), address(wbtcUsdPriceFeed)];
        uint256 index = uint256(uint160(priceFeedAddress)) % priceFeeds.length;
        address ModdedPriceFeedAddress = priceFeeds[index];
        // Bound the new price to a realistic range
        uint256 boundedPrice = bound(newPrice, MIN_REALISTIC_PRICE, MAX_REALISTIC_PRICE);
        // Convert uint256 to int256 for the price
        int256 price = int256(boundedPrice);

        // Update the price in the corresponding MockV3Aggregator
        if (ModdedPriceFeedAddress == address(wethUsdPriceFeed)) {
            console.log("Weth price feed...");
            wethUsdPriceFeed.updateAnswer(price);
        } else if (ModdedPriceFeedAddress == address(wbtcUsdPriceFeed)) {
            console.log("Wbtc price feed...");
            wbtcUsdPriceFeed.updateAnswer(price);
        }
    }

    function boundCollateralToken(address collateralToken) internal view returns (address) {
        // Use modular operation to bound the collateral token to either WETH or WBTC
        address[2] memory tokens = [address(weth), address(wbtc)];
        uint256 index = uint256(uint160(collateralToken)) % tokens.length;
        return tokens[index];
    }
}
