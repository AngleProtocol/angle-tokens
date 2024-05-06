// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "./utils/Constants.s.sol";
import "utils/src/CommonUtils.sol";
import { TokenSideChainMultiBridge } from "contracts/agToken/TokenSideChainMultiBridge.sol";
import { LayerZeroBridgeTokenERC20 } from "contracts/agToken/layerZero/LayerZeroBridgeTokenERC20.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";

contract DeployAngleSideChainMultiBridge is Script, CommonUtils {
    using stdJson for string;

    function run() external {
        /** TODO  complete */
        string memory chainName = vm.envString("CHAIN_NAME");
        uint256 totalLimit = vm.envUint("TOTAL_LIMIT");
        uint256 hourlyLimit = vm.envUint("HOURLY_LIMIT");
        uint256 chainTotalHourlyLimit = vm.envUint("CHAIN_TOTAL_HOURLY_LIMIT");
        bool mock = vm.envOr("MOCK", false);
        /** END  complete */

        string memory symbol = "ANGLE";
        uint256 chainId = vm.envUint("CHAIN_ID");
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        vm.startBroadcast(deployerPrivateKey);

        string memory json = vm.readFile(JSON_ADDRESSES_PATH);
        address proxyAdmin;
        address coreBorrow;
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
        ILayerZeroEndpoint lzEndpoint = _lzEndPoint(chainId);

        TokenSideChainMultiBridge angleImpl = new TokenSideChainMultiBridge();
        console.log("TokenSideChainMultiBridge Implementation deployed at", address(angleImpl));
        TokenSideChainMultiBridge angleProxy = TokenSideChainMultiBridge(
            address(_deployUpgradeable(proxyAdmin, address(angleImpl), ""))
        );
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
            string.concat(symbol, "_", chainName),
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
            (uint256[] memory chainIds, address[] memory contracts) = _getConnectedChains("ANGLE");

            // Set trusted remote from current chain
            for (uint256 i = 0; i < contracts.length; i++) {
                if (chainIds[i] == chainId) {
                    continue;
                }

                lzProxy.setTrustedRemote(_getLZChainId(chainIds[i]), abi.encodePacked(contracts[i], address(lzProxy)));
            }

            // TODO add real governor
        }

        string memory json2 = "output";
        string[] memory keys = vm.parseJsonKeys(json, "");
        for (uint256 i = 0; i < keys.length; i++) {
            json2.serialize(keys[i], json.readAddress(string.concat(".", keys[i])));
        }
        json2.serialize("angle", address(angleProxy));
        json2 = json2.serialize("lzAngle", address(lzProxy));
        json2.write(JSON_ADDRESSES_PATH);

        vm.stopBroadcast();
    }
}
