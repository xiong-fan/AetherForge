// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract AcceptAdminRole is Script {
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
        (,,, address tokenAdminRegistry,,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(tokenAdminRegistry != address(0), "TokenAdminRegistry is not defined for this network");

        vm.startBroadcast(deployerPrivateKey);

        address signer = deployer;

        TokenAdminRegistry tokenAdminRegistryContract = TokenAdminRegistry(tokenAdminRegistry);

        // 这里不懂整个CCIP注册流程时会很疑惑：为什么getTokenAdminRegistryContract.getTokenConfig(tokenAddress)可以获取到相关配置
        // 是因为在同目录下的ClaimAdmin.s.sol中的registryContract.registerAdminViaGetCCIPAdmin(tokenAddress);注册进去的
        TokenAdminRegistry.TokenConfig memory tokenConfig = tokenAdminRegistryContract.getTokenConfig(tokenAddress);

        address pendingAdministrator = tokenConfig.pendingAdministrator;

        require(pendingAdministrator == signer, "Only the pending administrator can accept the admin role");

        tokenAdminRegistryContract.acceptAdminRole(tokenAddress);

        console.log("Accepted admin role for token:", tokenAddress);

        vm.stopBroadcast();
    }
}
