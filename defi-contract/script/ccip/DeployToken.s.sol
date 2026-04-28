// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {BurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol";

contract DeployToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/ccip/config.json");

        string memory name = HelperUtils.getStringFromJson(vm, configPath, ".BnMToken.name");
        string memory symbol = HelperUtils.getStringFromJson(vm, configPath, ".BnMToken.symbol");
        uint8 decimals = uint8(HelperUtils.getUintFromJson(vm, configPath, ".BnMToken.decimals"));
        uint256 maxSupply = HelperUtils.getUintFromJson(vm, configPath, ".BnMToken.maxSupply");
        uint256 preMint = HelperUtils.getUintFromJson(vm, configPath, ".BnMToken.preMint");


        
        vm.startBroadcast(deployerPrivateKey);

        // address deployer = msg.sender;
        address tokenAddress;

        BurnMintERC20 token = new BurnMintERC20(name, symbol, decimals, maxSupply, preMint);
        tokenAddress = address(token);
        console.log("Deployed BurnMintERC20 at:", tokenAddress);

        BurnMintERC20(tokenAddress).grantMintAndBurnRoles(deployer);
        console.log("Granted mint and burn roles to:", deployer);

        vm.stopBroadcast();

        string memory jsonObj = "internal_key";
        string memory key = string(abi.encodePacked("deployedToken_", chainName));
        string memory finalJson = vm.serializeAddress(jsonObj, key, tokenAddress);

        string memory fileName = string(abi.encodePacked("./script/ccip/output/deployedToken_", chainName, ".json"));
        console.log("Writing deployed token address to file:", fileName);

        vm.writeJson(finalJson, fileName);
    }
}
