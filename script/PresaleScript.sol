// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Presale} from "../src/Presale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PresaleToken} from "../src/PresaleToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockStable18 is ERC20 {
    constructor() ERC20("Stable18", "ST18") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
    function decimals() public pure override returns (uint8) { return 18; }
}

contract PresaleScript is Script {
    Presale public presale;
    PresaleToken public presaleToken;
    MockStable18 public mockStable18;

    address _owner = makeAddr("OWNER"); // for both contracts
    address fundsReceiverAddress = makeAddr("FUND_RECEIVER");

    string name = "MyTokenPresale";
    string symbol = "MTPS";

    address public constant usdtAddress = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // Arbitrum
    address public constant usdcAddress = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum
    address public constant dataFeedAddress = 0xe4D040128CFdF03eC221832251caC9b6f0515E3f; // ETH / USD Arbitrum mainnet
    
    // Sale parameters (small for easy testing)
    uint256 public constant maxSellingAmount = 1000 * 1e18;
    uint256[][3] phases; 
    uint256 startingTime = block.timestamp + 100;
    uint256 endingTime = block.timestamp + 5000;

    // function setUp() public {}

    function run() public returns(Presale) {

        phases[0] = [400 * 1e18, 1, block.timestamp + 1000];
        phases[1] = [300 * 1e18, 2, block.timestamp + 1000];
        phases[2] = [300 * 1e18, 3, block.timestamp + 1000];

        vm.startBroadcast(_owner);

        presaleToken = new PresaleToken(name, symbol, _owner);

        mockStable18 = new MockStable18();

        presale = new Presale(
            address(presaleToken),
            _owner, 
            usdtAddress, // address(mockStable18), 
            address(mockStable18),// usdcAddress, 
            fundsReceiverAddress, 
            dataFeedAddress,
            maxSellingAmount,
            phases, 
            startingTime,
            endingTime
        );

        vm.stopBroadcast();

        vm.startPrank(_owner);
        IERC20(address(presaleToken)).approve(address(presale), maxSellingAmount);
        IERC20(address(presaleToken)).transfer(address(presale), maxSellingAmount);

        vm.stopPrank();

        return presale;
    }
}
