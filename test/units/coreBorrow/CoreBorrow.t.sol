// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../BaseTest.t.sol";
import { CoreBorrow, ICoreBorrow } from "contracts/coreBorrow/CoreBorrow.sol";
import { MockTreasury } from "contracts/mock/MockTreasury.sol";
import { IAgToken } from "contracts/interfaces/IAgToken.sol";
import { MockFlashLoanModule } from "contracts/mock/MockFlashLoanModule.sol";

contract CoreBorrowTest is BaseTest {
    MockTreasury internal _treasury;
    CoreBorrow internal _coreBorrowImplem;
    CoreBorrow internal _coreBorrow;
    MockFlashLoanModule internal _flashAngle;

    bytes32 constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 constant FLASHLOANER_TREASURY_ROLE = keccak256("FLASHLOANER_TREASURY_ROLE");

    function setUp() public override {
        super.setUp();

        _coreBorrowImplem = new CoreBorrow();
        _coreBorrow = CoreBorrow(_deployUpgradeable(address(proxyAdmin), address(_coreBorrowImplem), ""));

        _treasury = new MockTreasury(IAgToken(address(0)), address(0), address(0), address(0), address(0), address(0));
        _flashAngle = new MockFlashLoanModule(_coreBorrow);

        _coreBorrow.initialize(_GOVERNOR, _GUARDIAN);
    }

    // ================================= INITIALIZE ================================

    function test_initialize_Constructor() public {
        assertEq(_coreBorrow.isGovernor(_GOVERNOR), true);
        assertEq(_coreBorrow.isGovernor(_GUARDIAN), false);
        assertEq(_coreBorrow.isGovernorOrGuardian(_GUARDIAN), true);
        assertEq(_coreBorrow.isGovernorOrGuardian(_GOVERNOR), true);
        assertEq(_coreBorrow.isFlashLoanerTreasury(_GOVERNOR), false);
        assertEq(_coreBorrow.isFlashLoanerTreasury(_GUARDIAN), false);
        assertEq(_coreBorrow.getRoleAdmin(GUARDIAN_ROLE), GOVERNOR_ROLE);
        assertEq(_coreBorrow.getRoleAdmin(GOVERNOR_ROLE), GOVERNOR_ROLE);
        assertEq(_coreBorrow.getRoleAdmin(FLASHLOANER_TREASURY_ROLE), GOVERNOR_ROLE);
        assertEq(_coreBorrow.hasRole(GOVERNOR_ROLE, _GOVERNOR), true);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _GUARDIAN), true);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _GOVERNOR), true);
        assertEq(_coreBorrow.hasRole(FLASHLOANER_TREASURY_ROLE, _GOVERNOR), false);
        assertEq(_coreBorrow.flashLoanModule(), address(0));
    }

    function test_initialize_AlreadyInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        _coreBorrow.initialize(_GOVERNOR, _GUARDIAN);
    }

    function test_initialize_InvalidGovernorGuardian() public {
        _coreBorrow = CoreBorrow(_deployUpgradeable(address(proxyAdmin), address(_coreBorrowImplem), ""));
        vm.expectRevert(CoreBorrow.IncompatibleGovernorAndGuardian.selector);
        _coreBorrow.initialize(_GOVERNOR, _GOVERNOR);

        vm.expectRevert(CoreBorrow.ZeroAddress.selector);
        _coreBorrow.initialize(address(0), _GUARDIAN);

        vm.expectRevert(CoreBorrow.ZeroAddress.selector);
        _coreBorrow.initialize(_GOVERNOR, address(0));
    }

    // ================================= AddGovernor ================================

    function test_addGovernor_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.addGovernor(_alice);
    }

    function test_addGovernor_Normal() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.addGovernor(_alice);
        assertEq(_coreBorrow.isGovernor(_alice), true);
        assertEq(_coreBorrow.isGovernorOrGuardian(_alice), true);
        assertEq(_coreBorrow.hasRole(GOVERNOR_ROLE, _alice), true);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _alice), true);
    }

    function test_addGovernor_Multi() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.addGovernor(_alice);
        vm.prank(_alice);
        _coreBorrow.addGovernor(_bob);
        assertEq(_coreBorrow.isGovernor(_bob), true);
        assertEq(_coreBorrow.isGovernorOrGuardian(_bob), true);
        assertEq(_coreBorrow.hasRole(GOVERNOR_ROLE, _bob), true);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _bob), true);
    }

    // ================================= RemoveGovernor ================================

    function test_removeGovernor_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.removeGovernor(_alice);
    }

    function test_removeGovernor_NotEnoughGovernorsLeft() public {
        vm.expectRevert(CoreBorrow.NotEnoughGovernorsLeft.selector);
        _coreBorrow.removeGovernor(_GOVERNOR);
    }

    function test_removeGovernor_NormalAfterAsk() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.addGovernor(_alice);
        vm.prank(_alice);
        _coreBorrow.removeGovernor(_alice);

        assertEq(_coreBorrow.isGovernor(_alice), false);
        assertEq(_coreBorrow.isGovernorOrGuardian(_alice), false);
        assertEq(_coreBorrow.hasRole(GOVERNOR_ROLE, _alice), false);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _alice), false);
    }

    function test_removeGovernor_Normal() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.addGovernor(_alice);
        vm.prank(_GOVERNOR);
        _coreBorrow.removeGovernor(_alice);

        assertEq(_coreBorrow.isGovernor(_alice), false);
        assertEq(_coreBorrow.isGovernorOrGuardian(_alice), false);
        assertEq(_coreBorrow.hasRole(GOVERNOR_ROLE, _alice), false);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _alice), false);
    }

    // ================================= SetFlashLoanModule ================================

    function test_setFlashLoanModule_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.setFlashLoanModule(_GOVERNOR);
    }

    function test_setFlashLoanModule_ZeroAddress() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(0));
        assertEq(_coreBorrow.flashLoanModule(), address(0));
    }

    function test_setFlashLoanModule_NoTreasury() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
        assertEq(_coreBorrow.flashLoanModule(), address(_flashAngle));
    }

    function test_setFlashLoanModule_WrongCore() public {
        _flashAngle = new MockFlashLoanModule(CoreBorrow(_GOVERNOR));
        vm.expectRevert(CoreBorrow.InvalidCore.selector);
        vm.prank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
    }

    function test_setFlashLoanModule_Normal() public {
        vm.startPrank(_GOVERNOR);
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
        vm.stopPrank();
        assertEq(_coreBorrow.flashLoanModule(), address(_flashAngle));
        assertEq(_treasury.flashLoanModule(), address(_flashAngle));
    }

    // ================================= AddFlashLoanerTreasuryRole ================================

    function test_addFlashLoanerTreasuryRole_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
    }

    function test_addFlashLoanerTreasuryRole_ZeroFlashLoandModule() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
        assertEq(_coreBorrow.isFlashLoanerTreasury(address(_treasury)), true);
        assertEq(_coreBorrow.hasRole(FLASHLOANER_TREASURY_ROLE, address(_treasury)), true);
    }

    function test_addFlashLoanerTreasuryRole_Normal() public {
        vm.startPrank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
        vm.stopPrank();
        assertEq(_coreBorrow.isFlashLoanerTreasury(address(_treasury)), true);
        assertEq(_coreBorrow.hasRole(FLASHLOANER_TREASURY_ROLE, address(_treasury)), true);
        assertEq(_coreBorrow.flashLoanModule(), address(_flashAngle));
        assertEq(_treasury.flashLoanModule(), address(_flashAngle));
        assertEq(_flashAngle.stablecoinsSupported(address(_treasury)), true);
    }

    // ================================= RemoveFlashLoanerTreasuryRole ================================

    function test_removeFlashLoanerTreasuryRole_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.removeFlashLoanerTreasuryRole(address(_treasury));
    }

    function test_removeFlashLoanerTreasuryRole_ZeroFlashLoanModule() public {
        vm.startPrank(_GOVERNOR);
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
        _coreBorrow.removeFlashLoanerTreasuryRole(address(_treasury));
        vm.stopPrank();
        assertEq(_coreBorrow.isFlashLoanerTreasury(address(_treasury)), false);
        assertEq(_coreBorrow.hasRole(FLASHLOANER_TREASURY_ROLE, address(_treasury)), false);
    }

    function test_removeFlashLoanerTreasuryRole_Normal() public {
        vm.startPrank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
        _coreBorrow.addFlashLoanerTreasuryRole(address(_treasury));
        _coreBorrow.removeFlashLoanerTreasuryRole(address(_treasury));
        vm.stopPrank();
        assertEq(_coreBorrow.isFlashLoanerTreasury(address(_treasury)), false);
        assertEq(_coreBorrow.hasRole(FLASHLOANER_TREASURY_ROLE, address(_treasury)), false);
        assertEq(_coreBorrow.flashLoanModule(), address(_flashAngle));
        assertEq(_treasury.flashLoanModule(), address(0));
        assertEq(_flashAngle.stablecoinsSupported(address(_treasury)), false);
    }

    // ================================= SetCore ================================

    function test_setCore_NotGovernor() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.setCore(ICoreBorrow(address(_treasury)));
    }

    function test_setCore_GoodGovernorNoFlashLoanModule() public {
        CoreBorrow coreBorrowRevert = CoreBorrow(
            _deployUpgradeable(address(proxyAdmin), address(_coreBorrowImplem), "")
        );
        coreBorrowRevert.initialize(_GOVERNOR, _GUARDIAN);

        vm.expectEmit(true, true, true, true);
        emit CoreBorrow.CoreUpdated(address(coreBorrowRevert));
        vm.prank(_GOVERNOR);
        _coreBorrow.setCore(ICoreBorrow(address(coreBorrowRevert)));
    }

    function test_setCore_GoodGovernorAndFlashLoanModule() public {
        CoreBorrow coreBorrowRevert = CoreBorrow(
            _deployUpgradeable(address(proxyAdmin), address(_coreBorrowImplem), "")
        );
        coreBorrowRevert.initialize(_GOVERNOR, _GUARDIAN);

        vm.startPrank(_GOVERNOR);
        _coreBorrow.setFlashLoanModule(address(_flashAngle));
        vm.expectEmit(true, true, true, true);
        emit CoreBorrow.CoreUpdated(address(coreBorrowRevert));
        _coreBorrow.setCore(ICoreBorrow(address(coreBorrowRevert)));
        vm.stopPrank();
        assertEq(address(_flashAngle.core()), address(coreBorrowRevert));
    }

    function test_setCore_WrongGovernor() public {
        CoreBorrow coreBorrowRevert = CoreBorrow(
            _deployUpgradeable(address(proxyAdmin), address(_coreBorrowImplem), "")
        );
        coreBorrowRevert.initialize(_GOVERNOR_POLYGON, _alice);

        vm.expectRevert(CoreBorrow.InvalidCore.selector);
        vm.prank(_GOVERNOR);
        _coreBorrow.setCore(ICoreBorrow(address(coreBorrowRevert)));
    }

    // ================================= GrantGuardianRole ================================

    function test_grantGuardianRole_NotGuardian() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.grantRole(GUARDIAN_ROLE, _alice);
    }

    function test_grantGuardianRole_Normal() public {
        vm.prank(_GOVERNOR);
        _coreBorrow.grantRole(GUARDIAN_ROLE, _alice);
        assertEq(_coreBorrow.isGovernorOrGuardian(_alice), true);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _alice), true);
    }

    // ================================= RevokeGuardianRole ================================

    function test_revokeGuardianRole_NotGuardian() public {
        vm.expectRevert();
        vm.prank(_alice);
        _coreBorrow.revokeRole(GUARDIAN_ROLE, _alice);
    }

    function test_revokeGuardianRole_Normal() public {
        vm.startPrank(_GOVERNOR);
        _coreBorrow.grantRole(GUARDIAN_ROLE, _alice);
        _coreBorrow.revokeRole(GUARDIAN_ROLE, _alice);
        vm.stopPrank();
        assertEq(_coreBorrow.isGovernorOrGuardian(_alice), false);
        assertEq(_coreBorrow.hasRole(GUARDIAN_ROLE, _alice), false);
    }
}
