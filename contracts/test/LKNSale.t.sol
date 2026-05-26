// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// contracts/test/LKNSale.t.sol

import {Test} from "forge-std/Test.sol";
import {LKNSale} from "../src/LKNSale.sol";
import {LinkenToken} from "../src/LinkenToken.sol";
import {ProjectRegistry} from "../src/ProjectRegistry.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract LKNSaleTest is Test {
    LKNSale sale;
    LinkenToken lkn;
    ProjectRegistry registry;
    MockUSDC usdc;

    address platform = makeAddr("platform");
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");

    uint256 constant EARLY = 100_000; // 0.10 USDC/LKN
    uint256 constant STD = 250_000; // 0.25 USDC/LKN

    uint256 projectId;

    function setUp() public {
        vm.startPrank(platform);
        lkn = new LinkenToken(platform);
        usdc = new MockUSDC();
        registry = new ProjectRegistry(platform);

        sale = new LKNSale(address(lkn), address(usdc), address(registry), treasury, platform);

        // Darle MINTER_ROLE al contrato de venta
        lkn.grantRole(lkn.MINTER_ROLE(), address(sale));

        // Registrar proyecto de prueba
        projectId = registry.registerProject("Campo Solar", "Desc", platform, EARLY, STD);
        vm.stopPrank();

        // USDC para alice
        usdc.mint(alice, 1_000 * 1e6);
        vm.prank(alice);
        usdc.approve(address(sale), type(uint256).max);
    }

    // ── Compra en FUNDING (early bird) ───────────────────────

    function test_BuyLKNFundingStage() public {
        // 10 USDC a 0.10 USDC/LKN = 100 LKN
        vm.prank(alice);
        sale.buyLKN(projectId, 10 * 1e6);

        assertEq(lkn.balanceOf(alice), 100e18);
        assertEq(usdc.balanceOf(treasury), 10 * 1e6);
    }

    function test_BuyLKNActiveStage() public {
        vm.prank(platform);
        registry.setStage(projectId, ProjectRegistry.Stage.ACTIVE);

        // 10 USDC a 0.25 USDC/LKN = 40 LKN
        vm.prank(alice);
        sale.buyLKN(projectId, 10 * 1e6);

        assertEq(lkn.balanceOf(alice), 40e18);
    }

    function test_EarlyBirdCheaperThanStandard() public {
        // Compra en FUNDING
        vm.prank(alice);
        sale.buyLKN(projectId, 10 * 1e6);
        uint256 fundingLKN = lkn.balanceOf(alice);

        // Reset — nuevo inversor en ACTIVE
        address bob = makeAddr("bob");
        usdc.mint(bob, 1_000 * 1e6);
        vm.prank(bob);
        usdc.approve(address(sale), type(uint256).max);

        vm.prank(platform);
        registry.setStage(projectId, ProjectRegistry.Stage.ACTIVE);

        vm.prank(bob);
        sale.buyLKN(projectId, 10 * 1e6);
        uint256 activeLKN = lkn.balanceOf(bob);

        assertGt(fundingLKN, activeLKN);
    }

    function test_PausedProjectReverts() public {
        vm.prank(platform);
        registry.setStage(projectId, ProjectRegistry.Stage.PAUSED);

        vm.prank(alice);
        vm.expectRevert("SALE: project paused");
        sale.buyLKN(projectId, 10 * 1e6);
    }

    function test_ZeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert("SALE: amount = 0");
        sale.buyLKN(projectId, 0);
    }

    function test_TotalUsdcCollected() public {
        vm.prank(alice);
        sale.buyLKN(projectId, 10 * 1e6);

        vm.prank(alice);
        sale.buyLKN(projectId, 5 * 1e6);

        assertEq(sale.totalUsdcCollected(), 15 * 1e6);
    }

    function test_PausedSaleReverts() public {
        vm.prank(platform);
        sale.pause();

        vm.prank(alice);
        vm.expectRevert();
        sale.buyLKN(projectId, 10 * 1e6);
    }

    function testFuzz_BuyAnyValidAmount(uint256 usdcAmount) public {
        usdcAmount = bound(usdcAmount, 1e6, 1_000 * 1e6);
        usdc.mint(alice, usdcAmount);

        vm.prank(alice);
        sale.buyLKN(projectId, usdcAmount);

        uint256 expected = (usdcAmount * 1e18) / EARLY;
        assertEq(lkn.balanceOf(alice), expected);
    }

    function test_ConstructorZeroLKNReverts() public {
        vm.expectRevert("SALE: zero lkn");

        new LKNSale(address(0), address(usdc), address(registry), treasury, platform);
    }

    function test_LKNAmountTooSmallReverts() public {
        vm.startPrank(platform);

        uint256 expensiveProject = registry.registerProject("Expensive", "Desc", platform, 1e30, 1e30 + 1);

        vm.stopPrank();

        vm.prank(alice);

        vm.expectRevert("SALE: lkn amount too small");

        sale.buyLKN(expensiveProject, 1);
    }

    function test_UnpauseRestoresSale() public {
        vm.startPrank(platform);

        sale.pause();
        sale.unpause();

        vm.stopPrank();

        vm.prank(alice);

        sale.buyLKN(projectId, 10 * 1e6);

        assertGt(lkn.balanceOf(alice), 0);
    }
}
