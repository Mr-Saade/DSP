# Foundry DeFi Stablecoin
> **Note:** The code will be refactored in future updates to use custom errors instead of string-based reverts for better gas efficiency. This will be implemented once additional features, as outlined in the documentation, are added. Contributions to these features are welcome! Feel free to check the docs for more information on how to get involved.


# About

This protocol is meant to create an exogenous decentralized stablecoin pegged to $1 using Bitcoin and Ethereum as collateral types (specifically wrapped ETH and wrapped BTC) with an overcollateralized ratio mechanism. This DSP will be algorithmic, that is, the protocol will utilize smart contracts to manage minting, burning, and other key functionalities instead of a central authority, hence making it decentralized. Additional features of the protocol include liquidation, insurance fund contributions, and a liquidation discount mechanism, amongst others.

## Key Components:

### 1. ERC20 Stable Coin Contract:
- **Function:** Represents the stablecoin token pegged to $1.
- **Features:**
  - Minting and burning of stablecoins.
  - Transfer and approval mechanisms.
  - Compliance with ERC20 standards.

### 2. Stablecoin Engine Contract:
- **Function:** Controls the logic for stablecoin minting, burning, collateral management, and liquidation.
- **Features:**
  - Algorithmic control of minting and burning based on collateral ratios.
  - Management of collateral deposits and withdrawals (wrapped ETH and wrapped BTC).
  - Liquidation mechanism to ensure system stability and maintain collateral health factor.
  - Overcollateralization enforcement to mitigate risks.
  - User interfaces for interacting with the protocol.

---

## Technical Details:

### 1. Collateral Management:
- **Assets:** Wrapped ETH (wETH) and Wrapped BTC (wBTC).
- **Overcollateralization:** Users must deposit collateral exceeding the value of the stablecoins they wish to mint. For example, if the overcollateralization ratio is 150%, to mint $100 worth of stablecoins, a user must deposit $150 worth of collateral.
- **Liquidation:** If the collateral value falls below a certain threshold, the system will trigger a liquidation call to ensure the stability of the stablecoin.

### 2. Smart Contract Logic:
- **Minting:** Users can mint stablecoins by depositing collateral. The amount of stablecoins minted is determined by the collateral value and overcollateralization ratio.
- **Burning:** Users can burn stablecoins to withdraw their collateral.
- **Liquidation:** The protocol will monitor collateral health and allow and incentivize third parties/users to liquidate undercollateralized positions, ensuring overall system stability.

### 3. Governance and Upgrades:
- **Decentralized Governance:** Implement a governance token for community-driven decisions on protocol parameters and upgrades.
- **Upgradeable Contracts:** Use proxy patterns to allow for future upgrades and improvements without disrupting the existing protocol.


## Risks & Mitigation Strategies/Lessons from Terra Luna Crash:

### **Background on Terra Luna Collapse:**
- TerraUSD (UST) was an algorithmic stablecoin pegged to $1, backed by its sister token Luna.
- A sudden drop in UST's value led to massive redemptions, hyperinflating Luna and causing a death spiral, resulting in a $40 billion loss.

### Key Risks and Mitigation Strategies:

1. **Collateral Price Volatility:**
   - **Risk:** Sharp or immediate price spikes/drops in collateral assets (wETH, wBTC).
   - **Mitigation:**
     - Maintain a high over-collateralization ratio (e.g., 150%).
     - Implement dynamic adjustment of collateralization ratios.
     - Use multiple reliable price oracles and automated rebalancing mechanisms.

2. **Under-collateralization:**
   - **Risk:** Collateral value drops below the required collateralization ratio.
   - **Mitigation:**
     - Implement robust liquidation mechanisms.
     - Monitor collateral health and trigger partial liquidations if needed.
     - Create an insurance fund to cover extreme cases.

3. **Oracle Failure:**
   - **Risk:** Inaccurate price feeds from oracles.
   - **Mitigation:**
     - Use multiple price oracles and implement fallback mechanisms.

4. **Smart Contract Vulnerabilities:**
   - **Risk:** Exploits and bugs.
   - **Mitigation:** Conduct regular audits and use formal verification methods.

5. **Systemic Risks:**
   - **Risk:** Market-wide events affecting collateral assets or DeFi protocols.
   - **Mitigation:** Diversify collateral assets and implement emergency governance protocols.

---

## Addressing Immediate Price Spikes:

**Scenario:** A sharp price spike in collateral assets.

- **Risk:** Extremely over-collateralized positions or under-collateralized positions.
- **Mitigation Strategies:**
  1. Real-time monitoring of collateral prices.
  2. Dynamic adjustment of collateralization ratios.
  3. Automated rebalancing mechanisms.
  4. User notification system for significant price changes.

-------------------------------------------------------------------
     

- [Foundry DeFi Stablecoin](#foundry-defi-stablecoin)
- [About](#about)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)
- [Deployment to a testnet or mainnet](#deployment-to-a-testnet-or-mainnet)
  - [Scripts](#scripts)
  - [Estimate gas](#estimate-gas)
- [Formatting](#formatting)

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`

## Quickstart

```
git clone https://github.com/Mr-Saade/DSP
cd DSP
forge build or forge compile
```

## Testing

```
forge test
```

### Test Coverage

```
forge coverage
```

and for coverage based testing:

```
forge coverage --report debug
```

# Deployment to a testnet or mainnet

1. Setup environment variables

You'll want to set your `SEPOLIA_RPC_URL` and `PRIVATE_KEY` as environment variables. You can add them to a `.env` file.

- `PRIVATE_KEY`: The private key of your account (like from [metamask](https://metamask.io/)). **NOTE:** FOR DEVELOPMENT, PLEASE USE A KEY THAT DOESN'T HAVE ANY REAL FUNDS ASSOCIATED WITH IT.
  - You can [learn how to export it here](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key).
- `SEPOLIA_RPC_URL`: This is url of the sepolia testnet node you're working with. You can get setup with one for free from [Alchemy](https://alchemy.com/?a=673c802981)

Optionally, add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/).

1. Get testnet ETH

Head over to [faucets.chain.link](https://faucets.chain.link/) and get some testnet ETH. You should see the ETH show up in your metamask.

2. Deploy

You can run an anvil chain and deploy to your locally running anvil chain by running the following command:

```
forge script script/DspDeploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

A more safer approach is to run the following command:

```
forge script script/DspDeploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --account 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

The second command will prompt you to enter your passkey to unlock your account using foundry's wallet feature.

## Scripts

Instead of scripts, we can directly use the `cast` command to interact with the contract.

For example, on Sepolia:

1. Get some WETH

```
cast send [contract address] "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

2. Approve the WETH

```
cast send [contract address] "approve(address,uint256)" [contract address] [approve amount] --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

3. Deposit Collateral

```
cast send [contract address] "depositCollateral(address,uint256)" [contract address] [deposit amount] --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Estimate gas

You can estimate how much gas things cost by running:

```
forge snapshot
```

And you'll see an output file called `.gas-snapshot`

# Formatting

To run code formatting:

```
forge fmt
```
