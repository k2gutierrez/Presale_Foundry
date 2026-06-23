// SPDX-License-Identifier: MIT
// forge test -vvvv --fork-url https://arb1.arbitrum.io/rpc
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Presale} from "../src/Presale.sol";
import {PresaleScript} from "../script/PresaleScript.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PresaleTest is Test {
    Presale public presale;

    address owner;
    address fundsReceiverAddress;
    address user1 = makeAddr("USER1");
    address user2 = makeAddr("USER2");
    address user3 = makeAddr("USER3");
    address USDT;
    address USDC; // mock with 18 decimals
    address saleToken;

    // parameters to check constructor:
    address public constant ETH_DATA_FEED = 0xe4D040128CFdF03eC221832251caC9b6f0515E3f;

    // Sale parameters (small for easy testing)
    uint256 public constant MAX_SELLING = 1000 * 1e18;       // 100 tokens
    uint256 public constant PHASE0_CAP = 400 * 1e18;
    uint256 public constant PHASE0_PRICE = 1;                // 1 token per 1 USD worth
    uint256 public constant PHASE1_CAP = 300 * 1e18;
    uint256 public constant PHASE1_PRICE = 2;
    uint256 public constant PHASE2_CAP = 300 * 1e18;
    uint256 public constant PHASE2_PRICE = 3;
    uint256 startingTime = block.timestamp + 100;
    uint256 endingTime = block.timestamp + 5000;

    function setUp() public {
        PresaleScript deployer = new PresaleScript();
        presale = deployer.run();
        fundsReceiverAddress = presale.s_fundsReceiverAddress();
        owner = presale.owner();
        USDT = presale.s_usdtAddress();
        USDC = presale.s_usdcAddress();
        saleToken = presale.s_saleTokenAddress();

        // Give test users some ETH and stablecoins (fork cheat)
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        deal(USDC, user1, 1000 * 1e18, true);     // USDC has 6 decimals
        deal(USDC, user2, 1000 * 1e18, true);

        deal(USDT, user1, 2000 * 1e6, true);
        deal(USDT, user2, 2000 * 1e6, true);
        
    }

    // Constructor tests
    function testConstructorRevertIfEndTimeBeforeStartTime() public {
        uint256[][3] memory phases;
        vm.expectRevert("Incorrect Presale times");
        new Presale(saleToken, owner, USDT, USDC,
                    owner, ETH_DATA_FEED, MAX_SELLING, phases,
                    block.timestamp + 100, block.timestamp + 50);
    }

    function testConstructorStateVariables() public view {
        assertEq(presale.s_saleTokenAddress(), address(saleToken));
        assertEq(presale.s_usdtAddress(), USDT);
        assertEq(presale.s_usdcAddress(), USDC);
        assertEq(presale.s_fundsReceiverAddress(), fundsReceiverAddress);
        assertEq(presale.s_dataFeedAddress(), ETH_DATA_FEED);
        assertEq(presale.s_maxSellingAmount(), MAX_SELLING);
        assertEq(presale.s_startingTime(), startingTime);
        assertEq(presale.s_endingTime(), endingTime);
        assertEq(presale.s_totalSold(), 0);
        assertEq(presale.s_currentPhase(), 0);
        assertEq(IERC20(saleToken).balanceOf(address(presale)), MAX_SELLING);
    }

    function testBlackListRevertsNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        presale.blackList(user2);
    }

    // Only Owner Functions
    function testBlackList() public {
        bool user1Before = presale.checkUserBlackList(user1);

        vm.prank(owner);
        presale.blackList(user1);

        bool user1After = presale.checkUserBlackList(user1);


        assertNotEq(user1Before, user1After);
        assert(user1Before == false);
        assert(user1After == true);
    }

    function testRemoveBlackListRevertsNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        presale.removeBlackList(user2);
    }

    function testRemoveBlackList() public {
        bool user1Before = presale.checkUserBlackList(user1);
        vm.prank(owner);
        presale.blackList(user1);
        bool user1After = presale.checkUserBlackList(user1);

        vm.prank(owner);
        presale.removeBlackList(user1);

        bool user1AfetRemoveBlacklist = presale.checkUserBlackList(user1);

        assertNotEq(user1Before, user1After);
        assert(user1Before == false);
        assert(user1After == true);
        assert(user1AfetRemoveBlacklist == false);
        assertEq(user1Before, user1AfetRemoveBlacklist);
    }

    function testEmergencyWithdrawRevertsOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        presale.emergencyWithdraw(USDC, 1);
    }

    function testEmergencyWithdrawTransfersTokens() public {
        // Send some USDC to presale so the contract has USDC balance
        deal(USDT, address(presale), 500 * 1e18);
        uint256 ownerBefore = IERC20(USDT).balanceOf(owner);
        vm.prank(owner);
        presale.emergencyWithdraw(USDT, 200 * 1e18);
        assertEq(IERC20(USDT).balanceOf(owner), ownerBefore + 200 * 1e18);
    }

    function testEmergencyEthWithdrawRevertsOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        presale.emergencyEthWithdraw();
    }

    function testEmergencyEthWithdrawTransfersEth() public {
        // Send ETH to presale contract for balance to withdraw
        vm.deal(address(presale), 5 ether);
        uint256 ownerBefore = owner.balance;
        vm.prank(owner);
        presale.emergencyEthWithdraw();
        assertEq(owner.balance, ownerBefore + 5 ether);
    }

    function testBuyWithStableRevertsIfBlacklisted() public {
        vm.prank(owner);
        presale.blackList(user1);
        vm.warp(startingTime + 1);
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__UserIsBlackListed.selector);
        presale.buyWithStable(USDT, 10 * 1e18);
    }

    function testBuyWithStableRevertsIfNotStarted() public {
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__PresaleNotStartedYetOrIsFinished.selector);
        presale.buyWithStable(USDT, 10 * 1e18);
    }

    function testBuyWithStableRevertSIfEnded() public {
        vm.warp(endingTime + 1);
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__PresaleNotStartedYetOrIsFinished.selector);
        presale.buyWithStable(USDT, 10 * 1e18);
    }

    function testBuyWithStableRevertSIfIncorrectToken() public {
        vm.warp(startingTime + 1);
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__IncorrectToken.selector);
        presale.buyWithStable(ETH_DATA_FEED, 10 * 1e18);
    }

    function testBuyWithStableSuccess18Decimals() public {
        vm.warp(startingTime + 1);
        uint256 buyAmount = 20 * 1e18;
        uint256 expectedTokens = buyAmount / PHASE0_PRICE;
        console2.log("expectedTokens: ", expectedTokens);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(presale), buyAmount);
        presale.buyWithStable(USDC, buyAmount);
        vm.stopPrank();

        assertEq(presale.s_userTokenBalance(user1), expectedTokens);
        assertEq(presale.s_totalSold(), expectedTokens);
        assertEq(IERC20(USDC).balanceOf(fundsReceiverAddress), buyAmount);
    }

    function testBuyWithStableSuccess6DecimalsUSDT() public {

        vm.warp(startingTime + 1);
        uint256 buyAmount = 20 * 1e6;  // 20 USDC
        uint256 expectedTokens = 20 * 1e18;
        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), buyAmount);
        presale.buyWithStable(USDT, buyAmount);
        vm.stopPrank();
        console2.log("User balance: ", presale.s_userTokenBalance(user1));
        assertEq(presale.s_userTokenBalance(user1), expectedTokens);
        assertEq(IERC20(USDT).balanceOf(fundsReceiverAddress), buyAmount);
    }

    function testBuyWithStablePhaseTransitionByAmount() public {
        // Phase0 cap 400 tokens, price 1
        vm.warp(startingTime + 1);
        uint256 buyAmount = 350 * 1e6;
        
        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), buyAmount);
        presale.buyWithStable(USDT, buyAmount);
        vm.stopPrank();
        
        assertEq(presale.s_currentPhase(), 0);
        uint256 purchaseAmount2 = 51 * 1e6;
        vm.startPrank(user2);
        IERC20(USDT).approve(address(presale), purchaseAmount2);
        presale.buyWithStable(USDT, purchaseAmount2);
        vm.stopPrank();

        assertEq(presale.s_currentPhase(), 1);
    }

    function testBuyWithStablePhaseTransitionByTime() public {
        vm.warp(startingTime + 1);
        // Buy a little to set totalSold
        uint256 amountToPurchase = 1 * 1e6;

        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), amountToPurchase);
        presale.buyWithStable(USDT, amountToPurchase);
        vm.stopPrank();

        assertEq(presale.s_currentPhase(), 0);
        // Warp past phase0 end time
        vm.warp(presale.s_phases(0, 2) + 1);
        // Next purchase triggers phase transition because time > phase0[2]
        vm.startPrank(user2);
        IERC20(USDT).approve(address(presale), amountToPurchase);
        presale.buyWithStable(USDT, amountToPurchase);
        vm.stopPrank();
        assertEq(presale.s_currentPhase(), 1);
    }

    function testBuyWithStableSoldOut() public {
        vm.warp(startingTime + 1);
        uint256 amountToPurchase = 2000 * 1e6;
        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), amountToPurchase);
        presale.buyWithStable(USDT, 400 * 1e6); // phase0 cap hit
        console2.log("Tokens balance1: ", presale.s_totalSold());
        presale.buyWithStable(USDT, 700 * 1e6); // phase1 cap hit
        console2.log("Tokens balance2: ", presale.s_totalSold());
        presale.buyWithStable(USDT, 600 * 1e6); // phase2 cap hit, total = 100
        console2.log("Tokens balance3: ", presale.s_totalSold());
        vm.stopPrank();
        // Now any further buy should revert
        vm.startPrank(user2);
        IERC20(USDT).approve(address(presale), 600 * 1e6);
        vm.expectRevert(Presale.Presale__SoldOut.selector);
        presale.buyWithStable(USDT, 600 * 1e6);
        vm.stopPrank();
    }

    function testBuyWithEtherRevertsIfBlacklisted() public {
        vm.prank(owner);
        presale.blackList(user1);
        vm.warp(startingTime + 1);
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__UserIsBlackListed.selector);
        presale.buyWithEther{value: 0.1 ether}();
    }

    function testBuyWithEtherRevertsIfNotStarted() public {
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__PresaleNotStartedYetOrIsFinished.selector);
        presale.buyWithEther{value: 0.1 ether}();
    }

    function testBuyWithEtherRevertsIfEnded() public {
        vm.warp(endingTime + 1);
        vm.prank(user1);
        vm.expectRevert(Presale.Presale__PresaleNotStartedYetOrIsFinished.selector);
        presale.buyWithEther{value: 0.1 ether}();
    }

    function testBuyWithEtherSuccessAndPhaseTransition() public {
        vm.warp(startingTime + 1);
        uint256 ethPrice = presale.getEtherPrice();
        uint256 etherAmount = 0.01 ether;
        uint256 usdValue = etherAmount * ethPrice / 1e18;
        uint256 expectedTokensPhase0 = usdValue / PHASE0_PRICE; // price=1

        vm.prank(user1);
        presale.buyWithEther{value: etherAmount}();
        assertEq(presale.s_userTokenBalance(user1), expectedTokensPhase0);

        // Buy enough to reach phase0 cap
        uint256 remainingPhase0 = PHASE0_CAP - presale.s_totalSold();
        uint256 usdNeeded = remainingPhase0 * PHASE0_PRICE;   // no /1e18
        uint256 ethNeeded = usdNeeded * 1e18 / ethPrice + 1;  // +1 wei to exceed cap
        vm.prank(user2);
        presale.buyWithEther{value: ethNeeded}();
        assertEq(presale.s_currentPhase(), 1);
    }

    function testBuyWithEtherRevertsSoldOut() public {
        vm.warp(startingTime + 1);
        // 17226000000000000000000
        uint256 hugeEther = 10 ether;
        vm.prank(user1);
        // This will likely push over max, so revert
        vm.expectRevert(Presale.Presale__SoldOut.selector);
        presale.buyWithEther{value: hugeEther}();
    }

    function testClaimRevertIfNotEnded() public {
        vm.warp(startingTime + 1);
        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), 10 * 1e6);
        presale.buyWithStable(USDT, 10 * 1e6);
        vm.stopPrank();
        vm.expectRevert(Presale.Presale__PresaleNotEnded.selector);
        presale.claim();
    }

    function testClaimTransfersTokensAndZeroesBalance() public {
        vm.warp(startingTime + 1);
        vm.startPrank(user1);
        IERC20(USDT).approve(address(presale), 10 * 1e6);
        presale.buyWithStable(USDT, 10 * 1e6);
        vm.stopPrank();
        uint256 balance = presale.s_userTokenBalance(user1);
        assertGt(balance, 0);
        // Warp past end
        vm.warp(endingTime + 1);
        uint256 tokensBefore = IERC20(saleToken).balanceOf(user1);
        vm.prank(user1);
        presale.claim();
        assertEq(IERC20(saleToken).balanceOf(user1), tokensBefore + balance);
        assertEq(presale.s_userTokenBalance(user1), 0);
    }

    function testGetEtherPriceReturnsNonZero() public view {
        uint256 price = presale.getEtherPrice();
        assert(price > 0);
    }

}
