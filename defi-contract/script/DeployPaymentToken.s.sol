// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PaymentToken.sol";


/**
 * @title Deploy
 * @dev Deployment script for all DeFi DApp contracts
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Token contracts
        console.log("Deploying Token contracts...");

        PaymentToken paymentToken = new PaymentToken();
        console.log("PaymentToken (USDC) deployed at:", address(paymentToken));
    }
}
