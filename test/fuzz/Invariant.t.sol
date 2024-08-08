// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import "../../script/DspDeploy.s.sol";
import "../../src/DS.sol";
import "../../src/DSE.sol";
import "../../src/Mocks/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {StablecoinEngineHandler} from "./Handler.t.sol";

contract StablecoinEngineInvariantTest is StdInvariant, Test {
    StablecoinEngine public stablecoinEngine;
    Stablecoin public stablecoin;
    StablecoinEngineHandler public handler;

    address public weth;
    address public wbtc;

    function setUp() public {
        DeployScript deployScript = new DeployScript();

        (stablecoin, stablecoinEngine, weth, wbtc,,) = deployScript.run();
        handler = new StablecoinEngineHandler(stablecoinEngine, stablecoin, weth, wbtc);
        targetContract(address(handler));
    }

    function invariant_TotalCirculatingStablecoinsMustBeLessThanTotalCollateralValue() public view {
        uint256 totalWethCollateral = ERC20Mock(weth).balanceOf(address(stablecoinEngine));
        uint256 totalWbtcCollateral = ERC20Mock(wbtc).balanceOf(address(stablecoinEngine));
        uint256 totalWethCollateralValue =
            stablecoinEngine.getCollateralValue(totalWethCollateral, stablecoinEngine.s_wethPriceFeed());
        uint256 totalWbtcCollateralValue =
            stablecoinEngine.getCollateralValue(totalWbtcCollateral, stablecoinEngine.s_wbtcPriceFeed());

        uint256 totalCollateralValue = totalWethCollateralValue + totalWbtcCollateralValue;
        uint256 totalStablecoinSupply = stablecoin.totalSupply();

        // Total stablecoins in circulation should be less than the total collateral value due to overcollateralization ratio

        assert(totalStablecoinSupply <= totalCollateralValue * 1e10);
        assertEq(handler.totalCollateralDeposited(), totalWethCollateral + totalWbtcCollateral);
    }
}
