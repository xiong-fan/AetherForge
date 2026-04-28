// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract SetPool is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer address:", deployer);
        
        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory deployedTokenPath = string.concat(root, "/script/ccip/output/deployedToken_", chainName, ".json");
        string memory deployedPoolPath = string.concat(root, "/script/ccip/output/deployedTokenPool_", chainName, ".json");

        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, deployedTokenPath, string.concat(".deployedToken_", chainName));
        address poolAddress =
            HelperUtils.getAddressFromJson(vm, deployedPoolPath, string.concat(".deployedTokenPool_", chainName));

        HelperConfig helperConfig = new HelperConfig();
        (,,, address tokenAdminRegistry,,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(poolAddress != address(0), "Invalid pool address");
        require(tokenAdminRegistry != address(0), "TokenAdminRegistry is not defined for this network");

        vm.startBroadcast(deployerPrivateKey);

        TokenAdminRegistry tokenAdminRegistryContract = TokenAdminRegistry(tokenAdminRegistry);

        TokenAdminRegistry.TokenConfig memory config = tokenAdminRegistryContract.getTokenConfig(tokenAddress);
        address tokenAdministratorAddress = config.administrator;

        console.log("Setting pool for token:", tokenAddress);
        console.log("New pool address:", poolAddress);
        console.log("Action performed by admin:", tokenAdministratorAddress);

        tokenAdminRegistryContract.setPool(tokenAddress, poolAddress);

        console.log("Pool set for token", tokenAddress, "to", poolAddress);

        vm.stopBroadcast();
    }
}
