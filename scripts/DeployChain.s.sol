// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "utils/src/CommonUtils.sol";
import { ProxyAdmin } from "contracts/external/ProxyAdmin.sol";
import { CoreBorrow } from "contracts/coreBorrow/CoreBorrow.sol";

contract DeployChain is Script, CommonUtils {
    function run() external {
        uint256 chainId = vm.envUint("CHAIN_ID");

        /** TODO  complete */
        address governor = vm.envOr("GOVERNOR", _chainToContract(chainId, ContractType.GovernorMultisig));
        address guardian = vm.envOr("GUARDIAN", _chainToContract(chainId, ContractType.GuardianMultisig));
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed at", address(proxyAdmin));

        CoreBorrow coreBorrowImpl = new CoreBorrow();
        console.log("CoreBorrow Implementation deployed at", address(coreBorrowImpl));

        CoreBorrow coreBorrowProxy = CoreBorrow(
            address(
                _deployUpgradeable(
                    address(proxyAdmin),
                    address(coreBorrowImpl),
                    abi.encodeWithSelector(CoreBorrow.initialize.selector, governor, guardian)
                )
            )
        );
        console.log("CoreBorrow Proxy deployed at", address(coreBorrowProxy));

        vm.stopBroadcast();
    }
}
