// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../BaseTest.t.sol";
import { MockTreasury } from "contracts/mock/MockTreasury.sol";
import { AgTokenSideChainMultiBridge } from "contracts/agToken/AgTokenSideChainMultiBridge.sol";
import { MockToken } from "contracts/mock/MockToken.sol";

contract AgTokenSideChainMultiBridgeTest is BaseTest {
    AgTokenSideChainMultiBridge internal _agToken;
    AgTokenSideChainMultiBridge internal _agTokenImplem;
    MockTreasury internal _treasury;
    MockToken internal _bridgeToken;

    function setUp() public override {
        super.setUp();

        _agTokenImplem = new AgTokenSideChainMultiBridge();
        _agToken = AgTokenSideChainMultiBridge(_deployUpgradeable(address(proxyAdmin), address(_agTokenImplem), ""));

        _treasury = new MockTreasury(
            IAgToken(address(_agToken)),
            _GOVERNOR,
            _GUARDIAN,
            address(0),
            address(0),
            address(0)
        );

        _agToken.initialize("agEUR", "agEUR", address(_treasury));

        _treasury.addMinter(_agToken, _alice);
        _treasury.addMinter(_agToken, _GOVERNOR);
        vm.prank(_alice);
        _agToken.mint(_alice, 1e18);

        _bridgeToken = new MockToken("any-agEUR", "any-agEUR", 18);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(_bridgeToken), 10e18, 1e18, 5e8, false);
    }

    // ================================= INITIALIZE ================================

    function test_initialize_Constructor() public {
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertEq(limit, 10e18);
        assertEq(hourlyLimit, 1e18);
        assertEq(fee, 5e8);
        assertTrue(allowed);
        assertFalse(paused);
        assertEq(_agToken.bridgeTokensList(0), address(_bridgeToken));
        assertEq(_agToken.allBridgeTokens()[0], address(_bridgeToken));
    }

    function test_initialize_NotGovernor() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernor.selector);
        vm.prank(_bob);
        _agToken.addBridgeToken(address(_bridgeToken), 10e18, 1e18, 5e8, false);
    }

    function test_initialize_TooHighParameterValue() public {
        MockToken bridgeToken2 = new MockToken("any-agEUR", "any-agEUR", 18);
        vm.expectRevert(AgTokenSideChainMultiBridge.TooHighParameterValue.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(bridgeToken2), 1e18, 1e17, 2e9, false);
    }

    function test_initialize_ZeroAddress() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(0), 1e18, 1e17, 5e8, false);
    }

    function test_initialize_AlreadyAdded() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(_bridgeToken), 1e18, 1e17, 5e8, false);
    }

    function test_initialize_SecondTokenAdded() public {
        MockToken bridgeToken2 = new MockToken("synapse-agEUR", "synapse-agEUR", 18);

        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(bridgeToken2), 1e18, 1e17, 5e8, false);
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(bridgeToken2)
        );
        assertEq(limit, 1e18);
        assertEq(hourlyLimit, 1e17);
        assertEq(fee, 5e8);
        assertTrue(allowed);
        assertFalse(paused);
        assertEq(_agToken.bridgeTokensList(1), address(bridgeToken2));
        assertEq(_agToken.allBridgeTokens()[1], address(bridgeToken2));
    }

    // ================================= AddBridgeToken ================================

    function test_addBridgeToken_Normal() public {
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );

        assertEq(limit, 10e18);
        assertEq(hourlyLimit, 1e18);
        assertEq(fee, 5e8);
        assertTrue(allowed);
        assertFalse(paused);
        assertEq(_agToken.bridgeTokensList(0), address(_bridgeToken));
        assertEq(_agToken.allBridgeTokens()[0], address(_bridgeToken));
    }

    function test_addBridgeToken_NotGovernor() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernor.selector);
        vm.prank(_alice);
        _agToken.addBridgeToken(address(_bridgeToken), 10e18, 1e18, 5e8, false);
    }

    function test_addBridgeToken_TooHighParameterValue() public {
        MockToken bridgeToken2 = new MockToken("any-agEUR", "any-agEUR", 18);
        vm.expectRevert(AgTokenSideChainMultiBridge.TooHighParameterValue.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(bridgeToken2), 1e18, 1e17, 2e9, false);
    }

    function test_addBridgeToken_ZeroAddress() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(0), 1e18, 1e17, 5e8, false);
    }

    function test_addBridgeToken_AlreadyAdded() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(_bridgeToken), 1e18, 1e17, 5e8, false);
    }

    function test_addBridgeToken_SecondTokenAdded() public {
        MockToken bridgeToken2 = new MockToken("synapse-agEUR", "synapse-agEUR", 18);

        vm.prank(_GOVERNOR);
        _agToken.addBridgeToken(address(bridgeToken2), 1e18, 1e17, 5e8, false);
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(bridgeToken2)
        );
        assertEq(limit, 1e18);
        assertEq(hourlyLimit, 1e17);
        assertEq(fee, 5e8);
        assertTrue(allowed);
        assertFalse(paused);
        assertEq(_agToken.bridgeTokensList(1), address(bridgeToken2));
        assertEq(_agToken.allBridgeTokens()[1], address(bridgeToken2));
    }

    // ================================= RemoveBridgeToken ================================

    function test_removeBridgeToken_NotGovernor() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernor.selector);
        vm.prank(_alice);
        _agToken.removeBridgeToken(address(_bridgeToken));
    }

    function test_removeBridgeToken_NonNullBalance() public {
        _bridgeToken.mint(address(_agToken), 1e18);
        vm.expectRevert(AgTokenSideChainMultiBridge.AssetStillControlledInReserves.selector);
        vm.prank(_GOVERNOR);
        _agToken.removeBridgeToken(address(_bridgeToken));
    }

    function test_removeBridgeToken_NormalOneToken() public {
        vm.prank(_GOVERNOR);
        _agToken.removeBridgeToken(address(_bridgeToken));

        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertEq(limit, 0);
        assertEq(hourlyLimit, 0);
        assertEq(fee, 0);
        assertFalse(allowed);
        assertFalse(paused);
    }

    function test_removeBridgeToken_TwoTokensAndFirstIsRemoved() public {
        MockToken bridgeToken2 = new MockToken("synapse-agEUR", "synapse-agEUR", 18);
        vm.startPrank(_GOVERNOR);
        _agToken.addBridgeToken(address(bridgeToken2), 100e18, 10e18, 3e7, true);
        _agToken.removeBridgeToken(address(bridgeToken2));
        vm.stopPrank();

        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(bridgeToken2)
        );
        assertEq(limit, 0);
        assertEq(hourlyLimit, 0);
        assertEq(fee, 0);
        assertFalse(allowed);
        assertFalse(paused);
        assertEq(_agToken.bridgeTokensList(0), address(_bridgeToken));
        assertEq(_agToken.allBridgeTokens()[0], address(_bridgeToken));
    }

    // ================================= RecoverERC20 ================================

    function test_recoverERC20_NotGovernor() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernor.selector);
        vm.prank(_alice);
        _agToken.recoverERC20(address(_bridgeToken), _bob, 1e18);
    }

    function test_recoverERC20_InvalidBalance() public {
        vm.expectRevert();
        vm.prank(_GOVERNOR);
        _agToken.recoverERC20(address(_bridgeToken), _bob, 1e19);
    }

    function test_recoverERC20_Normal() public {
        _bridgeToken.mint(address(_agToken), 1e18);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 1e18);
        vm.prank(_GOVERNOR);
        _agToken.recoverERC20(address(_bridgeToken), _bob, 1e18);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 0);
    }

    // ================================= SetLimit ================================

    function test_setLimit_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.setLimit(address(_bridgeToken), 1e18);
    }

    function test_setLimit_InvalidToken() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.setLimit(_alice, 1e18);
    }

    function test_setLimit_Normal() public {
        vm.prank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 1000e18);
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertEq(limit, 1000e18);
    }

    // ================================= SetHourlyLimit ================================

    function test_setHourlyLimit_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.setHourlyLimit(address(_bridgeToken), 1e18);
    }

    function test_setHourlyLimit_InvalidToken() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.setHourlyLimit(_alice, 1e18);
    }

    function test_setHourlyLimit_Normal() public {
        vm.prank(_GOVERNOR);
        _agToken.setHourlyLimit(address(_bridgeToken), 1000e18);
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertEq(hourlyLimit, 1000e18);
    }

    // ================================= SetChainTotalHourlyLimit ================================

    function test_setChainTotalHourlyLimit_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.setChainTotalHourlyLimit(1e18);
    }

    function test_setChainTotalHourlyLimit_Normal() public {
        vm.prank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(1000e18);
        assertEq(_agToken.chainTotalHourlyLimit(), 1000e18);
    }

    // ================================= SetSwapFee ================================

    function test_setSwapFee_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
    }

    function test_setSwapFee_InvalidToken() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.setSwapFee(_alice, 5e8);
    }

    function test_setSwapFee_TooHighParameterValue() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.TooHighParameterValue.selector);
        vm.prank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 2e9);
    }

    function test_setSwapFee_Normal() public {
        vm.prank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 3e8);
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertEq(fee, 3e8);
    }

    // ================================= ToggleBridge ================================

    function test_toggleBridge_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.toggleBridge(address(_bridgeToken));
    }

    function test_toggleBridge_NonExistingBridge() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        vm.prank(_GOVERNOR);
        _agToken.toggleBridge(_alice);
    }

    function test_toggleBridge_Paused() public {
        vm.prank(_GOVERNOR);
        _agToken.toggleBridge(address(_bridgeToken));
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertTrue(paused);
    }

    function test_toggleBridge_Unpaused() public {
        vm.startPrank(_GOVERNOR);
        _agToken.toggleBridge(address(_bridgeToken));
        _agToken.toggleBridge(address(_bridgeToken));
        vm.stopPrank();
        (uint256 limit, uint256 hourlyLimit, uint64 fee, bool allowed, bool paused) = _agToken.bridges(
            address(_bridgeToken)
        );
        assertFalse(paused);
    }

    // ================================= ToggleFeesForAddress ================================

    function test_toggleFeesForAddress_NotGovernorOrGuardian() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.NotGovernorOrGuardian.selector);
        vm.prank(_alice);
        _agToken.toggleFeesForAddress(_alice);
    }

    function test_toggleFeesForAddress_AddressExempted() public {
        vm.prank(_GOVERNOR);
        _agToken.toggleFeesForAddress(_alice);
        assertEq(_agToken.isFeeExempt(_alice), 1);
    }

    function test_toggleFeesForAddress_AddressNotExempted() public {
        vm.startPrank(_GOVERNOR);
        _agToken.toggleFeesForAddress(_alice);
        _agToken.toggleFeesForAddress(_alice);
        vm.stopPrank();
        assertEq(_agToken.isFeeExempt(_alice), 0);
    }

    // ================================= SwapIn ================================

    function test_swapIn_IncorrectBridgeToken() public {
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        _agToken.swapIn(_bob, 1e18, _alice);
    }

    function test_swapIn_PausedBridge() public {
        vm.startPrank(_GOVERNOR);
        _agToken.toggleBridge(address(_bridgeToken));
        vm.stopPrank();
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        _agToken.swapIn(address(_bridgeToken), 1e18, _alice);
    }

    function test_swapIn_InsufficentBalanceOrApproval() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 100e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 100e18);
        _bridgeToken.mint(_GOVERNOR, 10e18);
        vm.expectRevert();
        _agToken.swapIn(address(_bridgeToken), 50e18, _alice);
        _bridgeToken.approve(address(_agToken), 100e18);
        vm.expectRevert();
        _agToken.swapIn(address(_bridgeToken), 50e18, _alice);
        vm.stopPrank();
    }

    function test_swapIn_ZeroLimitSwaps() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 0);
        _agToken.swapIn(address(_bridgeToken), 1e18, _alice);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_bob), 0);
    }

    function test_swapIn_AmountGreaterThanLimit() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 10e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 10e18);
        _agToken.setSwapFee(address(_bridgeToken), 0);
        _bridgeToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.approve(address(_agToken), 100e18);
        _agToken.swapIn(address(_bridgeToken), 100e18, _bob);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_bob), 10e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 90e18);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 10e18);
    }

    function test_swapIn_AmountGreaterThanHourlyLimit() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 10e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 1e18);
        _agToken.setSwapFee(address(_bridgeToken), 0);
        _bridgeToken.mint(_GOVERNOR, 2e18);
        _bridgeToken.approve(address(_agToken), 2e18);
        assertEq(_agToken.balanceOf(_bob), 0);
        _agToken.swapIn(address(_bridgeToken), 2e18, _bob);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_bob), 1e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 1e18);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 1e18);
    }

    function test_swapIn_TotalAmountGreaterThanHourlyLimit() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setLimit(address(_bridgeToken), 10e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 2e18);
        _bridgeToken.mint(_GOVERNOR, 3e18);
        _bridgeToken.approve(address(_agToken), 3e18);
        _agToken.swapIn(address(_bridgeToken), 1e18, _alice);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 1e18);
        _agToken.swapIn(address(_bridgeToken), 2e18, _alice);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_alice), 2e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 1e18);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 2e18);
    }

    function test_swapIn_HourlyLimitOverTwoHours() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 0);
        _agToken.setLimit(address(_bridgeToken), 10e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 2e18);
        _bridgeToken.mint(_GOVERNOR, 3e18);
        _bridgeToken.approve(address(_agToken), 3e18);
        _agToken.swapIn(address(_bridgeToken), 1e18, _bob);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 1e18);
        assertEq(_agToken.balanceOf(_bob), 1e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 2e18);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 1e18);

        uint256 hour = block.timestamp / 3600;
        assertEq(_agToken.usage(address(_bridgeToken), hour), 1e18);
        vm.warp(block.timestamp + 3600);
        hour = block.timestamp / 3600;
        assertEq(_agToken.usage(address(_bridgeToken), hour - 1), 1e18);
        assertEq(_agToken.usage(address(_bridgeToken), hour), 0);
        assertEq(_agToken.currentUsage(address(_bridgeToken)), 0);
        _agToken.swapIn(address(_bridgeToken), 2e18, _bob);
        assertEq(_agToken.usage(address(_bridgeToken), hour), 2e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 3e18);
        assertEq(_agToken.balanceOf(_bob), 3e18);
    }

    function test_swapIn_WithSomeTransactionFees() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
        _agToken.setLimit(address(_bridgeToken), 100e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 10e18);
        _bridgeToken.mint(_GOVERNOR, 10e18);
        _bridgeToken.approve(address(_agToken), 10e18);
        _agToken.swapIn(address(_bridgeToken), 10e18, _bob);
        vm.stopPrank();
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 10e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0e18);
        assertEq(_agToken.balanceOf(_bob), 5e18);
    }

    function test_swapIn_WithSomeTransactionFesAndExempt() public {
        vm.startPrank(_GOVERNOR);
        _agToken.toggleFeesForAddress(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
        _agToken.setLimit(address(_bridgeToken), 100e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 100e18);
        _bridgeToken.mint(_GOVERNOR, 10e18);
        _bridgeToken.approve(address(_agToken), 10e18);
        _agToken.swapIn(address(_bridgeToken), 10e18, _bob);
        vm.stopPrank();
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 10e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0e18);
        assertEq(_agToken.balanceOf(_bob), 10e18);
    }

    function test_swapIn_WithoutTransactionsFeesAndExempt() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 0);
        _agToken.setLimit(address(_bridgeToken), 100e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 100e18);
        _bridgeToken.mint(_GOVERNOR, 10e18);
        _bridgeToken.approve(address(_agToken), 10e18);
        _agToken.swapIn(address(_bridgeToken), 10e18, _bob);
        vm.stopPrank();
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 10e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0e18);
        assertEq(_agToken.balanceOf(_bob), 10e18);
    }

    function test_swapIn_WithWeirdTransactionFees() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 4e5);
        _agToken.setLimit(address(_bridgeToken), 100e18);
        _agToken.setHourlyLimit(address(_bridgeToken), 100e18);
        _bridgeToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.approve(address(_agToken), 100e18);
        _agToken.swapIn(address(_bridgeToken), 100e18, _bob);
        vm.stopPrank();
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 100e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0e18);
        assertEq(_agToken.balanceOf(_bob), 9996e16);
    }

    // ================================= SwapOut ================================

    function test_swapOut_IncorrectBridgeToken() public {
        vm.prank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(type(uint256).max);

        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        _agToken.swapOut(_bob, 1e18, _alice);
    }

    function test_swapOut_BridgeTokenPaused() public {
        vm.prank(_GOVERNOR);
        _agToken.toggleBridge(address(_bridgeToken));

        vm.prank(_GOVERNOR);
        vm.expectRevert(AgTokenSideChainMultiBridge.InvalidToken.selector);
        _agToken.swapOut(address(_bridgeToken), 1e18, _alice);
    }

    function test_swapOut_InvalidBridgeTokenBalance() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(type(uint256).max);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
        _agToken.mint(_GOVERNOR, 100e18);
        vm.expectRevert();
        _agToken.swapOut(address(_bridgeToken), 1e18, _alice);
        vm.stopPrank();
    }

    function test_swapOut_HourlyLimitExceeded() public {
        uint256 limit = 10e18;
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(limit);

        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);
        _agToken.swapOut(address(_bridgeToken), 9e18, _bob);
        vm.expectRevert(AgTokenSideChainMultiBridge.HourlyLimitExceeded.selector);
        _agToken.swapOut(address(_bridgeToken), 2e18, _bob);
        vm.stopPrank();
    }

    function test_swapOut_HourlyLimitExceededAtDifferentHours() public {
        uint256 limit = 10e18;
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(limit);

        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);

        _agToken.swapOut(address(_bridgeToken), 9e18, _bob);
        vm.warp(block.timestamp + 3600);
        _agToken.swapOut(address(_bridgeToken), 2e18, _bob);
        vm.expectRevert(AgTokenSideChainMultiBridge.HourlyLimitExceeded.selector);
        _agToken.swapOut(address(_bridgeToken), 81e17, _bob);
        vm.stopPrank();
    }

    function test_swapOut_WithValidBridgeTokenBalance() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(type(uint256).max);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);
        _agToken.swapOut(address(_bridgeToken), 100e18, _bob);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(_bob), 50e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 50e18);
    }

    function test_swapOut_WithValidBridgeTokenBalanceButFeeExemption() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(type(uint256).max);
        _agToken.toggleFeesForAddress(_GOVERNOR);
        _agToken.setSwapFee(address(_bridgeToken), 5e8);
        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);
        _agToken.swapOut(address(_bridgeToken), 100e18, _bob);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(_bob), 100e18);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 0);
    }

    function test_swapOut_WithWeirdTransactionFees() public {
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(type(uint256).max);
        _agToken.setSwapFee(address(_bridgeToken), 4e5);
        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);
        _agToken.swapOut(address(_bridgeToken), 100e18, _bob);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(_bob), 9996e16);
        assertEq(_bridgeToken.balanceOf(_GOVERNOR), 0);
        assertEq(_bridgeToken.balanceOf(address(_agToken)), 4e16);
    }

    function test_swapOut_HourlyLimitAtDifferentHours() public {
        uint256 limit = 10e18;
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(limit);

        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);

        _agToken.swapOut(address(_bridgeToken), 9e18, _bob);
        assertEq(_agToken.chainTotalUsage(0), 9e18);
        vm.warp(block.timestamp + 3600);
        _agToken.swapOut(address(_bridgeToken), 2e18, _bob);
        assertEq(_agToken.chainTotalUsage(1), 2e18);

        _agToken.swapOut(address(_bridgeToken), 8e18, _bob);
        assertEq(_agToken.chainTotalUsage(1), 10e18);
        vm.stopPrank();
    }

    function test_swapOut_HourlyLimitUpdatedByGovernance() public {
        uint256 limit = 10e18;
        vm.startPrank(_GOVERNOR);
        _agToken.setChainTotalHourlyLimit(limit);

        _agToken.mint(_GOVERNOR, 100e18);
        _bridgeToken.mint(address(_agToken), 100e18);

        _agToken.swapOut(address(_bridgeToken), 9e18, _bob);
        vm.expectRevert(AgTokenSideChainMultiBridge.HourlyLimitExceeded.selector);
        _agToken.swapOut(address(_bridgeToken), 2e18, _bob);

        uint256 hour = block.timestamp / 3600;
        assertEq(_agToken.chainTotalUsage(hour), 9e18);

        _agToken.setChainTotalHourlyLimit(11e18);
        _agToken.swapOut(address(_bridgeToken), 2e18, _bob);
        assertEq(_agToken.chainTotalUsage(hour), 11e18);

        vm.expectRevert(AgTokenSideChainMultiBridge.HourlyLimitExceeded.selector);
        _agToken.swapOut(address(_bridgeToken), 1e17, _bob);

        assertEq(_agToken.chainTotalUsage(hour), 11e18);
        vm.stopPrank();
    }
}
