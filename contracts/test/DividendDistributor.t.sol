// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// forge-lint: disable(erc20-unchecked-transfer)

import {Test} from "forge-std/Test.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {ProjectToken} from "../src/ProjectToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC — 6 decimales como el real
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract DividendDistributorTest is Test {
    DividendDistributor distributor;
    ProjectToken token;
    MockUSDC usdc;

    address platform = makeAddr("platform");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    uint256 constant SUPPLY = 1_000_000 * 1e18;

    function setUp() public {
        // Deploy token
        vm.prank(platform);
        token = new ProjectToken("Campo Solar Mendoza", "CSM", SUPPLY, SUPPLY, platform, platform);

        // Deploy USDC mock
        usdc = new MockUSDC();

        // Deploy distributor
        vm.prank(platform);
        distributor = new DividendDistributor(address(token), address(usdc), platform);

        // Darle USDC a la plataforma para depositar
        usdc.mint(platform, 100_000 * 1e6);

        vm.prank(platform);
        usdc.approve(address(distributor), type(uint256).max);
    }

    // ── Deposit ──────────────────────────────────────────────

    function test_DepositDividendsUpdatesState() public {
        // Distribuir tokens: alice 50%, bob 50%
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY / 2);
        token.transfer(bob, SUPPLY / 2);
        vm.stopPrank();

        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        assertEq(distributor.totalDeposited(), 1_000 * 1e6);
    }

    function test_DepositZeroReverts() public {
        vm.prank(platform);
        vm.expectRevert("DD: amount = 0");
        distributor.depositDividends(0);
    }

    function test_DepositWithZeroSupplyReverts() public {
        // El supply esta en platform, no en circulacion con holders
        // Quemamos todo para simular supply = 0
        vm.startPrank(platform);
        token.burn(SUPPLY);
        vm.expectRevert("DD: no token supply");
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();
    }

    function test_NonDepositorCannotDeposit() public {
        vm.prank(alice);
        vm.expectRevert();
        distributor.depositDividends(100 * 1e6);
    }

    // ── Claim ────────────────────────────────────────────────

    function test_EqualHoldersGetEqualDividends() public {
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY / 2);
        token.transfer(bob, SUPPLY / 2);
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();

        assertApproxEqAbs(
            distributor.pendingDividends(alice),
            500 * 1e6,
            1 // tolerancia de 1 wei por redondeo
        );
        assertApproxEqAbs(distributor.pendingDividends(bob), 500 * 1e6, 1);
    }

    function test_ClaimTransfersUSDC() public {
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY);
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();

        vm.prank(alice);
        distributor.claimDividends();

        assertApproxEqAbs(usdc.balanceOf(alice), 1_000 * 1e6, 1);
    }

    function test_ClaimZeroPendingReverts() public {
        vm.prank(alice);
        vm.expectRevert("DD: nothing to claim");
        distributor.claimDividends();
    }

    function test_ClaimTwiceOnlyOnce() public {
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY);
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();

        vm.startPrank(alice);
        distributor.claimDividends();
        vm.expectRevert("DD: nothing to claim");
        distributor.claimDividends();
        vm.stopPrank();
    }

    function test_MultipleDepositsAccumulate() public {
        vm.prank(platform);
        token.transfer(alice, SUPPLY);

        vm.startPrank(platform);
        distributor.depositDividends(500 * 1e6);
        distributor.depositDividends(500 * 1e6);
        vm.stopPrank();

        assertApproxEqAbs(distributor.pendingDividends(alice), 1_000 * 1e6, 1);
    }

    function test_ProportionalDistribution() public {
        // Alice 75%, Bob 25%
        vm.startPrank(platform);
        token.transfer(alice, (SUPPLY * 75) / 100);
        token.transfer(bob, (SUPPLY * 25) / 100);
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();

        assertApproxEqAbs(distributor.pendingDividends(alice), 750 * 1e6, 10);
        assertApproxEqAbs(distributor.pendingDividends(bob), 250 * 1e6, 10);
    }

    // ── Pausable ─────────────────────────────────────────────

    function test_PausedBlocksClaim() public {
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY);
        distributor.depositDividends(1_000 * 1e6);
        distributor.pause();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        distributor.claimDividends();
    }

    function test_PausedBlocksDeposit() public {
        vm.startPrank(platform);
        token.transfer(alice, SUPPLY);
        distributor.pause();
        vm.expectRevert();
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();
    }

    // ── Fuzz ─────────────────────────────────────────────────

    function testFuzz_ProportionalPayout(uint256 aliceShare) public {
        aliceShare = bound(aliceShare, 1, SUPPLY - 1);
        uint256 bobShare = SUPPLY - aliceShare;

        vm.startPrank(platform);
        token.transfer(alice, aliceShare);
        token.transfer(bob, bobShare);
        distributor.depositDividends(1_000 * 1e6);
        vm.stopPrank();

        uint256 alicePending = distributor.pendingDividends(alice);
        uint256 bobPending = distributor.pendingDividends(bob);

        // La suma no supera lo depositado (puede haber 1-2 wei de redondeo)
        assertLe(alicePending + bobPending, 1_000 * 1e6 + 2);

        // Alice siempre obtiene mas si tiene mas tokens
        if (aliceShare > bobShare) {
            assertGe(alicePending, bobPending);
        }
    }
}
