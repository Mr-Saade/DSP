/* Library to check for stale prices from the chainlink pricefeeds*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

library PriceFeedChecker {
    uint256 public constant HEARTBEAT_INTERVAL = 3 hours;

    /// @notice Check if the price feed data is fresh
    /// @param priceFeed The Chainlink price feed to check
    function checkPriceFreshness(AggregatorV3Interface priceFeed) internal view {
        (,,, uint256 updatedAt,) = priceFeed.latestRoundData();
        console.log("block.timestamp:", block.timestamp);
        console.log("updatedAt:", updatedAt);
        console.log("Time difference:", block.timestamp - updatedAt);
        require(block.timestamp - updatedAt <= HEARTBEAT_INTERVAL, "Price feed data is stale!");
    }
}
