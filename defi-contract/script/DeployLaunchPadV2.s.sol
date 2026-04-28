// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LaunchPadV2.sol";

contract DeployLaunchPadV2 is Script {
    function run() external {
        // Read private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenFactory = 0x26Fd85f5b351862B3eE8B7EEe1a48C96273527BF;

        vm.startBroadcast(deployerPrivateKey);

        // Deploy LaunchPadV2
        LaunchPadV2 launchpad = new LaunchPadV2(tokenFactory);
        console.log("LaunchPadV2 deployed at:", address(launchpad));
        console.log("TokenFactory address:", tokenFactory);

        vm.stopBroadcast();
    }
}
