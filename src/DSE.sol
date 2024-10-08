// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./DS.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "forge-std/console.sol";
import "../src/library/PriceFeedsLIb.sol";

/// @title Stablecoin Engine Contract
/// @dev Controls the logic for stablecoin minting, burning, collateral management, and liquidation
contract StablecoinEngine is ReentrancyGuard {
    using PriceFeedChecker for AggregatorV3Interface;

    Stablecoin public s_stablecoin;
    address public s_weth;
    address public s_wbtc;
    uint256 public s_collateralizationRatio; // E.g., 150 means 150%
    uint256 public constant COLLATERAL_DECIMALS = 1e18;
    uint256 public s_liquidationDiscount; // E.g., 10 means 10% discount
    uint256 public s_insuranceFundContribution; // E.g., 2 means 2% contribution
    uint256 public s_insuranceFundBalance;

    AggregatorV3Interface public s_wethPriceFeed;
    AggregatorV3Interface public s_wbtcPriceFeed;

    mapping(address => mapping(address => uint256)) public s_collateralBalances; // User -> (Token -> Amount)
    mapping(address => uint256) public s_stablecoinDebt;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event StablecoinMinted(address indexed user, uint256 amount);
    event StablecoinBurned(address indexed user, uint256 amount);
    event Liquidation(address indexed user, uint256 collateralLiquidatedValue, uint256 debtBurned);
    event InsuranceFundContribution(uint256 amount);

    constructor(
        address stablecoinAddress,
        address weth,
        address wbtc,
        uint256 collateralizationRatio,
        uint256 liquidationDiscount,
        uint256 insuranceFundContribution,
        address wethPriceFeed,
        address wbtcPriceFeed
    ) {
        s_stablecoin = Stablecoin(stablecoinAddress);
        s_weth = weth;
        s_wbtc = wbtc;
        s_collateralizationRatio = collateralizationRatio;
        s_liquidationDiscount = liquidationDiscount;
        s_insuranceFundContribution = insuranceFundContribution;
        s_wethPriceFeed = AggregatorV3Interface(wethPriceFeed);
        s_wbtcPriceFeed = AggregatorV3Interface(wbtcPriceFeed);
    }

    modifier onlyPositive(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    /// @notice Deposit collateral to mint stablecoins
    /// @param token The address of the collateral token (wETH or wBTC)
    /// @param amount The amount of collateral to deposit
    function depositCollateral(address token, uint256 amount) external nonReentrant onlyPositive(amount) {
        require(token == s_weth || token == s_wbtc, "Unsupported collateral token");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        s_collateralBalances[msg.sender][token] += amount;
        emit CollateralDeposited(msg.sender, token, amount);
    }

    /// @notice Withdraw collateral
    /// @param token The address of the collateral token (wETH or wBTC)
    /// @param amount The amount of collateral to withdraw
    function withdrawCollateral(address token, uint256 amount) external nonReentrant onlyPositive(amount) {
        require(token == s_weth || token == s_wbtc, "Unsupported collateral token");
        require(s_collateralBalances[msg.sender][token] >= amount, "Insufficient collateral balance");
        require(
            isAboveCollateralizationRatio(msg.sender, s_stablecoinDebt[msg.sender]), "Below collateralization ratio"
        );

        // Calculate the new total collateral value after withdrawal
        uint256 newCollateralBalance = s_collateralBalances[msg.sender][token] - amount;

        uint256 newTotalCollateralValue = getTotalCollateralValueWithAdjustedBalance(token, newCollateralBalance);

        // Check if the new collateral value meets the required collateralization ratio
        uint256 requiredCollateral = (s_stablecoinDebt[msg.sender] * s_collateralizationRatio) / 100;

        require(newTotalCollateralValue >= requiredCollateral / 1e10, "Withdrawal would cause undercollateralization");

        s_collateralBalances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /// @notice Mint stablecoins
    /// @param amount The amount of stablecoins to mint
    function mintStablecoin(uint256 amount) external nonReentrant onlyPositive(amount) {
        require(
            isAboveCollateralizationRatio(msg.sender, s_stablecoinDebt[msg.sender] + amount),
            "Below collateralization ratio"
        );

        s_stablecoin.mint(msg.sender, amount);
        s_stablecoinDebt[msg.sender] += amount;
        emit StablecoinMinted(msg.sender, amount);
    }

    /// @notice Burn stablecoins
    /// @param amount The amount of stablecoins to burn
    function burnStablecoin(uint256 amount) external nonReentrant onlyPositive(amount) {
        require(s_stablecoinDebt[msg.sender] >= amount, "Exceeds debt amount");
        require(s_stablecoin.balanceOf(msg.sender) >= amount, "Insufficient stablecoin balance");

        s_stablecoin.burn(msg.sender, amount);
        s_stablecoinDebt[msg.sender] -= amount;
        emit StablecoinBurned(msg.sender, amount);
    }

    /// @notice Liquidate under-collateralized positions
    /// @param user The user to liquidate
    function liquidate(address user) external nonReentrant {
        require(!isAboveCollateralizationRatio(user, s_stablecoinDebt[user]), "Above collateralization ratio");

        uint256 totalDebtBurned = s_stablecoinDebt[user];

        // Liquidator must have enough stablecoins to cover the user's debt
        require(s_stablecoin.balanceOf(msg.sender) >= totalDebtBurned, "Insufficient stablecoin balance to cover debt");

        // Check if liquidator is not already under-collateralized
        require(
            isAboveCollateralizationRatio(msg.sender, s_stablecoinDebt[msg.sender]),
            "Liquidator already below collateralization ratio"
        );

        // Pre-calculate collateral values before state changes
        uint256 wethCollateralAmount = s_collateralBalances[user][s_weth];
        uint256 wbtcCollateralAmount = s_collateralBalances[user][s_wbtc];

        uint256 totalCollateralLiquidatedWeth = 0;
        uint256 totalCollateralLiquidatedWbtc = 0;
        uint256 totalInsuranceContribution = 0;

        if (wethCollateralAmount > 0) {
            uint256 liquidationDiscountAmount = (wethCollateralAmount * s_liquidationDiscount) / 100;
            uint256 insuranceContributionAmount = (wethCollateralAmount * s_insuranceFundContribution) / 100;
            uint256 amountToLiquidator = wethCollateralAmount - liquidationDiscountAmount - insuranceContributionAmount;

            totalCollateralLiquidatedWeth += amountToLiquidator;
            totalInsuranceContribution += insuranceContributionAmount;
        }

        if (wbtcCollateralAmount > 0) {
            uint256 liquidationDiscountAmount = (wbtcCollateralAmount * s_liquidationDiscount) / 100;
            uint256 insuranceContributionAmount = (wbtcCollateralAmount * s_insuranceFundContribution) / 100;
            uint256 amountToLiquidator = wbtcCollateralAmount - liquidationDiscountAmount - insuranceContributionAmount;

            totalCollateralLiquidatedWbtc += amountToLiquidator;
            totalInsuranceContribution += insuranceContributionAmount;
        }

        // Calculate the total value of the collateral liquidated
        uint256 totalCollateralLiquidatedWethValue =
            (totalCollateralLiquidatedWeth * getLatestPrice(s_wethPriceFeed)) / COLLATERAL_DECIMALS;
        uint256 totalCollateralLiquidatedWbtcValue =
            (totalCollateralLiquidatedWbtc * getLatestPrice(s_wbtcPriceFeed)) / COLLATERAL_DECIMALS;

        // Sum the total collateral values
        uint256 totalCollateralLiquidatedValue = totalCollateralLiquidatedWethValue + totalCollateralLiquidatedWbtcValue;

        // Simulate post-liquidation state to check if liquidator remains above the collateralization ratio
        uint256 newLiquidatorCollateralValue = getTotalCollateralValue(msg.sender) + totalCollateralLiquidatedValue;

        uint256 newLiquidatorDebt = s_stablecoinDebt[msg.sender] + totalDebtBurned;
        require(
            ((newLiquidatorCollateralValue * 1e10) / newLiquidatorDebt) >= (s_collateralizationRatio / 100),
            "Liquidator below collateralization ratio"
        );

        // Execute state changes after all checks
        s_stablecoin.transferFrom(msg.sender, address(this), totalDebtBurned);
        s_stablecoin.burn(address(this), totalDebtBurned);

        if (wethCollateralAmount > 0) {
            IERC20(s_weth).transfer(
                msg.sender,
                wethCollateralAmount
                    - (wethCollateralAmount * (s_liquidationDiscount + s_insuranceFundContribution)) / 100
            );
            s_collateralBalances[msg.sender][s_weth] += wethCollateralAmount
                - (wethCollateralAmount * (s_liquidationDiscount + s_insuranceFundContribution)) / 100;
            s_collateralBalances[user][s_weth] = 0;
        }

        if (wbtcCollateralAmount > 0) {
            IERC20(s_wbtc).transfer(
                msg.sender,
                wbtcCollateralAmount
                    - (wbtcCollateralAmount * (s_liquidationDiscount + s_insuranceFundContribution)) / 100
            );
            s_collateralBalances[msg.sender][s_wbtc] += wbtcCollateralAmount
                - (wbtcCollateralAmount * (s_liquidationDiscount + s_insuranceFundContribution)) / 100;
            s_collateralBalances[user][s_wbtc] = 0;
        }

        s_stablecoinDebt[user] = 0;
        s_stablecoinDebt[msg.sender] += totalDebtBurned;
        s_insuranceFundBalance += totalInsuranceContribution;

        emit Liquidation(user, totalCollateralLiquidatedValue, totalDebtBurned);
        emit InsuranceFundContribution(totalInsuranceContribution);
    }

    /// @notice Check if a user's position is above the collateralization ratio
    /// @param user The user to check
    /// @param debt The user's debt
    /// @return True if above collateralization ratio, false otherwise
    function isAboveCollateralizationRatio(address user, uint256 debt) public view returns (bool) {
        if (debt == 0) return true;

        uint256 collateralValue = getTotalCollateralValue(user);
        uint256 adjustedCollateralValueWithDecimalsPrecision = collateralValue * 1e10;

        uint256 requiredCollateral = (debt * s_collateralizationRatio) / 100;

        return adjustedCollateralValueWithDecimalsPrecision >= requiredCollateral;
    }

    /// @notice Get the total collateral value of a user
    /// @param user The user to check
    /// @return The total collateral value in USD using Chainlink price feeds
    function getTotalCollateralValue(address user) public view returns (uint256) {
        uint256 wethValue = (s_collateralBalances[user][s_weth] * getLatestPrice(s_wethPriceFeed)) / COLLATERAL_DECIMALS;
        uint256 wbtcValue = (s_collateralBalances[user][s_wbtc] * getLatestPrice(s_wbtcPriceFeed)) / COLLATERAL_DECIMALS;

        return wethValue + wbtcValue;
    }

    /// @notice Get the latest price from a Chainlink price feed
    /// @param priceFeed The Chainlink price feed address
    /// @return The latest price
    function getLatestPrice(AggregatorV3Interface priceFeed) public view returns (uint256) {
        priceFeed.checkPriceFreshness();
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");
        return uint256(price);
    }

    /// @notice Get the collateral value of a user
    /// @param collateralAmount The amount of collateral
    /// @param priceFeed The Chainlink price feed
    /// @return The collateral value in USD
    function getCollateralValue(uint256 collateralAmount, AggregatorV3Interface priceFeed)
        public
        view
        returns (uint256)
    {
        uint256 price = getLatestPrice(priceFeed);
        uint256 collateralValue = (collateralAmount * price) / 1e18;
        return collateralValue;
    }

    /// @notice Get the total collateral value of a user with adjusted balance
    /// @param token The collateral token address
    /// @param adjustedBalance The adjusted balance
    /// @return The total collateral value in USD
    function getTotalCollateralValueWithAdjustedBalance(address token, uint256 adjustedBalance)
        internal
        view
        returns (uint256)
    {
        uint256 wethValue;
        uint256 wbtcValue;

        if (token == s_weth) {
            wethValue = (adjustedBalance * getLatestPrice(s_wethPriceFeed)) / COLLATERAL_DECIMALS;
        } else if (token == s_wbtc) {
            wbtcValue = (adjustedBalance * getLatestPrice(s_wbtcPriceFeed)) / COLLATERAL_DECIMALS;
        } else {
            revert("Unsupported collateral token");
        }

        return wethValue + wbtcValue;
    }
}
