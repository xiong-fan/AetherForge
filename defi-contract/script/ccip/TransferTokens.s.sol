// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IERC20} from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";

contract TransferTokens is Script {
    enum Fee {
        Native,
        Link
    }

    function run() external {
        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory configPath = string.concat(root, "/script/ccip/config.json");
        string memory tokenPath = string.concat(root, "/script/ccip/output/deployedToken_", chainName, ".json");

        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, tokenPath, string.concat(".deployedToken_", chainName));

        uint256 amount = HelperUtils.getUintFromJson(vm, configPath, ".tokenAmountToTransfer");
        string memory feeType = HelperUtils.getStringFromJson(vm, configPath, ".feeType");

        uint256 destinationChainId = HelperUtils.getUintFromJson(
            vm, configPath, string.concat(".remoteChains.", HelperUtils.uintToStr(block.chainid))
        );

        HelperConfig helperConfig = new HelperConfig();
        (, address router,,,, address link,,) = helperConfig.activeNetworkConfig();

        HelperConfig.NetworkConfig memory remoteNetworkConfig =
            HelperUtils.getNetworkConfig(helperConfig, destinationChainId);
        uint64 destinationChainSelector = remoteNetworkConfig.chainSelector;

        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Invalid amount to transfer");
        require(destinationChainSelector != 0, "Chain selector not defined for the destination chain");

        address feeTokenAddress;
        if (keccak256(bytes(feeType)) == keccak256(bytes("native"))) {
            feeTokenAddress = address(0);
        } else if (keccak256(bytes(feeType)) == keccak256(bytes("link"))) {
            feeTokenAddress = link;
        } else {
            console.log("Invalid fee token:", feeType);
            revert("Invalid fee token");
        }

        vm.startBroadcast();

        IRouterClient routerContract = IRouterClient(router);

        require(routerContract.isChainSupported(destinationChainSelector), "Destination chain not supported");

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(msg.sender),
            data: abi.encode(),
            tokenAmounts: new Client.EVMTokenAmount[](1),
            feeToken: feeTokenAddress,
            extraArgs: abi.encodePacked(
                bytes4(keccak256("CCIP EVMExtraArgsV1")),
                abi.encode(uint256(0))
            )
        });

        message.tokenAmounts[0] = Client.EVMTokenAmount({token: tokenAddress, amount: amount});

        IERC20(tokenAddress).approve(router, amount);

        uint256 fees = routerContract.getFee(destinationChainSelector, message);
        console.log("Estimated fees:", fees);

        bytes32 messageId;
        if (feeTokenAddress == address(0)) {
            messageId = routerContract.ccipSend{value: fees}(destinationChainSelector, message);
        } else {
            IERC20(feeTokenAddress).approve(router, fees);
            messageId = routerContract.ccipSend(destinationChainSelector, message);
        }

        console.log("Message ID:");
        console.logBytes32(messageId);

        string memory messageUrl = string(
            abi.encodePacked(
                "Check status of the message at https://ccip.chain.link/msg/", HelperUtils.bytes32ToHexString(messageId)
            )
        );
        console.log(messageUrl);

        vm.stopBroadcast();
    }
}
