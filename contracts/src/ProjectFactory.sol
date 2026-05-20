// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ProjectToken} from "./ProjectToken.sol";

contract ProjectFactory is AccessControl, Pausable, ReentrancyGuard {
    address public immutable platformAdmin;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    struct ProjectInfo {
        address tokenAddress;
        address projectOwner;
        string name;
        string symbol;
        bool exists;
    }

    mapping(uint256 => ProjectInfo) public projects;
    mapping(address => uint256) public tokenToProject;
    uint256 public projectCount;

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed tokenAddress,
        address indexed projectOwner,
        string name,
        string symbol,
        uint256 initialSupply,
        uint256 maxSupply
    );

    constructor(address _platformAdmin) {
        platformAdmin = _platformAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        // El admin tambien puede crear proyectos directamente
        _grantRole(CREATOR_ROLE, platformAdmin);
    }

    function createProject(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address projectOwner
    ) external onlyRole(CREATOR_ROLE) nonReentrant whenNotPaused returns (uint256 projectId, address tokenAddress) {
        require(bytes(name).length > 0, "PF: empty name");
        require(bytes(symbol).length > 0, "PF: empty symbol");
        require(projectOwner != address(0), "PF: zero owner");
        require(maxSupply > 0, "PF: max supply = 0");

        projectId = ++projectCount;

        ProjectToken token = new ProjectToken(name, symbol, initialSupply, maxSupply, projectOwner, platformAdmin);
        tokenAddress = address(token);

        projects[projectId] = ProjectInfo({
            tokenAddress: tokenAddress, projectOwner: projectOwner, name: name, symbol: symbol, exists: true
        });

        tokenToProject[tokenAddress] = projectId;

        emit ProjectCreated(projectId, tokenAddress, projectOwner, name, symbol, initialSupply, maxSupply);
    }

    // ── Circuit-breaker de la Factory ────────────────────────
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ── Views ────────────────────────────────────────────────
    function getProject(uint256 projectId) external view returns (ProjectInfo memory) {
        require(projects[projectId].exists, "PF: not found");
        return projects[projectId];
    }

    function isRegistered(address tokenAddress) external view returns (bool) {
        return tokenToProject[tokenAddress] != 0;
    }
}
