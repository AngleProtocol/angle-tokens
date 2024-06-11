// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "./utils/Constants.s.sol";
import "utils/src/CommonUtils.sol";
import { AgTokenSideChainMultiBridge } from "contracts/agToken/AgTokenSideChainMultiBridge.sol";
import { LayerZeroBridgeToken } from "contracts/agToken/layerZero/LayerZeroBridgeToken.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";
import { Treasury } from "contracts/treasury/Treasury.sol";
import { ImmutableCreate2Factory } from "contracts/interfaces/external/create2/ImmutableCreate2Factory.sol";

contract DeployAgTokenSideChainMultiBridge is Script, CommonUtils {
    using stdJson for string;

    function run() external {
        /** TODO  complete */
        string memory stableName = vm.envString("STABLE_NAME");
        bool mock = vm.envOr("MOCK", false);
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        address deployer = vm.addr(deployerPrivateKey);
        string memory jsonVanity = vm.readFile(string.concat(JSON_VANITY_PATH, stableName, ".json"));
        bytes32 salt = jsonVanity.readBytes32("$.salt");
        bytes memory initCode = jsonVanity.readBytes("$.initCode");
        uint256 chainId = vm.envUint("CHAIN_ID");

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
            // TODO compute the expected address once one of the address has been deployed
            if (keccak256(abi.encodePacked(stableName)) == keccak256("USD")) {
                expectedAddress = _chainToContract(CHAIN_ETHEREUM, ContractType.AgUSD);
            }
            if (keccak256(abi.encodePacked(stableName)) == keccak256("EUR")) {
                expectedAddress = address(0x00001063a5d3A9d5f1B03e848fa788aae1d98C5c);
            }
        }

        vm.startBroadcast(deployerPrivateKey);

        AgTokenSideChainMultiBridge agTokenImpl = new AgTokenSideChainMultiBridge();
        console.log("AgTokenSideChainMultiBridge Implementation deployed at", address(agTokenImpl));

        ImmutableCreate2Factory create2Factory = ImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);
        address computedAddress = create2Factory.findCreate2Address(salt, initCode);
        console.log("AgTokenSideChainMultiBridge Proxy Supposed to deploy: %s", computedAddress);

        require(computedAddress == expectedAddress, "Computed address does not match expected address");

        AgTokenSideChainMultiBridge agToken = AgTokenSideChainMultiBridge(create2Factory.safeCreate2(salt, initCode));
        TransparentUpgradeableProxy(payable(address(agToken))).upgradeTo(address(agTokenImpl));
        TransparentUpgradeableProxy(payable(address(agToken))).changeAdmin(proxyAdmin);
        console.log("AgTokenSideChainMultiBridge Proxy deployed at", address(agToken));

        Treasury treasuryImpl = new Treasury();
        console.log("Treasury Implementation deployed at", address(treasuryImpl));

        Treasury treasuryProxy = Treasury(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(treasuryImpl),
                    abi.encodeWithSelector(Treasury.initialize.selector, coreBorrow, address(agToken))
                )
            )
        );
        console.log("Treasury Proxy deployed at", address(treasuryProxy));

        agToken.initialize(string.concat(stableName, "A"), string.concat(stableName, "A"), address(treasuryProxy));

        LayerZeroBridgeToken lzImpl = new LayerZeroBridgeToken();
        console.log("LayerZeroBridgeToken Implementation deployed at", address(lzImpl));
        LayerZeroBridgeToken lzProxy = LayerZeroBridgeToken(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(lzImpl),
                    abi.encodeWithSelector(
                        LayerZeroBridgeToken.initialize.selector,
                        string.concat("LayerZero Bridge ", stableName, "A"),
                        string.concat("LZ-", stableName, "A"),
                        address(lzEndpoint),
                        address(treasuryProxy),
                        0
                    )
                )
            )
        );
        console.log("LayerZeroBridgeToken Proxy deployed at", address(lzProxy));

        if (mock) {
            uint256 totalLimit = vm.envUint("TOTAL_LIMIT");
            uint256 hourlyLimit = vm.envUint("HOURLY_LIMIT");
            uint256 chainTotalHourlyLimit = vm.envUint("CHAIN_TOTAL_HOURLY_LIMIT");
            agToken.addBridgeToken(address(lzProxy), totalLimit, hourlyLimit, 0, false);
            agToken.setChainTotalHourlyLimit(chainTotalHourlyLimit);
            lzProxy.setUseCustomAdapterParams(1);

            (uint256[] memory chainIds, address[] memory contracts) = _getConnectedChains(stableName);

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
        json2.serialize("agToken", address(agToken));
        json2.serialize("treasury", address(treasuryProxy));
        json2 = json2.serialize("lzAgToken", address(lzProxy));
        json2.write(JSON_ADDRESSES_PATH);

        vm.stopBroadcast();
    }
}
