<div align="center">
  <h1>🚀 Multi-Phase Token Presale Application</h1>
  <p><b>A robust DeFi token presale layer supporting stablecoin and native ETH purchases via Chainlink Oracles</b></p>
</div>

## 📖 About the Project

The **Multi-Phase Token Presale Application** is a production-ready Web3 Smart Contract project built with **Solidity `0.8.30`** and thoroughly tested using the **Foundry** framework. At its core, the project provides a secure, automated mechanism for Web3 projects to raise funds by selling an ERC20 token across configurable phases with distinct price points and token caps. 

This architecture is ideal for DAOs, decentralized protocols, or Web3 startups looking to execute a transparent token generation event (TGE) or initial coin offering (ICO). It offers flexibility by allowing users to purchase presale tokens using either native Ether (ETH) or standard stablecoins (USDT/USDC).

**Key Technical Highlights:**
* **Solidity `0.8.30`:** Leveraging up-to-date compiler features for maximum security and gas efficiency.
* **OpenZeppelin Contracts:** Utilizing standard `IERC20`, `SafeERC20`, and `Ownable` implementations to prevent common attack vectors and handle secure access control.
* **Chainlink Integration:** Implements `IAggregator` to fetch real-time ETH/USD price data, ensuring accurate token distribution for native ETH purchases.
* **Foundry Framework:** Complete with high-speed testing, state assertions, and mainnet-fork simulations via Arbitrum RPC.

---

## ⚙️ How It Works

The `Presale` contract manages a tiered token sale. The contract owner configures multiple sale phases, each defined by a token cap, a price, and a timestamp. When users buy tokens with stablecoins or ETH, the contract calculates the correct amount of presale tokens to allocate based on the active phase's price. 

If a purchase exceeds the current phase's cap or time limit, the contract automatically transitions to the next phase. Tokens are not distributed immediately; instead, user balances are recorded in a mapping. Once the global presale end time is reached, users can invoke a claim function to withdraw their purchased tokens to their wallets.

### Architecture Diagram

![Project Diagram](./images/diagram.png)

[Presale.sol](./src/Presale.sol) - Main Application Logic

[IAggregator.sol](./src/IAggregator.sol) - Chainlink Price Feed Interface

[PresaleToken.sol](./src/PresaleToken.sol) - ERC20 Token Contract

---

## 💻 Technical Docs

The primary interaction points of the application handle stablecoin purchases, ETH purchases, and the post-sale claim process. The contract strictly manages state to prevent purchases outside of the active presale window and includes security features like a user blacklist.

### buyWithStable
Allows users to purchase presale tokens using approved stablecoins (USDC or USDT).

```solidity
    function buyWithStable(address _tokenUsedToBuy, uint256 _amount) external {
        if (s_isBlackListed[msg.sender]) revert Presale__UserIsBlackListed();
        if (block.timestamp < s_startingTime || block.timestamp > s_endingTime) revert Presale__PresaleNotStartedYetOrIsFinished();
        if (_tokenUsedToBuy != s_usdtAddress && _tokenUsedToBuy != s_usdcAddress) revert Presale__IncorrectToken();

        uint256 tokenAmountToReceive = _amount * 10**(18 - ERC20(_tokenUsedToBuy).decimals()) / s_phases[s_currentPhase][1];
        _checkCurrentPhase(tokenAmountToReceive);

        s_totalSold += tokenAmountToReceive;
        if (s_totalSold > s_maxSellingAmount) revert Presale__SoldOut();

        s_userTokenBalance[msg.sender] += tokenAmountToReceive;

        IERC20(_tokenUsedToBuy).safeTransferFrom(msg.sender, s_fundsReceiverAddress, _amount);
        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }
```

### buyWithEther
Allows users to purchase presale tokens using native ETH, utilizing a Chainlink data feed to determine the USD equivalent value.

```Solidity
    function buyWithEther() external payable {
        if (s_isBlackListed[msg.sender]) revert Presale__UserIsBlackListed();
        if (block.timestamp < s_startingTime || block.timestamp > s_endingTime) revert Presale__PresaleNotStartedYetOrIsFinished();
        
        uint256 usdValue = msg.value * getEtherPrice() / 1e18;
        uint256 tokenAmountToReceive = usdValue / s_phases[s_currentPhase][1];

        _checkCurrentPhase(tokenAmountToReceive);

        s_totalSold += tokenAmountToReceive;
        if (s_totalSold > s_maxSellingAmount) revert Presale__SoldOut();

        s_userTokenBalance[msg.sender] += tokenAmountToReceive;

        (bool success, ) = s_fundsReceiverAddress.call{value: msg.value}("");
        if (!success) revert Presale__TransferFailed();

        emit TokenBuy(msg.sender, tokenAmountToReceive);
    }
```

### claim
Allows users to withdraw their purchased tokens after the presale timeframe has completely concluded.

```Solidity
    function claim() external {
        if (block.timestamp < s_endingTime) revert Presale__PresaleNotEnded();
        
        uint256 amount = s_userTokenBalance[msg.sender];
        delete s_userTokenBalance[msg.sender];

        IERC20(s_saleTokenAddress).safeTransfer(msg.sender, amount);
    }
```

🚀 Execution Example
Here is a step-by-step example of how a user interacts with the Presale contract to buy tokens and later claim them.

Step 1: Setup & Deploy. The Owner deploys the contract, configuring the token addresses (USDC, USDT, Presale Token), the Chainlink Aggregator address, and the phase parameters (caps, prices, and timestamps). The owner also transfers the total supply of presale tokens into the contract.

Step 2: User Approval. A User wants to invest 500 USDC. Because USDC is an ERC20 standard token, the user must first call approve() on the USDC contract directly, granting the Presale contract permission to move their funds.

Step 3: Execute Purchase. The user calls buyWithStable(USDC_ADDRESS, 500000000) (scaling for 6 decimals). The contract verifies the time, calculates the tokens owed based on the current phase price, updates the user's internal balance, and transfers the 500 USDC directly to the project's designated fundsReceiverAddress.

Step 4: Phase Transition. Another user buys a massive amount of tokens using ETH. The contract checks _checkCurrentPhase() and recognizes that the total sold amount has surpassed the Phase 0 cap. It automatically increments s_currentPhase to Phase 1, meaning subsequent buyers will pay the Phase 1 price.

Step 5: Claiming. The presale reaches its s_endingTime. The user from Step 2 returns and calls claim(). The contract zeroes out their internal balance and transfers their purchased ERC20 presale tokens to their wallet.

⬆️ Installation
Bash
- forge install OpenZeppelin/openzeppelin-contracts foundry-rs/forge-std

🧪 Testing
Bash
- forge test -vvvv --fork-url [https://arb1.arbitrum.io/rpc](https://arb1.arbitrum.io/rpc)

📊 Coverage
Bash
- forge coverage --fork-url [https://arb1.arbitrum.io/rpc](https://arb1.arbitrum.io/rpc)

📜 Contract Address
(Provide deployed contract addresses here upon mainnet/testnet launch)