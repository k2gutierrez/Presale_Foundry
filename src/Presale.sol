// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IAggregator } from "./IAggregator.sol";

contract Presale is Ownable {

    error Presale__UserIsBlackListed();
    error Presale__TransferFailed();
    error Presale__PresaleNotStartedYetOrIsFinished();
    error Presale__PresaleNotEnded();
    error Presale__IncorrectToken();
    error Presale__SoldOut();

    using SafeERC20 for IERC20;

    address public s_saleTokenAddress;
    address public s_usdtAddress; 
    address public s_usdcAddress;
    address public s_fundsReceiverAddress;
    address public s_dataFeedAddress;

    uint256 public s_maxSellingAmount;
    uint256 public s_startingTime;
    uint256 public s_endingTime;
    uint256 public s_totalSold;
    uint256 public s_currentPhase;

    uint256[][3] public s_phases;

    mapping(address user => bool blackListed) public s_isBlackListed;
    mapping (address user => uint256 tokensBalance) public s_userTokenBalance;

    event TokenBuy(address user, uint256 amount);
    
    constructor(
        address _saleTokenAddress,
        address _owner, 
        address usdtAddress, 
        address usdcAddress, 
        address fundsReceiverAddress, 
        address dataFeedAddress,
        uint256 maxSellingAmount,
        uint256[][3] memory phases, 
        uint256 startingTime,
        uint256 endingTime
    ) Ownable(_owner) {
        s_saleTokenAddress = _saleTokenAddress;
        s_usdtAddress = usdtAddress;
        s_usdcAddress = usdcAddress;
        s_fundsReceiverAddress = fundsReceiverAddress;
        s_maxSellingAmount = maxSellingAmount;
        s_phases = phases;
        s_startingTime = startingTime;
        s_endingTime = endingTime;
        s_dataFeedAddress = dataFeedAddress;

        require(s_endingTime > s_startingTime, "Incorrect Presale times");

        //IERC20(s_saleTokenAddress).safeTransferFrom(msg.sender, address(this), s_maxSellingAmount);
    }

    //////// Only Owner functions ////////
    /**
     * Function used to blacklist a user
     * @param _user address of the blacklisted user
     */
    function blackList(address _user) external onlyOwner {
        s_isBlackListed[_user] = true;
    }

    /**
     * Function to remove address from blacklist
     * @param _user address to remove blacklist
     */
    function removeBlackList(address _user) external onlyOwner {
        s_isBlackListed[_user] = false;
    }

    function emergencyWithdraw(address _tokenAddress, uint256 _amount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }

    function emergencyEthWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) revert Presale__TransferFailed(); 
    }

    //////// General functions ////////
    /**
     * Functions used to buy tokens with stable coin
     * @param _tokenUsedToBuy address of the token used to buy
     * @param _amount Amount of the tokens the user wants to purchase
     */
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

    function claim() external {
        if (block.timestamp < s_endingTime) revert Presale__PresaleNotEnded();

        uint256 amount = s_userTokenBalance[msg.sender];
        delete s_userTokenBalance[msg.sender];

        IERC20(s_saleTokenAddress).safeTransfer(msg.sender, amount);
    }

    function _checkCurrentPhase(uint256 _amount) private returns(uint256 phase) {
    if (s_currentPhase < 2 &&
        (s_totalSold + _amount >= s_phases[s_currentPhase][0] ||
         block.timestamp >= s_phases[s_currentPhase][2]))
    {
        s_currentPhase++;
        phase = s_currentPhase;
    } else {
        phase = s_currentPhase;
    }
}

    function getEtherPrice() public view returns (uint256) {
        (,int256 price,,,) = IAggregator(s_dataFeedAddress).latestRoundData();
        uint256 rawPrice = uint256(price);
        if (rawPrice < 1e12) {
            return rawPrice * 1e10;
        }
        return rawPrice;
    }

    function checkUserBlackList(address _user) external view returns(bool status) {
        status = s_isBlackListed[_user];   
    }

}
