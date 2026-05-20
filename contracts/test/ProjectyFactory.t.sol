// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// forge-lint: disable(erc20-unchecked-transfer)

import {Test} from "forge-std/Test.sol";
import {ProjectFactory} from "../src/ProjectFactory.sol";
import {ProjectToken} from "../src/ProjectToken.sol";

contract ProjectFactoryTest is Test {
    ProjectFactory factory;

    address platform = makeAddr("platform");
    address creator = makeAddr("creator");
    address alice = makeAddr("alice");

    function setUp() public {
        vm.prank(platform);
        factory = new ProjectFactory(platform);
    }

    // ── Creacion ─────────────────────────────────────────────

    function test_CreateProjectDeploysToken() public {
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("Campo Solar Mendoza", "CSM", 1000e18, 10_000e18, creator);
        assertTrue(tokenAddr != address(0));
        assertEq(factory.projectCount(), 1);
    }

    function test_CreatedTokenHasCorrectOwner() public {
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("Campo Solar Mendoza", "CSM", 1000e18, 10_000e18, creator);
        assertTrue(ProjectToken(tokenAddr).hasRole(ProjectToken(tokenAddr).MINTER_ROLE(), creator));
    }

    function test_CreatedTokenHasInitialSupply() public {
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("Campo Solar Mendoza", "CSM", 1000e18, 10_000e18, creator);
        assertEq(ProjectToken(tokenAddr).balanceOf(creator), 1000e18);
    }

    function test_NonOwnerCannotCreateProject() public {
        vm.prank(alice);
        vm.expectRevert();
        factory.createProject("X", "X", 0, 1000e18, alice);
    }

    function test_EmptyNameReverts() public {
        vm.prank(platform);
        vm.expectRevert("PF: empty name");
        factory.createProject("", "CSM", 0, 1000e18, creator);
    }

    function test_ZeroOwnerReverts() public {
        vm.prank(platform);
        vm.expectRevert("PF: zero owner");
        factory.createProject("X", "X", 0, 1000e18, address(0));
    }

    function test_ZeroMaxSupplyReverts() public {
        vm.prank(platform);
        vm.expectRevert("PF: max supply = 0");
        factory.createProject("X", "X", 0, 0, creator);
    }

    function test_ProjectRegisteredCorrectly() public {
        vm.prank(platform);
        (uint256 id, address tokenAddr) = factory.createProject("Eolico Patagonia", "EOP", 0, 5_000e18, creator);
        ProjectFactory.ProjectInfo memory info = factory.getProject(id);
        assertEq(info.tokenAddress, tokenAddr);
        assertEq(info.projectOwner, creator);
        assertEq(info.name, "Eolico Patagonia");
        assertTrue(factory.isRegistered(tokenAddr));
    }

    function test_MultipleProjectsIncrementCount() public {
        vm.startPrank(platform);
        factory.createProject("P1", "P1", 0, 1000e18, creator);
        factory.createProject("P2", "P2", 0, 1000e18, creator);
        factory.createProject("P3", "P3", 0, 1000e18, creator);
        vm.stopPrank();
        assertEq(factory.projectCount(), 3);
    }

    // ── Pausable ─────────────────────────────────────────────

    function test_PausedFactoryBlocksCreation() public {
        vm.prank(platform);
        factory.pause();

        vm.prank(platform);
        vm.expectRevert();
        factory.createProject("X", "X", 0, 1000e18, creator);
    }

    function test_UnpauseRestoresCreation() public {
        vm.startPrank(platform);
        factory.pause();
        factory.unpause();
        factory.createProject("X", "X", 0, 1000e18, creator);
        vm.stopPrank();
        assertEq(factory.projectCount(), 1);
    }

    // ── Project token — mint/burn solo owner ─────────────────

    function test_ProjectOwnerCanMint() public {
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("CSM", "CSM", 0, 10_000e18, creator);
        vm.prank(creator);
        ProjectToken(tokenAddr).mint(alice, 500e18);
        assertEq(ProjectToken(tokenAddr).balanceOf(alice), 500e18);
    }

    function test_NonOwnerCannotMintProjectToken() public {
        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("CSM", "CSM", 0, 10_000e18, creator);
        vm.prank(alice);
        vm.expectRevert();
        ProjectToken(tokenAddr).mint(alice, 500e18);
    }

    // ── Fuzz ─────────────────────────────────────────────────

    function testFuzz_CreateProjectAnyValidSupply(uint256 initial, uint256 max) public {
        max = bound(max, 1, type(uint128).max);
        initial = bound(initial, 0, max);

        vm.prank(platform);
        (, address tokenAddr) = factory.createProject("Fuzz Project", "FZZ", initial, max, creator);
        assertEq(ProjectToken(tokenAddr).balanceOf(creator), initial);
        assertEq(ProjectToken(tokenAddr).maxSupply(), max);
    }
}
