// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// forge-lint: disable(erc20-unchecked-transfer)

import {Test, console} from "forge-std/Test.sol";
import {Linken} from "../../src/legacy/Linken.sol";

// ============================================================
// Contrato auxiliar para test de reentrancy
//
// Subclasea Linken y sobreescribe _update para intentar llamar
// burn() de nuevo mientras ya esta ejecutando burn().
// ReentrancyGuard debe revertir la segunda entrada.
// ============================================================
contract ReentrantLinken is Linken {
    bool private _attacking;

    constructor(address initialOwner) Linken(initialOwner) {}

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);

        // Solo intenta reentrar una vez para evitar recursion infinita
        if (_attacking) {
            _attacking = false;
            // Intenta llamar burn() desde adentro de _update (reentrada)
            this.burn(value);
        }
    }

    function attackBurn(uint256 amount) external {
        _attacking = true;
        this.burn(amount);
    }
}

// ============================================================
// Suite principal
// ============================================================
contract LinkenTest is Test {
    Linken public token;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant INITIAL = 10_000 * 1e18;
    uint256 constant MAX = 1_000_000 * 1e18;

    // --------------------------------------------------------
    // Setup
    // --------------------------------------------------------

    function setUp() public {
        vm.prank(owner);
        token = new Linken(owner);
    }

    // --------------------------------------------------------
    // Deploy / supply inicial
    // --------------------------------------------------------

    function test_InitialSupplyGoesToOwner() public view {
        assertEq(token.balanceOf(owner), INITIAL);
        assertEq(token.totalSupply(), INITIAL);
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "LINKEN");
        assertEq(token.symbol(), "LKN");
    }

    function test_MaxSupplyConstant() public view {
        assertEq(token.MAX_SUPPLY(), MAX);
    }

    // --------------------------------------------------------
    // Mint — acceso
    // --------------------------------------------------------

    function test_OwnerCanMint() public {
        vm.prank(owner);
        token.mint(alice, 500 * 1e18);
        assertEq(token.balanceOf(alice), 500 * 1e18);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 * 1e18);
    }

    function test_MintToZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert("LKN: mint to zero address");
        token.mint(address(0), 100 * 1e18);
    }

    function test_MintZeroAmountReverts() public {
        vm.prank(owner);
        vm.expectRevert("LKN: amount must be > 0");
        token.mint(alice, 0);
    }

    function test_MintBeyondCapReverts() public {
        uint256 remaining = MAX - token.totalSupply();
        vm.prank(owner);
        vm.expectRevert("LKN: cap exceeded");
        token.mint(alice, remaining + 1);
    }

    function test_MintUpToCapSucceeds() public {
        uint256 remaining = MAX - token.totalSupply();
        vm.prank(owner);
        token.mint(alice, remaining);
        assertEq(token.totalSupply(), MAX);
    }

    // --------------------------------------------------------
    // Burn
    // --------------------------------------------------------

    function test_HolderCanBurnOwnTokens() public {
        vm.prank(owner);
        token.transfer(alice, 1_000 * 1e18);

        vm.prank(alice);
        token.burn(400 * 1e18);

        assertEq(token.balanceOf(alice), 600 * 1e18);
        assertEq(token.totalSupply(), INITIAL - 400 * 1e18);
    }

    function test_BurnZeroReverts() public {
        vm.prank(owner);
        vm.expectRevert("LKN: amount must be > 0");
        token.burn(0);
    }

    function test_BurnMoreThanBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        token.burn(1);
    }

    function test_BurnFromWithAllowance() public {
        vm.prank(owner);
        token.transfer(alice, 1_000 * 1e18);

        vm.prank(alice);
        token.approve(bob, 300 * 1e18);

        vm.prank(bob);
        token.burnFrom(alice, 300 * 1e18);

        assertEq(token.balanceOf(alice), 700 * 1e18);
    }

    function test_BurnFromWithoutAllowanceReverts() public {
        vm.prank(owner);
        token.transfer(alice, 1_000 * 1e18);

        vm.prank(bob);
        vm.expectRevert();
        token.burnFrom(alice, 100 * 1e18);
    }

    // --------------------------------------------------------
    // Pausable
    // --------------------------------------------------------

    function test_OwnerCanPauseAndUnpause() public {
        vm.prank(owner);
        token.pause();
        assertTrue(token.paused());

        vm.prank(owner);
        token.unpause();
        assertFalse(token.paused());
    }

    function test_NonOwnerCannotPause() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }

    function test_TransferBlockedWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        vm.expectRevert();
        token.transfer(alice, 100 * 1e18);
    }

    function test_MintBlockedWhenPaused() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        vm.expectRevert();
        token.mint(alice, 100 * 1e18);
    }

    function test_BurnBlockedWhenPaused() public {
        vm.prank(owner);
        token.transfer(alice, 500 * 1e18);

        vm.prank(owner);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.burn(100 * 1e18);
    }

    function test_TransferWorksAfterUnpause() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        token.unpause();

        vm.prank(owner);
        token.transfer(alice, 100 * 1e18);
        assertEq(token.balanceOf(alice), 100 * 1e18);
    }

    // --------------------------------------------------------
    // Eventos
    // --------------------------------------------------------

    function test_MintEmitsMintedEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Linken.Minted(alice, 100 * 1e18);
        token.mint(alice, 100 * 1e18);
    }

    function test_BurnEmitsBurnedEvent() public {
        vm.prank(owner);
        token.transfer(alice, 500 * 1e18);

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit Linken.Burned(alice, 200 * 1e18);
        token.burn(200 * 1e18);
    }

    // --------------------------------------------------------
    // Reentrancy
    // --------------------------------------------------------

    function test_ReentrancyOnBurnFails() public {
        // Desplegamos una version maliciosa del contrato que intenta
        // reentrar burn() desde dentro del hook _update.
        vm.prank(owner);
        ReentrantLinken malicious = new ReentrantLinken(owner);

        // Le minteamos tokens para que tenga saldo
        vm.prank(owner);
        malicious.mint(address(malicious), 1_000 * 1e18);

        // attackBurn activa el flag y llama burn(); desde _update
        // intenta llamar burn() de nuevo → ReentrancyGuard revierte.
        vm.expectRevert();
        malicious.attackBurn(500 * 1e18);
    }

    // --------------------------------------------------------
    // Fuzz tests
    // --------------------------------------------------------

    function testFuzz_MintAnyValidAmount(uint256 amount) public {
        // Acotamos al espacio valido
        amount = bound(amount, 1, MAX - INITIAL);

        vm.prank(owner);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), INITIAL + amount);
    }

    function testFuzz_BurnAnyValidAmount(uint256 amount) public {
        amount = bound(amount, 1, INITIAL);

        vm.prank(owner);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.burn(amount);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), INITIAL - amount);
    }

    function testFuzz_TransferAnyValidAmount(uint256 amount) public {
        amount = bound(amount, 1, INITIAL);

        vm.prank(owner);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), INITIAL - amount);
    }

    function testFuzz_MintNeverExceedsCap(uint256 amount) public {
        amount = bound(amount, MAX - INITIAL + 1, type(uint256).max / 2);

        vm.prank(owner);
        vm.expectRevert("LKN: cap exceeded");
        token.mint(alice, amount);
    }

    // --------------------------------------------------------
    // Invariant: totalSupply nunca supera MAX_SUPPLY
    // --------------------------------------------------------

    function invariant_TotalSupplyNeverExceedsCap() public view {
        assertLe(token.totalSupply(), MAX);
    }
}
