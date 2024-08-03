//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IWETH9 {
    function deposit() external payable;

    function transfer(address dst, uint256 wad) external returns (bool);

    function approve(address guy, uint256 wad) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);
}
