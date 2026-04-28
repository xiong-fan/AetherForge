// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperUtils} from "./utils/HelperUtils.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {RegistryModuleOwnerCustom} from
    "@chainlink/contracts-ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {BurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/BurnMintERC20.sol";

contract ClaimAdmin is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("deployer address:", deployer);

        string memory chainName = HelperUtils.getChainName(block.chainid);

        string memory root = vm.projectRoot();
        string memory deployedTokenPath = string.concat(root, "/script/ccip/output/deployedToken_", chainName, ".json");
        string memory configPath = string.concat(root, "/script/ccip/config.json");

        address tokenAddress =
            HelperUtils.getAddressFromJson(vm, deployedTokenPath, string.concat(".deployedToken_", chainName));
        address tokenAdmin = HelperUtils.getAddressFromJson(vm, configPath, ".BnMToken.ccipAdminAddress");

        HelperConfig helperConfig = new HelperConfig();
        (,,,, address registryModuleOwnerCustom,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(registryModuleOwnerCustom != address(0), "Registry module owner custom is not defined for this network");

        vm.startBroadcast(deployerPrivateKey);

        claimAdminWithCCIPAdmin(tokenAddress, tokenAdmin, registryModuleOwnerCustom);

        vm.stopBroadcast();
    }

    function claimAdminWithCCIPAdmin(address tokenAddress, address tokenAdmin, address registryModuleOwnerCustom)
        internal
    {
        BurnMintERC20 tokenContract = BurnMintERC20(tokenAddress);
        RegistryModuleOwnerCustom registryContract = RegistryModuleOwnerCustom(registryModuleOwnerCustom);

        address tokenContractCCIPAdmin = tokenContract.getCCIPAdmin();
        console.log("Current token admin:", tokenContractCCIPAdmin);

        require(
            tokenContractCCIPAdmin == tokenAdmin, "CCIP admin of token doesn't match the token admin address."
        );

        console.log("Claiming admin of the token via getCCIPAdmin() for CCIP admin:", tokenAdmin);


        // 这个RegistryModuleOwnerCustom合约主要提供了两个常用函数：
        //     1、registerAdminViaGetCCIPAdmin(address token)  
        //         适用于使用了 Chainlink 官方 BurnMintERC20 的 Token（你当前用的方式）。
        //         它会调用 Token 合约的 getCCIPAdmin() 函数，获取当前管理员地址。
        //         然后把这个地址作为 pendingAdministrator（待确认管理员） 提交到 TokenAdminRegistry。

        //     2、registerAdminViaOwner(address token)  适用于普通的 ERC20（通过 owner() 函数获取管理员）。
        //         给那些没有实现 getCCIPAdmin() 的 Token 使用。

        // 作用总结：
        //     它充当中间桥梁，让 Token 的真实管理员（你）能够安全地向 CCIP 的中央注册表（TokenAdminRegistry）声明：“我是这个 Token 的管理员”。
        //     它会进行一些检查，确保只有 Token 当前的合法管理员才能发起 Claim 操作(就也说只有tokenAddress的部署者才能调用下面这个合约的registerAdminViaGetCCIPAdmin函数)，防止别人恶意注册。
        
        // 它和 TokenAdminRegistry 的关系TokenAdminRegistry：
        //     CCIP 的核心注册表，负责记录“哪个 Token 对应哪个 Pool”，以及“谁是这个 Token 的管理员”。
        //     RegistryModuleOwnerCustom：是 TokenAdminRegistry 允许使用的注册模块之一。它被设计成可扩展的（以后可能添加更多模块），目前主要负责“通过 owner 或 getCCIPAdmin 来注册管理员”这个常见场景。

        // 在 ClaimAdmin 脚本里，先通过 RegistryModuleOwnerCustom 进行 Claim（声明），成功后才会进入 AcceptAdminRole 步骤。

        // 为什么需要这个模块？
        //     让注册流程更灵活（支持不同类型的 Token）。
        //     增加一层安全检查（只有真正的 Token 管理员才能 Claim）。
        //     符合 Chainlink 的模块化设计思想（RegistryModule 可以被替换或扩展）。
        registryContract.registerAdminViaGetCCIPAdmin(tokenAddress);


        console.log("Admin claimed successfully for token:", tokenAddress);
    }
}
