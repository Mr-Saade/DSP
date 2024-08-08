// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";
import {Test, console} from "forge-std/Test.sol";

contract StablecoinEngineHandler is Test {
    StablecoinEngine public stablecoinEngine;
    Stablecoin public stablecoin;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    // Ghost Variables
    uint256 public totalCollateralDeposited;
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(StablecoinEngine _engine, Stablecoin _stablecoin, address _weth, address _wbtc) {
        stablecoinEngine = _engine;
        stablecoin = _stablecoin;
        weth = ERC20Mock(_weth);
        wbtc = ERC20Mock(_wbtc);
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
        vm.assume(userCollateralBalance > 0); // Ensure user has some collateral
        uint256 boundedWithdrawalAmount = bound(withdrawalAmount, 1, userCollateralBalance);
        vm.prank(msg.sender);
        stablecoinEngine.withdrawCollateral(boundedCollateralToken, boundedWithdrawalAmount);
        totalCollateralDeposited -= boundedWithdrawalAmount;
    }

    function mintStablecoins(uint256 amount) external {
        console.log("minting stablecoins...");
        vm.assume(amount > 0);
        uint256 boundedAmount = bound(amount, 1, MAX_DEPOSIT_SIZE);
        vm.prank(msg.sender);
        stablecoinEngine.mintStablecoin(boundedAmount);
    }

    function boundCollateralToken(address collateralToken) internal view returns (address) {
        // Use modular operation to bound the collateral token to either WETH or WBTC
        address[2] memory tokens = [address(weth), address(wbtc)];
        uint256 index = uint256(uint160(collateralToken)) % tokens.length;
        return tokens[index];
    }
}
