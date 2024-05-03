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
        address expectedAddress = vm.envAddress("EXPECTED_ADDRESS");
        uint256 totalLimit = vm.envUint("TOTAL_LIMIT");
        uint256 hourlyLimit = vm.envUint("HOURLY_LIMIT");
        uint256 chainTotalHourlyLimit = vm.envUint("CHAIN_TOTAL_HOURLY_LIMIT");
        bool mock = vm.envOr("MOCK", false);
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

        ImmutableCreate2Factory create2Factory = ImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);
        bytes memory initCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(IMMUTABLE_CREATE2_FACTORY_ADDRESS, deployer, "")
        );
        address computedAddress = create2Factory.findCreate2Address(salt, initCode);
        console.log("AgTokenSideChainMultiBridge Proxy Supposed to deploy: %s", computedAddress);

        require(computedAddress == expectedAddress, "Computed address does not match expected address");

        AgTokenSideChainMultiBridge angleProxy = AgTokenSideChainMultiBridge(
            create2Factory.safeCreate2(salt, initCode)
        );
        TransparentUpgradeableProxy(payable(address(angleProxy))).upgradeTo(address(agTokenImpl));
        TransparentUpgradeableProxy(payable(address(angleProxy))).changeAdmin(proxyAdmin);
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

        angleProxy.initialize(string.concat(stableName, "A"), string.concat(stableName, "A"), address(treasuryProxy));

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
            angleProxy.addBridgeToken(address(lzProxy), totalLimit, hourlyLimit, 0, false);
            angleProxy.setChainTotalHourlyLimit(chainTotalHourlyLimit);
            LayerZeroBridgeToken(address(lzProxy)).setUseCustomAdapterParams(1);

            (uint256[] memory chainIds, address[] memory contracts) = _getConnectedChains(stableName);

            // Set trusted remote from current chain
            for (uint256 i = 0; i < contracts.length; i++) {
                if (chainIds[i] == chainId) {
                    continue;
                }

                lzProxy.setTrustedRemote(_getLZChainId(chainIds[i]), abi.encodePacked(contracts[i], address(lzProxy)));
            }
        }

        vm.stopBroadcast();
    }
}
