// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {BurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol";

contract MintTokens is Script {
    function run() external {
        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/ccip/config.json");
        string memory tokenPath = string.concat(root, "/script/ccip/output/deployedToken_", chainName, ".json");

        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, tokenPath, string.concat(".deployedToken_", chainName));

        uint256 amount = HelperUtils.getUintFromJson(vm, configPath, ".tokenAmountToMint");

        address receiverAddress = msg.sender;

        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Invalid amount to mint");

        vm.startBroadcast();

        BurnMintERC20 tokenContract = BurnMintERC20(tokenAddress);

        console.log("Minting", amount, "tokens to", receiverAddress);
        tokenContract.mint(receiverAddress, amount);

        console.log("Waiting for confirmations...");

        vm.stopBroadcast();

        console.log("Minted", amount, "tokens to", receiverAddress);
        console.log("Current balance of receiver is", tokenContract.balanceOf(receiverAddress), tokenContract.symbol());
    }
}
