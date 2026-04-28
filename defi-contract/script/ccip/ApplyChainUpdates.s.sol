// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {TokenPool} from "@chainlink/contracts-ccip/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/libraries/RateLimiter.sol";

contract ApplyChainUpdates is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer address:", deployer);

        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/ccip/config.json");
        string memory localPoolPath = string.concat(root, "/script/ccip/output/deployedTokenPool_", chainName, ".json");

        uint256 remoteChainId = HelperUtils.getUintFromJson(
            vm, configPath, string.concat(".remoteChains.", HelperUtils.uintToStr(block.chainid))
        );

        string memory remoteChainName = HelperUtils.getChainName(remoteChainId);
        string memory remotePoolPath =
            string.concat(root, "/script/ccip/output/deployedTokenPool_", remoteChainName, ".json");
        string memory remoteTokenPath = string.concat(root, "/script/ccip/output/deployedToken_", remoteChainName, ".json");

        address poolAddress =
            HelperUtils.getAddressFromJson(vm, localPoolPath, string.concat(".deployedTokenPool_", chainName));
        address remotePoolAddress =
            HelperUtils.getAddressFromJson(vm, remotePoolPath, string.concat(".deployedTokenPool_", remoteChainName));
        address remoteTokenAddress =
            HelperUtils.getAddressFromJson(vm, remoteTokenPath, string.concat(".deployedToken_", remoteChainName));

        address[] memory remotePoolAddresses = new address[](1);
        remotePoolAddresses[0] = remotePoolAddress;

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory remoteNetworkConfig =
            HelperUtils.getNetworkConfig(helperConfig, remoteChainId);

        uint64 remoteChainSelector = remoteNetworkConfig.chainSelector;

        require(poolAddress != address(0), "Invalid pool address");
        require(remotePoolAddress != address(0), "Invalid remote pool address");
        require(remoteTokenAddress != address(0), "Invalid remote token address");
        require(remoteChainSelector != 0, "chainSelector is not defined for the remote chain");

        vm.startBroadcast(deployerPrivateKey);

        TokenPool poolContract = TokenPool(poolAddress);

        TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);

        bytes[] memory remotePoolAddressesEncoded = new bytes[](remotePoolAddresses.length);
        for (uint256 i = 0; i < remotePoolAddresses.length; i++) {
            remotePoolAddressesEncoded[i] = abi.encode(remotePoolAddresses[i]);
        }

        chainUpdates[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddressesEncoded,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false,
                capacity: 0,
                rate: 0
            })
        });

        // // 如果绑错了可以先移除原来的
        // uint64[] memory chainSelectorRemovals = new uint64[](1);
        // chainSelectorRemovals[0] = remoteChainSelector;

        // 首次绑定
        uint64[] memory chainSelectorRemovals = new uint64[](0);

        poolContract.applyChainUpdates(chainSelectorRemovals, chainUpdates);

        console.log("Chain update applied to pool at address:", poolAddress);

        vm.stopBroadcast();
    }
}
