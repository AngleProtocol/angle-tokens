// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "utils/src/CommonUtils.sol";
import "./utils/Constants.s.sol";
import { ProxyAdmin } from "contracts/external/ProxyAdmin.sol";
import { CoreBorrow } from "contracts/coreBorrow/CoreBorrow.sol";

contract DeployChain is Script, CommonUtils {
    function run() external {
        uint256 chainId = vm.envUint("CHAIN_ID");

        /** TODO  complete */
        bool mock = vm.envOr("MOCK", false);
        address timelock;
        address governor;
        address guardian;
        if (vm.envExists("TIMELOCK")) {
            timelock = vm.envAddress("TIMELOCK");
        } else {
            timelock = _chainToContract(chainId, ContractType.Timelock);
        }
        if (vm.envExists("GOVERNOR")) {
            address governor = vm.envAddress("GOVERNOR");
        } else {
            address governor = _chainToContract(chainId, ContractType.GovernorMultisig);
        }
        if (vm.envExists("GUARDIAN")) {
            address guardian = vm.envAddress("GUARDIAN");
        } else {
            address guardian = _chainToContract(chainId, ContractType.GuardianMultisig);
        }
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);

        ProxyAdmin proxyAdmin = new ProxyAdmin();
        console.log("ProxyAdmin deployed at", address(proxyAdmin));

        CoreBorrow coreBorrowImpl = new CoreBorrow();
        console.log("CoreBorrow Implementation deployed at", address(coreBorrowImpl));

        CoreBorrow coreBorrowProxy = CoreBorrow(
            address(
                _deployUpgradeable(
                    address(proxyAdmin),
                    address(coreBorrowImpl),
                    abi.encodeWithSelector(CoreBorrow.initialize.selector, mock ? deployer : governor, guardian)
                )
            )
        );
        console.log("CoreBorrow Proxy deployed at", address(coreBorrowProxy));

        coreBorrowProxy.addGovernor(timelock);

        if (mock) {
            coreBorrowProxy.addGovernor(governor);
        }

        proxyAdmin.transferOwnership(governor);

        vm.serializeAddress("", "coreBorrow", address(coreBorrowProxy));
        vm.serializeAddress("", "guardian", guardian);
        vm.serializeAddress("", "governor", governor);
        string memory json = vm.serializeAddress("", "proxyAdmin", address(proxyAdmin));
        vm.writeJson(json, JSON_ADDRESSES_PATH);

        vm.stopBroadcast();
    }
}
