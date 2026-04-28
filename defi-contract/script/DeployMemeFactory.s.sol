// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";

contract DeployMemeFactory is Script {
    function run() external {
        // Sepolia Uniswap V2 Router address
        address UNISWAP_V2_ROUTER = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MemeFactory
        MemeFactory factory = new MemeFactory(UNISWAP_V2_ROUTER);

        console.log("MemeFactory deployed to:", address(factory));
        console.log("Implementation deployed to:", factory.implementation());
        console.log("Uniswap Router:", address(factory.uniswapRouter()));
        console.log("Platform Fee Receiver:", factory.platformFeeReceiver());

        vm.stopBroadcast();
    }
}
