// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdStorage, StdStorage } from "forge-std/Test.sol";
import "../BaseTest.test.sol";
import { MockToken } from "contracts/mock/MockToken.sol";
import { MockFlashLoanReceiver } from "contracts/mock/MockFlashLoanReceiver.sol";
import { MockCoreBorrow, ICoreBorrow } from "contracts/mock/MockCoreBorrow.sol";
import { FlashAngle, IFlashAngle, IERC3156FlashBorrower } from "contracts/flashloan/FlashAngle.sol";
import { MockTreasury } from "contracts/mock/MockTreasury.sol";
import { IAgToken } from "contracts/interfaces/IAgToken.sol";

contract FlashAngleTest is BaseTest {
    using stdStorage for StdStorage;

    MockToken internal _token;
    MockTreasury internal _treasury;
    MockFlashLoanReceiver internal _flashLoanReceiver;
    MockCoreBorrow internal _coreBorrow;
    FlashAngle internal _flashAngleImplem;
    FlashAngle internal _flashAngle;

    function setUp() public override {
        super.setUp();

        _token = new MockToken("agEUR", "agEUR", 18);

        _coreBorrow = new MockCoreBorrow();
        _flashLoanReceiver = new MockFlashLoanReceiver();

        _treasury = new MockTreasury(
            IAgToken(address(_token)),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );

        _flashAngleImplem = new FlashAngle();
        _flashAngle = FlashAngle(_deployUpgradeable(address(proxyAdmin), address(_flashAngleImplem), ""));
        _flashAngle.initialize(ICoreBorrow(address(_coreBorrow)));

        _coreBorrow.addStablecoinSupport(IFlashAngle(address(_flashAngle)), address(_treasury));
        _coreBorrow.toggleGovernor(_GOVERNOR);
        _coreBorrow.toggleGuardian(_GUARDIAN);
    }

    // ================================= INITIALIZE ================================

    function test_initialize_Constructor() public {
        assertEq(address(_flashAngle.core()), address(_coreBorrow));
        assertEq(address(_treasury.stablecoin()), address(_token));
        (uint256 maxBorrowable, uint64 flashLoanFee, address treasury) = _flashAngle.stablecoinMap(
            IAgToken(address(_token))
        );
        assertEq(treasury, address(_treasury));
        assertEq(flashLoanFee, 0);
        assertEq(maxBorrowable, 0);
    }

    function test_initialize_AlreadyInitiliazed() public {
        vm.expectRevert("Initializable: contract is already initialized");
        _flashAngle.initialize(ICoreBorrow(_alice));
    }

    function test_initialize_ZeroAddress() public {
        vm.expectRevert("Initializable: contract is already initialized");
        _flashAngle.initialize(ICoreBorrow(address(0)));
    }

    // ================================= AddStableCoinSupport ================================

    function test_addStablecoinSupport_NotCore() public {
        vm.expectRevert(FlashAngle.NotCore.selector);
        _flashAngle.addStablecoinSupport(_GUARDIAN);
    }

    function test_addStablecoinSupport_Normal() public {
        _treasury = new MockTreasury(
            IAgToken(address(_token)),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );
        _coreBorrow.addStablecoinSupport(IFlashAngle(address(_flashAngle)), address(_treasury));
        (uint256 maxBorrowable, uint64 flashLoanFee, address treasury) = _flashAngle.stablecoinMap(
            IAgToken(address(_token))
        );
        assertEq(treasury, address(_treasury));
        assertEq(flashLoanFee, 0);
        assertEq(maxBorrowable, 0);
    }

    // ================================= RemoveStableCoinSupport ================================

    function test_removeStablecoinSupport_NotCore() public {
        vm.expectRevert(FlashAngle.NotCore.selector);
        _flashAngle.removeStablecoinSupport(address(_treasury));
    }

    function test_removeStablecoinSupport_Normal() public {
        _coreBorrow.removeStablecoinSupport(_flashAngle, address(_treasury));
        (uint256 maxBorrowable, uint64 flashLoanFee, address treasury) = _flashAngle.stablecoinMap(
            IAgToken(address(_token))
        );
        assertEq(treasury, address(0));
        assertEq(flashLoanFee, 0);
        assertEq(maxBorrowable, 0);
    }

    // ================================= SetCore ================================

    function test_setCore_NotCore() public {
        vm.expectRevert(FlashAngle.NotCore.selector);
        _flashAngle.setCore(_alice);
    }

    function test_setCore_Normal() public {
        _coreBorrow.setCore(_flashAngle, _alice);
        assertEq(address(_flashAngle.core()), _alice);
    }

    // ================================= SetFlashLoanParameters ================================

    function test_setFlashLoanParameters_UnsupportedStablecoin() public {
        vm.expectRevert(FlashAngle.UnsupportedStablecoin.selector);
        _flashAngle.setFlashLoanParameters(IAgToken(address(0)), 1e18, 0);
    }

    function test_setFlashLoanParameters_NotGovernorOrGuardian() public {
        vm.expectRevert(FlashAngle.NotGovernorOrGuardian.selector);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 1e18, 0);
    }

    function test_setFlashLoanParameters_TooHighFee() public {
        vm.expectRevert(FlashAngle.TooHighParameterValue.selector);
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 1e18, 0);
    }

    function test_setFlashLoanParameters_Normal() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 100e18);
        (uint256 maxBorrowable, uint64 flashLoanFee, address treasury) = _flashAngle.stablecoinMap(
            IAgToken(address(_token))
        );
        assertEq(treasury, address(_treasury));
        assertEq(flashLoanFee, 5e8);
        assertEq(maxBorrowable, 100e18);
    }

    // ================================= FlashFee ================================

    function test_flashFee_UnsupportedStablecoin() public {
        vm.expectRevert(FlashAngle.UnsupportedStablecoin.selector);
        _flashAngle.flashFee(address(0), 1e18);
    }

    function test_flashFee_NormalNoFlashFee() public {
        assertEq(_flashAngle.flashFee(address(_token), 1e18), 0);
    }

    function test_flashFee_NormalWithFlashFee() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 100e18);
        assertEq(_flashAngle.flashFee(address(_token), 1e18), 5e17);
    }

    // ================================= MaxFlashLoan ================================

    function test_maxFlashLoan_NonExistingToken() public {
        assertEq(_flashAngle.maxFlashLoan(_GUARDIAN), 0);
    }

    function test_maxFlashLoan_UninitalizedParameters() public {
        assertEq(_flashAngle.maxFlashLoan(address(_token)), 0);
    }

    function test_maxFlashLoan_Normal() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 100e18);
        assertEq(_flashAngle.maxFlashLoan(address(_token)), 100e18);
    }

    // ================================= AccruteInterestToTreasury ================================

    function test_accrueInterestToTreasury_NotTreasury() public {
        vm.expectRevert(FlashAngle.NotTreasury.selector);
        _flashAngle.accrueInterestToTreasury(IAgToken(address(_token)));
    }

    function test_accureInterestToTreasury_InvalidStablecoin() public {
        vm.expectRevert(FlashAngle.NotTreasury.selector);
        _flashAngle.accrueInterestToTreasury(IAgToken(address(_token)));
    }

    function test_accrueInterestToTreasury_NormalZeroBalance() public {
        _treasury.accrueInterestToTreasury(_flashAngle);
        assertEq(_token.balanceOf(address(_flashAngle)), 0);
    }

    function test_accrueInterestToTreasury_Normal() public {
        _token.mint(address(_flashAngle), 1e18);
        _treasury.accrueInterestToTreasury(_flashAngle);
        assertEq(_token.balanceOf(address(_flashAngle)), 0);
    }

    // ================================= FlashLoan ================================

    function test_flashLoan_UnsupportedStablecoin() public {
        vm.expectRevert(FlashAngle.UnsupportedStablecoin.selector);
        _flashAngle.flashLoan(_flashLoanReceiver, _GUARDIAN, 0, "");
    }

    function test_flashloan_TooBigAmount() public {
        vm.expectRevert(FlashAngle.TooBigAmount.selector);
        _flashAngle.flashLoan(_flashLoanReceiver, address(_token), 1e18, "");
    }

    function test_flashLoan_InvalidReturnMessage() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 10000e18);

        vm.expectRevert(FlashAngle.InvalidReturnMessage.selector);
        _flashAngle.flashLoan(_flashLoanReceiver, address(_token), 1001e18, "");
    }

    function test_flashloan_TooSmallBalance() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 10000e18);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        _flashAngle.flashLoan(_flashLoanReceiver, address(_token), 100e18, "");
    }

    function test_flashLoan_Normal() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 10000e18);
        _token.mint(address(_flashLoanReceiver), 50e18);

        assertEq(_token.balanceOf(address(_flashLoanReceiver)), 50e18);
        assertEq(_token.balanceOf(address(_flashAngle)), 0);
        assertEq(_flashAngle.flashFee(address(_token), 100e18), 50e18);

        vm.expectEmit(true, true, true, true);
        emit FlashAngle.FlashLoan(address(_token), 100e18, IERC3156FlashBorrower(address(_flashLoanReceiver)));
        _flashAngle.flashLoan(_flashLoanReceiver, address(_token), 100e18, "FlashLoanReceiver");

        assertEq(_token.balanceOf(address(_flashLoanReceiver)), 0);
        assertEq(_token.balanceOf(address(_flashAngle)), 50e18);
    }

    function test_flashloan_Reentrant() public {
        vm.prank(_GOVERNOR);
        _flashAngle.setFlashLoanParameters(IAgToken(address(_token)), 5e8, 10000e18);
        _token.mint(address(_flashLoanReceiver), 50e18);

        assertEq(_token.balanceOf(address(_flashLoanReceiver)), 50e18);
        assertEq(_token.balanceOf(address(_flashAngle)), 0);
        assertEq(_flashAngle.flashFee(address(_token), 100e18), 50e18);

        vm.expectRevert("ReentrancyGuard: reentrant call");
        _flashAngle.flashLoan(_flashLoanReceiver, address(_token), 2e18, "");
    }
}
