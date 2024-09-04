// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {Stablecoin} from "../src/DS.sol";
import {StablecoinEngine} from "../src/DSE.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployScript is Script {
    // Constants
    uint256 public constant COLLATERALIZATION_RATIO = 150; // 150%
    uint256 public constant LIQUIDATION_DISCOUNT = 10; // 10%
    uint256 public constant INSURANCE_FUND_CONTRIBUTION = 2; // 2%

    function run()
        external
        returns (
            Stablecoin,
            StablecoinEngine,
            address,
            address,
            address,
            address
        )
    {
        uint256 chainId = block.chainid;
        HelperConfig helperConfig = new HelperConfig(chainId);
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            uint256 deployerPrivateKey
        ) = helperConfig.networkConfig();
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        Stablecoin stablecoin = new Stablecoin(deployer);
        StablecoinEngine stablecoinEngine = new StablecoinEngine(
            address(stablecoin),
            weth,
            wbtc,
            COLLATERALIZATION_RATIO,
            LIQUIDATION_DISCOUNT,
            INSURANCE_FUND_CONTRIBUTION,
            wethUsdPriceFeed,
            wbtcUsdPriceFeed
        );

        // Transferring ownership of Stablecoin to the StablecoinEngine
        stablecoin.transferOwnership(address(stablecoinEngine));

        vm.stopBroadcast();

        return (
            stablecoin,
            stablecoinEngine,
            weth,
            wbtc,
            wethUsdPriceFeed,
            wbtcUsdPriceFeed
        );
    }
}
