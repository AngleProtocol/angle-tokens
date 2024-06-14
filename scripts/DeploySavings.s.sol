// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "./utils/Constants.s.sol";
import "utils/src/CommonUtils.sol";
import { TokenSideChainMultiBridge } from "contracts/agToken/TokenSideChainMultiBridge.sol";
import { LayerZeroBridgeTokenERC20 } from "contracts/agToken/layerZero/LayerZeroBridgeTokenERC20.sol";
import { ImmutableCreate2Factory } from "contracts/interfaces/external/create2/ImmutableCreate2Factory.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";

contract DeploySavings is Script, CommonUtils {
    using stdJson for string;

    function run() external {
        /** TODO  complete */
        string memory stableName = vm.envString("STABLE_NAME");
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        address deployer = vm.addr(deployerPrivateKey);
        string memory jsonVanity = vm.readFile(string.concat(JSON_VANITY_PATH, "Savings", stableName, ".json"));
        bytes32 salt = jsonVanity.readBytes32("$.salt");
        bytes memory initCode = jsonVanity.readBytes("$.initCode");
        uint256 chainId = vm.envUint("CHAIN_ID");

        string memory json;
        address proxyAdmin;
        address coreBorrow;
        address agToken;
        if (vm.isFile(JSON_ADDRESSES_PATH)) {
            json = vm.readFile(JSON_ADDRESSES_PATH);
            if (vm.keyExistsJson(json, ".proxyAdmin")) {
                proxyAdmin = vm.parseJsonAddress(json, ".proxyAdmin");
            } else {
                proxyAdmin = _chainToContract(chainId, ContractType.ProxyAdmin);
            }
            if (vm.keyExistsJson(json, ".coreBorrow")) {
                coreBorrow = vm.parseJsonAddress(json, ".coreBorrow");
            } else {
                coreBorrow = _chainToContract(chainId, ContractType.CoreBorrow);
            }
            if (vm.keyExistsJson(json, ".agToken")) {
                agToken = vm.parseJsonAddress(json, ".agToken");
            } else {
                agToken = _chainToContract(chainId, ContractType.AgToken);
            }
        } else {
            proxyAdmin = _chainToContract(chainId, ContractType.ProxyAdmin);
            coreBorrow = _chainToContract(chainId, ContractType.CoreBorrow);
            agToken = _chainToContract(chainId, ContractType.AgEUR);
        }

        vm.startBroadcast(deployerPrivateKey);

        Savings savingsImpl = new Savings();
        console.log("Savings Implementation deployed at", address(savingsImpl));

        ImmutableCreate2Factory create2Factory = ImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);
        address computedAddress = create2Factory.findCreate2Address(salt, initCode);
        console.log("Savings Proxy Supposed to deploy: %s", computedAddress);

        require(computedAddress == expectedAddress, "Computed address does not match expected address");

        Savings saving = Savings(create2Factory.safeCreate2(salt, initCode));
        TransparentUpgradeableProxy(payable(address(saving))).upgradeTo(address(savingsImpl));
        TransparentUpgradeableProxy(payable(address(saving))).changeAdmin(proxyAdmin);
        console.log("Savings Proxy deployed at", address(saving));

        IERC20MetadataUpgradeable(agToken).approve(address(saving), 1e18);
        Savings(saving).initialize(
            IAccessControlManager(coreBorrow),
            IERC20MetadataUpgradeable(agToken),
            string.concat("Staked ", stableName, "A"),
            string.concat("st", stableName),
            1
        );

        string memory json2 = "output";
        if (vm.isFile(JSON_ADDRESSES_PATH)) {
            string[] memory keys = vm.parseJsonKeys(json, "");
            for (uint256 i = 0; i < keys.length; i++) {
                json2.serialize(keys[i], json.readAddress(string.concat(".", keys[i])));
            }
        }
        json2.serialize("stAgToken", address(angleProxy));
        json2.write(JSON_ADDRESSES_PATH);

        vm.stopBroadcast();
    }
}
