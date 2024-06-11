// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "./utils/Constants.s.sol";
import "utils/src/CommonUtils.sol";
import { TokenSideChainMultiBridge } from "contracts/agToken/TokenSideChainMultiBridge.sol";
import { LayerZeroBridgeTokenERC20 } from "contracts/agToken/layerZero/LayerZeroBridgeTokenERC20.sol";
import { ImmutableCreate2Factory } from "contracts/interfaces/external/create2/ImmutableCreate2Factory.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";

contract DeployAngleSideChainMultiBridge is Script, CommonUtils {
    using stdJson for string;

    function run() external {
        /** TODO  complete */
        uint256 totalLimit = vm.envUint("TOTAL_LIMIT");
        uint256 hourlyLimit = vm.envUint("HOURLY_LIMIT");
        uint256 chainTotalHourlyLimit = vm.envUint("CHAIN_TOTAL_HOURLY_LIMIT");
        bool mock = vm.envOr("MOCK", false);
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        address deployer = vm.addr(deployerPrivateKey);
        string memory symbol = "ANGLE";
        string memory jsonVanity = vm.readFile(string.concat(JSON_VANITY_PATH, "ANGLE", ".json"));
        bytes32 salt = jsonVanity.readBytes32("$.salt");
        bytes memory initCode = jsonVanity.readBytes("$.initCode");
        uint256 chainId = vm.envUint("CHAIN_ID");
        vm.startBroadcast(deployerPrivateKey);

        string memory json;
        address proxyAdmin;
        address coreBorrow;
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
        } else {
            proxyAdmin = _chainToContract(chainId, ContractType.ProxyAdmin);
            coreBorrow = _chainToContract(chainId, ContractType.CoreBorrow);
        }
        ILayerZeroEndpoint lzEndpoint = _lzEndPoint(chainId);
        address expectedAddress;
        if (vm.envExists("EXPECTED_ADDRESS")) {
            expectedAddress = vm.envAddress("EXPECTED_ADDRESS");
        } else {
            expectedAddress = address(0xAaaaAA19ddd491648Db2a31C32f2B2792DeC5015);
            // TODO compute the expected address once one of the address has been deployed
        }

        TokenSideChainMultiBridge angleImpl = new TokenSideChainMultiBridge();
        console.log("TokenSideChainMultiBridge Implementation deployed at", address(angleImpl));

        ImmutableCreate2Factory create2Factory = ImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);
        address computedAddress = create2Factory.findCreate2Address(salt, initCode);
        console.log("TokenSideChainMultiBridge Proxy Supposed to deploy: %s", computedAddress);

        require(computedAddress == expectedAddress, "Computed address does not match expected address");

        TokenSideChainMultiBridge angleProxy = TokenSideChainMultiBridge(create2Factory.safeCreate2(salt, initCode));
        TransparentUpgradeableProxy(payable(address(angleProxy))).upgradeTo(address(angleImpl));
        TransparentUpgradeableProxy(payable(address(angleProxy))).changeAdmin(proxyAdmin);
        console.log("TokenSideChainMultiBridge Proxy deployed at", address(angleProxy));

        LayerZeroBridgeTokenERC20 lzImpl = new LayerZeroBridgeTokenERC20();
        console.log("LayerZeroBridgeTokenERC20 Implementation deployed at", address(lzImpl));
        LayerZeroBridgeTokenERC20 lzProxy = LayerZeroBridgeTokenERC20(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(lzImpl),
                    abi.encodeWithSelector(
                        LayerZeroBridgeTokenERC20.initialize.selector,
                        string.concat("LayerZero Bridge ", symbol),
                        string.concat("LZ-", symbol),
                        lzEndpoint,
                        coreBorrow,
                        address(angleProxy),
                        0
                    )
                )
            )
        );
        console.log("LayerZeroBridgeTokenERC20 Proxy deployed at", address(lzProxy));

        angleProxy.initialize(
            symbol,
            symbol,
            ICoreBorrow(coreBorrow),
            address(lzProxy),
            totalLimit,
            hourlyLimit,
            0,
            false,
            chainTotalHourlyLimit
        );

        if (mock) {
            LayerZeroBridgeToken(address(lzProxy)).setUseCustomAdapterParams(1);

            (uint256[] memory chainIds, address[] memory contracts) = _getConnectedChains("ANGLE");

            // Set trusted remote from current chain
            for (uint256 i = 0; i < contracts.length; i++) {
                if (chainIds[i] == chainId) {
                    continue;
                }

                lzProxy.setTrustedRemote(_getLZChainId(chainIds[i]), abi.encodePacked(contracts[i], address(lzProxy)));
            }

            // add real governor
            if (vm.envBool("FINALIZE")) {
                address realGovernor = vm.envOr(
                    "REAL_GOVERNOR",
                    _chainToContract(chainId, ContractType.GovernorMultisig)
                );
                ICoreBorrow(coreBorrow).addGovernor(realGovernor);
                ICoreBorrow(coreBorrow).removeGovernor(deployer);
            }
        }

        string memory json2 = "output";
        if (vm.isFile(JSON_ADDRESSES_PATH)) {
            string[] memory keys = vm.parseJsonKeys(json, "");
            for (uint256 i = 0; i < keys.length; i++) {
                json2.serialize(keys[i], json.readAddress(string.concat(".", keys[i])));
            }
        }
        json2.serialize("angle", address(angleProxy));
        json2 = json2.serialize("lzAngle", address(lzProxy));
        json2.write(JSON_ADDRESSES_PATH);

        vm.stopBroadcast();
    }
}
