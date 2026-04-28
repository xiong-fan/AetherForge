// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {BurnMintTokenPool} from "@chainlink/contracts-ccip/pools/BurnMintTokenPool.sol";
import {BurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol";
import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract DeployBurnMintTokenPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer address:", deployer);
        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory deployedTokenPath = string.concat(root, "/script/ccip/output/deployedToken_", chainName, ".json");

        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, deployedTokenPath, string.concat(".deployedToken_", chainName));

        HelperConfig helperConfig = new HelperConfig();
        (, address router, address rmnProxy,,,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(router != address(0) && rmnProxy != address(0), "Router or RMN Proxy not defined for this network");

        IBurnMintERC20 token = IBurnMintERC20(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        BurnMintTokenPool tokenPool = new BurnMintTokenPool(
            token,
            18,
            new address[](0),
            rmnProxy,
            router
        );

        console.log("Burn & Mint token pool deployed to:", address(tokenPool));

        BurnMintERC20(tokenAddress).grantMintAndBurnRoles(address(tokenPool));
        console.log("Granted mint and burn roles to token pool:", address(tokenPool));

        vm.stopBroadcast();

        string memory jsonObj = "internal_key";
        string memory key = string(abi.encodePacked("deployedTokenPool_", chainName));
        string memory finalJson = vm.serializeAddress(jsonObj, key, address(tokenPool));

        string memory poolFileName = string(abi.encodePacked("./script/ccip/output/deployedTokenPool_", chainName, ".json"));
        console.log("Writing deployed token pool address to file:", poolFileName);
        vm.writeJson(finalJson, poolFileName);
    }
}
