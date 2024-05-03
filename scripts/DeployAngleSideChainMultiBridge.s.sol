// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "utils/src/CommonUtils.sol";
import { TokenSideChainMultiBridge } from "contracts/agToken/TokenSideChainMultiBridge.sol";
import { LayerZeroBridgeToken } from "contracts/agToken/layerZero/LayerZeroBridgeToken.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";

contract DeployTokenSideChainMultiBridge is Script, CommonUtils {
    function run() external {
        /** TODO  complete */
        string memory chainName = vm.envString("CHAIN_NAME");
        uint256 totalLimit = vm.envUint("TOTAL_LIMIT");
        uint256 hourlyLimit = vm.envUint("HOURLY_LIMIT");
        uint256 chainTotalHourlyLimit = vm.envUint("CHAIN_TOTAL_HOURLY_LIMIT");
        /** END  complete */

        string memory symbol = "ANGLE";
        uint256 chainId = vm.envUint("CHAIN_ID");
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        vm.startBroadcast(deployerPrivateKey);

        address proxyAdmin = _chainToContract(chainId, ContractType.ProxyAdmin);
        address coreBorrow = _chainToContract(chainId, ContractType.CoreBorrow);
        ILayerZeroEndpoint lzEndpoint = _lzEndPoint(chainId);

        TokenSideChainMultiBridge angleImpl = new TokenSideChainMultiBridge();
        console.log("TokenSideChainMultiBridge Implementation deployed at", address(angleImpl));
        TokenSideChainMultiBridge angleProxy = TokenSideChainMultiBridge(
            address(_deployUpgradeable(proxyAdmin, address(angleImpl), ""))
        );
        console.log("TokenSideChainMultiBridge Proxy deployed at", address(angleProxy));

        LayerZeroBridgeToken lzImpl = new LayerZeroBridgeToken();
        console.log("LayerZeroBridgeToken Implementation deployed at", address(lzImpl));
        LayerZeroBridgeToken lzProxy = LayerZeroBridgeToken(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(lzImpl),
                    abi.encodeWithSelector(
                        LayerZeroBridgeToken.initialize.selector,
                        string.concat("LayerZero Bridge ", symbol),
                        string.concat("LZ-", symbol),
                        lzEndpoint,
                        coreBorrow,
                        address(angleProxy)
                    )
                )
            )
        );
        console.log("LayerZeroBridgeToken Proxy deployed at", address(lzProxy));

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

        vm.stopBroadcast();
    }
}
