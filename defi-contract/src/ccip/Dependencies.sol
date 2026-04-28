// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BurnMintTokenPool} from "@chainlink/contracts-ccip/pools/BurnMintTokenPool.sol";
import {LockReleaseTokenPool} from "@chainlink/contracts-ccip/pools/LockReleaseTokenPool.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts-ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IGetCCIPAdmin} from "@chainlink/contracts-ccip/interfaces/IGetCCIPAdmin.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/libraries/RateLimiter.sol";
import {Client} from "@chainlink/contracts-ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import {OnRamp} from "@chainlink/contracts-ccip/onRamp/OnRamp.sol";
