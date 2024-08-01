// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {MockV3Aggregator} from "../src/Mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../src/Mocks/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public networkConfig;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    address public constant SEPOLIA_WETH_ADDRESS = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant SEPOLIA_WBTC_ADDRESS = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public constant SEPOLIA_WETHUSD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_WBTCUSD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    // Mock parameters
    uint8 public constant MOCK_DECIMALS = 8;
    int256 public constant INITIAL_WETH_PRICE = 2000e8;
    int256 public constant INITIAL_WBTC_PRICE = 40000e8;
    string public constant WETH_NAME = "Wrapped Ether";
    string public constant WETH_SYMBOL = "WETH";
    string public constant WBTC_NAME = "Wrapped Bitcoin";
    string public constant WBTC_SYMBOL = "WBTC";
    uint256 public constant INITIAL_MOCK_BALANCE = 10000e18;

    constructor(uint256 chainId) {
        if (chainId == LOCAL_CHAIN_ID) {
            networkConfig = getLocalNetworkConfig();
        } else if (chainId == SEPOLIA_CHAIN_ID) {
            networkConfig = getSepoliaNetworkConfig();
        } else {
            revert("Unsupported network");
        }
    }

    function getLocalNetworkConfig() internal returns (NetworkConfig memory) {
        address wethUsdPriceFeed = deployMockPriceFeed(INITIAL_WETH_PRICE);
        address wbtcUsdPriceFeed = deployMockPriceFeed(INITIAL_WBTC_PRICE);
        address weth = deployMockERC20(WETH_NAME, WETH_SYMBOL);
        address wbtc = deployMockERC20(WBTC_NAME, WBTC_SYMBOL);
        return NetworkConfig(wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, DEFAULT_ANVIL_PRIVATE_KEY);
    }

    function getSepoliaNetworkConfig() internal view returns (NetworkConfig memory) {
        return NetworkConfig(
            SEPOLIA_WETHUSD_PRICE_FEED,
            SEPOLIA_WBTCUSD_PRICE_FEED,
            SEPOLIA_WETH_ADDRESS,
            SEPOLIA_WBTC_ADDRESS,
            vm.envUint("SEPOLIA_PRIVATE_KEY")
        );
    }

    function deployMockPriceFeed(int256 initialPrice) internal returns (address) {
        return address(new MockV3Aggregator(MOCK_DECIMALS, initialPrice));
    }

    function deployMockERC20(string memory name, string memory symbol) internal returns (address) {
        return address(new ERC20Mock(name, symbol, msg.sender, INITIAL_MOCK_BALANCE));
    }
}
