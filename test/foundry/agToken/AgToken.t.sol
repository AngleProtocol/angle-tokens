// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { stdStorage, StdStorage } from "forge-std/Test.sol";
import "../BaseTest.test.sol";
import "../../../contracts/mock/MockTreasury.sol";
import { IAgToken, AgToken } from "../../../contracts/agToken/AgToken.sol";
import { MockTreasury } from "../../../contracts/mock/MockTreasury.sol";

contract AgTokenTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));

    AgToken internal _agToken;
    MockTreasury internal _treasury;
    AgToken internal _agTokenImplem;

    string constant _NAME = "Angle stablecoin gold";
    string constant _SYMBOL = "agGold";

    function setUp() public override {
        super.setUp();

        _agTokenImplem = new AgToken();
        bytes memory emptyData;
        _agToken = AgToken(deployUpgradeable(address(_agTokenImplem), emptyData));

        _treasury = new MockTreasury(
            IAgToken(address(_agToken)),
            _GOVERNOR,
            _GUARDIAN,
            address(0),
            address(0),
            address(0)
        );

        _agToken.initialize(_NAME, _SYMBOL, address(_treasury));

        vm.startPrank(_GOVERNOR);
        _treasury.setStablecoin(_agToken);
        _treasury.addMinter(_agToken, _alice);
        vm.stopPrank();
    }

    // ================================= INITIALIZE ================================

    function test_initialize_Constructor() public {
        assertEq(_agToken.name(), _NAME);
        assertEq(_agToken.symbol(), _SYMBOL);
        assertEq(_agToken.decimals(), 18);
        assertEq(_agToken.treasury(), address(_treasury));
    }

    function test_initialize_AlreadyInitalizeFail() public {
        string memory name2 = "Angle stablecoin XXX";
        string memory symbol2 = "agXXX";
        vm.expectRevert();
        _agToken.initialize(name2, symbol2, _alice);
    }

    function test_initialize_WrongTreasuryAddress() public {
        string memory name2 = "Angle stablecoin XXX";
        string memory symbol2 = "agXXX";
        MockTreasury treasury = new MockTreasury(
            IAgToken(address(0)),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        );
        bytes memory emptyData;
        _agToken = AgToken(deployUpgradeable(address(_agTokenImplem), emptyData));

        vm.expectRevert(AgToken.InvalidTreasury.selector);
        _agToken.initialize(name2, symbol2, address(treasury));
    }

    // ================================= MINT ================================

    function test_mint_WrongSender() public {
        vm.expectRevert(AgToken.NotMinter.selector);
        vm.prank(_bob);
        _agToken.mint(_hacker, 1e18);
    }

    function test_mint_ZeroAddress() public {
        vm.expectRevert("ERC20: mint to the zero address");
        vm.prank(_alice);
        _agToken.mint(address(0), 1e18);
    }

    function test_mint_Normal() public {
        uint256 amount = 1e18;
        vm.prank(_alice);
        _agToken.mint(_alice, amount);
        assertEq(_agToken.balanceOf(_alice), amount);
        assertEq(_agToken.totalSupply(), amount);
    }

    // ================================= BurnStablecoin ================================

    function test_burnStablecoin_BurnStablecoin() public {
        uint256 amount = 1e18;
        vm.startPrank(_alice);
        _agToken.mint(_alice, amount);
        _agToken.burnStablecoin(amount);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_alice), 0);
        assertEq(_agToken.totalSupply(), 0);
    }

    function test_burnStablecoin_BurnGreaterThanBalance() public {
        uint256 amount = 1e18;
        vm.startPrank(_alice);
        _agToken.mint(_alice, amount);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        _agToken.burnStablecoin(amount + 1);
        vm.stopPrank();
    }

    // ================================= BurnSelf ================================

    function test_burnSelf_NotMinter() public {
        vm.expectRevert(AgToken.NotMinter.selector);
        _agToken.burnSelf(1e18, _alice);
    }

    function test_burnSelf_Normal() public {
        uint256 amount = 1e18;
        vm.startPrank(_alice);
        _agToken.mint(_alice, amount);
        _agToken.burnSelf(amount, _alice);
        vm.stopPrank();
        assertEq(_agToken.balanceOf(_alice), 0);
        assertEq(_agToken.totalSupply(), 0);
    }

    // ================================= BurnFrom ================================

    function test_burnFrom_NotMinter() public {
        vm.prank(_bob);
        vm.expectRevert(AgToken.NotMinter.selector);
        _agToken.burnFrom(1e18, _bob, _alice);
    }

    function test_burnFrom_NoApproval() public {
        vm.prank(_alice);
        vm.expectRevert(AgToken.BurnAmountExceedsAllowance.selector);
        _agToken.burnFrom(1e18, _alice, _bob);
    }

    function test_burnFrom_WithApproval() public {
        uint256 amount = 1e18;
        vm.startPrank(_alice);
        _agToken.mint(_alice, amount);
        _agToken.approve(_bob, amount * 2);
        vm.stopPrank();
        assertEq(_agToken.allowance(_alice, _bob), amount * 2);

        vm.prank(_alice);
        _agToken.burnFrom(amount, _alice, _bob);

        assertEq(_agToken.balanceOf(_alice), 0);
        assertEq(_agToken.totalSupply(), 0);
        assertEq(_agToken.allowance(_alice, _bob), amount);
    }

    function test_burnFrom_WithoutApprovalBurnerIsSender() public {
        uint256 amount = 1e18;
        vm.startPrank(_alice);
        _agToken.mint(_alice, amount);
        _agToken.burnFrom(amount, _alice, _alice);
        vm.stopPrank();

        assertEq(_agToken.balanceOf(_alice), 0);
        assertEq(_agToken.totalSupply(), 0);
    }

    // ================================= AddMinter ================================

    function test_addMinter_NotTreasury() public {
        vm.expectRevert(AgToken.NotTreasury.selector);
        _agToken.addMinter(_alice);
    }

    function test_addMinter_MinterToggled() public {
        vm.prank(_GOVERNOR);
        _treasury.addMinter(_agToken, _alice);
        assert(_agToken.isMinter(_alice));
    }

    // ================================= RemoveMinter ================================

    function test_removeMinter_NotTreasury() public {
        vm.expectRevert(AgToken.InvalidSender.selector);
        _agToken.removeMinter(_alice);
    }

    function test_removeMinter_Normal() public {
        vm.prank(_GOVERNOR);
        _treasury.addMinter(_agToken, _bob);
        assertTrue(_agToken.isMinter(_bob));

        vm.prank(_GOVERNOR);
        _treasury.removeMinter(_agToken, _bob);
        assertFalse(_agToken.isMinter(_bob));
    }

    // ================================= SetTreasury ================================

    function test_setTreasury_NotTreasury() public {
        vm.expectRevert(AgToken.NotTreasury.selector);
        vm.prank(_alice);
        _agToken.setTreasury(_alice);
    }

    function test_setTreasury_Normal() public {
        vm.prank(_GOVERNOR);
        _treasury.setTreasury(address(_agToken), _alice);

        assertEq(_agToken.treasury(), _alice);
    }

    function test_setTreasury_NormalReset() public {
        vm.prank(_GOVERNOR);
        _treasury.setTreasury(address(_agToken), _alice);
        vm.prank(_alice);
        _agToken.setTreasury(address(_treasury));

        assertEq(_agToken.treasury(), address(_treasury));
    }
}
