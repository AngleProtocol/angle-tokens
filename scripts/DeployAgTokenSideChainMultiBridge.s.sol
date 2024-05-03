// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "utils/src/CommonUtils.sol";
import { AgTokenSideChainMultiBridge } from "contracts/agToken/AgTokenSideChainMultiBridge.sol";
import { LayerZeroBridgeToken } from "contracts/agToken/layerZero/LayerZeroBridgeToken.sol";
import { ICoreBorrow } from "contracts/interfaces/ICoreBorrow.sol";
import { Treasury } from "contracts/treasury/Treasury.sol";
import { ImmutableCreate2Factory } from "contracts/interfaces/external/create2/ImmutableCreate2Factory.sol";

contract DeployAgTokenSideChainMultiBridge is Script, CommonUtils {
    using stdJson for string;

    string constant JSON_VANITY_PATH = "./scripts/vanity.json";

    function run() external {
        /** TODO  complete */
        string memory stableName = vm.envString("STABLE_NAME");
        /** END  complete */

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), "m/44'/60'/0'/0/", 0);
        address deployer = vm.addr(deployerPrivateKey);
        string memory json = vm.readFile(JSON_VANITY_PATH);
        bytes32 salt = bytes32(abi.encodePacked(deployer, abi.encodePacked(uint96(json.readUint("$.init")))));
        uint256 chainId = vm.envUint("CHAIN_ID");

        address proxyAdmin = _chainToContract(chainId, ContractType.ProxyAdmin);
        address coreBorrow = _chainToContract(chainId, ContractType.CoreBorrow);
        ILayerZeroEndpoint lzEndpoint = _lzEndPoint(chainId);

        vm.startBroadcast(deployerPrivateKey);

        AgTokenSideChainMultiBridge agTokenImpl = new AgTokenSideChainMultiBridge();
        console.log("AgTokenSideChainMultiBridge Implementation deployed at", address(agTokenImpl));

        AgTokenSideChainMultiBridge angleProxy = AgTokenSideChainMultiBridge(
            ImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS).safeCreate2(
                salt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(address(agTokenImpl), deployer, "")
                )
            )
        );
        console.log("AgTokenSideChainMultiBridge Proxy deployed at", address(angleProxy));

        Treasury treasuryImpl = new Treasury();
        console.log("Treasury Implementation deployed at", address(treasuryImpl));

        Treasury treasuryProxy = Treasury(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(treasuryImpl),
                    abi.encodeWithSelector(Treasury.initialize.selector, coreBorrow, address(angleProxy))
                )
            )
        );
        console.log("Treasury Proxy deployed at", address(treasuryProxy));

        angleProxy.initialize(
            string.concat("Angle ag", stableName),
            string.concat("ag", stableName),
            address(treasuryProxy)
        );

        LayerZeroBridgeToken lzImpl = new LayerZeroBridgeToken();
        console.log("LayerZeroBridgeToken Implementation deployed at", address(lzImpl));
        LayerZeroBridgeToken lzProxy = LayerZeroBridgeToken(
            address(
                _deployUpgradeable(
                    proxyAdmin,
                    address(lzImpl),
                    abi.encodeWithSelector(
                        LayerZeroBridgeToken.initialize.selector,
                        string.concat("LayerZero Bridge ag", stableName),
                        string.concat("LZ-ag", stableName),
                        address(lzEndpoint),
                        address(treasuryProxy),
                        0
                    )
                )
            )
        );
        console.log("LayerZeroBridgeToken Proxy deployed at", address(lzProxy));

        vm.stopBroadcast();
    }
}
