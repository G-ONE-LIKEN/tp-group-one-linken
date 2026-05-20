// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// forge-lint: disable(erc20-unchecked-transfer)

import {Test} from "forge-std/Test.sol";
import {ProjectToken} from "../src/ProjectToken.sol";
import {DividendDistributor} from "../src/DividendDistributor.sol";
import {ProjectFactory} from "../src/ProjectFactory.sol";
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

contract IntegrationTest is Test {
    ProjectFactory factory;
    ProjectToken token;
    DividendDistributor distributor;
    MockUSDC usdc;

    address platform = makeAddr("platform");
    address creator = makeAddr("creator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant SUPPLY = 1_000_000 * 1e18;

    function setUp() public {
        // 1. Deploy factory
        vm.prank(platform);
        factory = new ProjectFactory(platform);

        // 2. Crear proyecto via factory
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("Campo Solar Mendoza", "CSM", SUPPLY, SUPPLY, creator);
        token = ProjectToken(tokenAddr);

        // 3. Deploy USDC mock y distributor
        usdc = new MockUSDC();
        vm.prank(platform);
        distributor = new DividendDistributor(address(token), address(usdc), platform);

        // 4. Conectar distributor al token (solo platform como DEFAULT_ADMIN)
        vm.prank(platform);
        token.setDistributor(address(distributor));

        // 5. USDC para la plataforma
        usdc.mint(platform, 1_000_000 * 1e6);
        vm.prank(platform);
        usdc.approve(address(distributor), type(uint256).max);
    }

    // ── Flujo básico end-to-end ───────────────────────────────

    function test_FullFlow_DepositAndClaim() public {
        // Creator distribuye tokens a inversores
        vm.startPrank(creator);
        token.transfer(alice, SUPPLY / 2);
        token.transfer(bob, SUPPLY / 2);
        vm.stopPrank();

        // Plataforma deposita dividendos
        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        // Alice y Bob reclaman
        vm.prank(alice);
        distributor.claimDividends();
        vm.prank(bob);
        distributor.claimDividends();

        assertApproxEqAbs(usdc.balanceOf(alice), 500 * 1e6, 1);
        assertApproxEqAbs(usdc.balanceOf(bob), 500 * 1e6, 1);
    }

    function test_TransferBetweenHoldersAdjustsDividends() public {
        // Alice recibe todo el supply
        vm.prank(creator);
        token.transfer(alice, SUPPLY);

        // Se depositan dividendos — alice tiene derecho al 100%
        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        // Alice transfiere la mitad a Bob ANTES de reclamar
        vm.prank(alice);
        token.transfer(bob, SUPPLY / 2);

        // Los dividendos del primer depósito siguen siendo 100% de alice
        // (la corrección preserva los derechos anteriores a la transferencia)
        assertApproxEqAbs(distributor.pendingDividends(alice), 1_000 * 1e6, 2);
        assertApproxEqAbs(distributor.pendingDividends(bob), 0, 2);

        // Nuevo depósito — ahora alice y bob tienen 50/50
        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        assertApproxEqAbs(distributor.pendingDividends(alice), 1_500 * 1e6, 2);
        assertApproxEqAbs(distributor.pendingDividends(bob), 500 * 1e6, 2);
    }

    function test_NewInvestorAfterDepositGetsZero() public {
        // Se deposita ANTES de que alice tenga tokens
        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        // Alice recibe tokens DESPUÉS del depósito
        vm.prank(creator);
        token.transfer(alice, SUPPLY);

        // Alice no tiene derecho al depósito anterior
        assertEq(distributor.pendingDividends(alice), 0);
    }

    function test_ClaimAfterMultipleDeposits() public {
        vm.prank(creator);
        token.transfer(alice, SUPPLY);

        vm.startPrank(platform);
        distributor.depositDividends(300 * 1e6);
        distributor.depositDividends(300 * 1e6);
        distributor.depositDividends(400 * 1e6);
        vm.stopPrank();

        vm.prank(alice);
        distributor.claimDividends();

        assertApproxEqAbs(usdc.balanceOf(alice), 1_000 * 1e6, 3);
    }

    // ── Emergency pause end-to-end ────────────────────────────

    function test_PlatformCanPauseTokenAndDistributor() public {
        vm.prank(creator);
        token.transfer(alice, SUPPLY);

        vm.prank(platform);
        distributor.depositDividends(1_000 * 1e6);

        // Plataforma pausa ambos contratos
        vm.startPrank(platform);
        token.pause();
        distributor.pause();
        vm.stopPrank();

        // Transferencias bloqueadas
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 100 * 1e18);

        // Claims bloqueados
        vm.prank(alice);
        vm.expectRevert();
        distributor.claimDividends();

        // Plataforma reanuda
        vm.startPrank(platform);
        token.unpause();
        distributor.unpause();
        vm.stopPrank();

        // Todo funciona de nuevo
        vm.prank(alice);
        distributor.claimDividends();
        assertApproxEqAbs(usdc.balanceOf(alice), 1_000 * 1e6, 1);
    }

    // ── CREATOR_ROLE flow ─────────────────────────────────────

    function test_GrantCreatorRoleAndCreateProject() public {
        address developer = makeAddr("developer");

        bytes32 creatorRole = factory.CREATOR_ROLE(); // call sin prank
        vm.prank(platform);
        factory.grantRole(creatorRole, developer); // prank se usa aquí

        vm.prank(developer);
        (, address tokenAddr) =
            factory.createProject( // warning fix: sin "id"
                "Eolico Patagonia",
                "EOP",
                0,
                500_000 * 1e18,
                developer
            );

        assertTrue(factory.isRegistered(tokenAddr));
        assertEq(factory.projectCount(), 2);
        bytes32 minterRole = ProjectToken(tokenAddr).MINTER_ROLE();
        assertTrue(ProjectToken(tokenAddr).hasRole(minterRole, developer));
    }

    function test_RevokeCreatorRoleBlocksCreation() public {
        address developer = makeAddr("developer");

        bytes32 creatorRole = factory.CREATOR_ROLE(); // call sin prank

        vm.prank(platform);
        factory.grantRole(creatorRole, developer);

        vm.prank(platform);
        factory.revokeRole(creatorRole, developer);

        vm.prank(developer);
        vm.expectRevert();
        factory.createProject("X", "X", 0, 1000e18, developer);
    }
}
