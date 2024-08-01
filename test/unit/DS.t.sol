// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import "../../script/DspDeploy.s.sol";
import "../../src/DS.sol";
import "../../src/DSE.sol";

contract StablecoinTest is Test {
    Stablecoin stablecoin;
    StablecoinEngine stablecoinEngine;
    address public stablecoinEngineAddress;
    uint256 public constant MINT_AMOUNT = 1000e18;
    uint256 public constant BURN_AMOUNT = 500e18;

    function setUp() public {
        DeployScript deployScript = new DeployScript();
        (stablecoin, stablecoinEngine,,,,) = deployScript.run();
        stablecoinEngineAddress = address(stablecoinEngine);
    }

    function testMintStablecoinByOwner() public {
        address to = address(1);

        // Mint by owner (StablecoinEngine)
        vm.prank(stablecoinEngineAddress);
        stablecoin.mint(to, MINT_AMOUNT);

        assertEq(stablecoin.balanceOf(to), MINT_AMOUNT);
    }

    function testBurnStablecoinByOwner() public {
        // Mint by owner (StablecoinEngine)
        vm.startPrank(stablecoinEngineAddress);

        stablecoin.mint(stablecoinEngineAddress, MINT_AMOUNT);

        // Burn by owner (StablecoinEngine)

        stablecoin.burn(stablecoinEngineAddress, BURN_AMOUNT);
        vm.stopPrank();

        assertEq(stablecoin.balanceOf(stablecoinEngineAddress), MINT_AMOUNT - BURN_AMOUNT);
    }

    function testMintStablecoinByNonOwner() public {
        address to = address(1);

        // Try to mint by non-owner (should revert)

        vm.expectRevert();
        stablecoin.mint(to, MINT_AMOUNT);
    }

    function testBurnStablecoinByNonOwner() public {
        address from = address(1);

        // Mint by owner (StablecoinEngine)
        vm.prank(stablecoinEngineAddress);
        stablecoin.mint(from, MINT_AMOUNT);

        // Try to burn by non-owner (should revert)
        vm.prank(from);
        vm.expectRevert();
        stablecoin.burn(from, BURN_AMOUNT);
    }
}
