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
        require(_platformAdmin != address(0), "Admin cannot be zero address");
        platformAdmin = _platformAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        _grantRole(CREATOR_ROLE, platformAdmin);
    }

    function createProject(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address projectOwner
    ) external onlyRole(CREATOR_ROLE) nonReentrant whenNotPaused returns (uint256 projectId, address tokenAddress) {
        // CHECKS
        require(bytes(name).length > 0, "PF: empty name");
        require(bytes(symbol).length > 0, "PF: empty symbol");
        require(projectOwner != address(0), "PF: zero owner");
        require(maxSupply > 0, "PF: max supply = 0");

        projectId = ++projectCount;

        // Precalcular un salt unico usando el ID del proyecto
        bytes32 salt = keccak256(abi.encodePacked(projectId));

        // Precalcular la direccion del token usando la funcion helper
        tokenAddress = predictTokenAddress(name, symbol, initialSupply, maxSupply, projectOwner, salt);

        // EFFECTS (Cambios de estado interno)
        projects[projectId] = ProjectInfo({
            tokenAddress: tokenAddress, projectOwner: projectOwner, name: name, symbol: symbol, exists: true
        });

        tokenToProject[tokenAddress] = projectId;

        emit ProjectCreated(projectId, tokenAddress, projectOwner, name, symbol, initialSupply, maxSupply);

        // INTERACTIONS (Llamada externa / Creación del contrato)
        ProjectToken token =
            new ProjectToken{salt: salt}(name, symbol, initialSupply, maxSupply, projectOwner, platformAdmin);

        // Verificación de seguridad extra por si las direcciones no coinciden
        require(address(token) == tokenAddress, "PF: deploy address mismatch");
    }

    /**
     * @notice Predice la direccion que tendra el ProjectToken desplegado mediante CREATE2.
     */
    function predictTokenAddress(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address projectOwner,
        bytes32 salt
    ) public view returns (address) {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ProjectToken).creationCode,
                abi.encode(name, symbol, initialSupply, maxSupply, projectOwner, platformAdmin)
            )
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
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

    // Modificado para usar la view publica interna si fuera necesario externamente
    function isRegistered(address tokenAddress) external view returns (bool) {
        return tokenToProject[tokenAddress] != 0;
    }
}
