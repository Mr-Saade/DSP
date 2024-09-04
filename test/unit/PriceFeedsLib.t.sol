// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/library/PriceFeedsLIb.sol";
import "../../src/Mocks/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeedCheckerTest is Test {
    using PriceFeedChecker for AggregatorV3Interface;

    MockV3Aggregator mockPriceFeed;
    AggregatorV3Interface priceFeed;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITAL_PRICE = 2000 ether;

    function setUp() public {
        mockPriceFeed = new MockV3Aggregator(DECIMALS, INITAL_PRICE);
        priceFeed = AggregatorV3Interface(address(mockPriceFeed));
    }

    function testCheckPriceFreshness_RecentUpdate() public {
        // Arrange: The mock price feed's `updateAnswer` method will set the `latestTimestamp` to the current time
        mockPriceFeed.updateAnswer(2000 * 10 ** 8);

        // Act and Assert: Check that the price feed is considered fresh
        priceFeed.checkPriceFreshness(); // Should not revert
    }

    /* Due to the way we programmed our priceFeeds library the expectRevert might not work as expected on the priceFeed.checkPriceFreshness();
     when the price is stale. This is because the expectRevert expects the checkPriceFreshness() to revert upon immediate call
     but according to our library , the reverts happens after calling another function on the aggragator before running a checker for the 
     revert. When we comment the expect revert line out, the test then shows a revert at the latter.*/

    function testCheckPriceFreshness_StaleUpdate() public {
        mockPriceFeed.updateAnswer(2000 * 10 ** 8);
        console.log("Current timestamp before warp:", block.timestamp);
        vm.warp(block.timestamp + 4 hours + 1 seconds);
        vm.roll(block.number + 1);
        console.log("New timestamp after warp:", block.timestamp);
        // vm.expectRevert("Price feed data is stale!");
        priceFeed.checkPriceFreshness(); // Should revert
    }

    function testCheckPriceFreshness_ExactHeartbeatInterval() public {
        mockPriceFeed.updateAnswer(2000 * 10 ** 8);

        vm.warp(block.timestamp + 3 hours);
        vm.roll(block.number + 1);
        priceFeed.checkPriceFreshness();
    }

    function testCheckPriceFreshness_JustBelowHeartbeatInterval() public {
        mockPriceFeed.updateAnswer(2000 * 10 ** 8);

        vm.warp(block.timestamp + 3 hours - 1 seconds);
        vm.roll(block.number + 1);
        priceFeed.checkPriceFreshness();
    }

    function testCheckPriceFreshness_JustAboveHeartbeatInterval() public {
        mockPriceFeed.updateAnswer(2000 * 10 ** 8);

        vm.warp(block.timestamp + 3 hours + 1 seconds);
        vm.roll(block.number + 1);
        // vm.expectRevert("Price feed data is stale!");
        priceFeed.checkPriceFreshness(); // Should revert
    }
}
