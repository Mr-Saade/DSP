// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Stablecoin Contract
/// @dev Represents the stablecoin token pegged to $1
contract Stablecoin is ERC20, Ownable {
    constructor(address _owner) ERC20("Stablecoin", "STC") Ownable(_owner) {}

    /// @notice Mint new stablecoins
    /// @param to The address to receive the stablecoins
    /// @param amount The amount of stablecoins to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Burn stablecoins
    /// @param from The address from which stablecoins will be burned
    /// @param amount The amount of stablecoins to burn
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
