// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDividendDistributor} from "./interfaces/IDividendDistributor.sol";

contract ProjectToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public immutable maxSupply;

    IDividendDistributor public dividendDistributor;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    event DistributorSet(address indexed distributor);

    /**
     * @param name          Nombre del token
     * @param symbol        Simbolo del token
     * @param initialSupply Tokens iniciales acreditados al projectOwner
     * @param _maxSupply    Cap. max. de supply
     * @param projectOwner  Recibe MINTER_ROLE y PAUSER_ROLE (creador del proyecto)
     * @param platformAdmin Recibe DEFAULT_ADMIN_ROLE y PAUSER_ROLE (plataforma)
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _maxSupply,
        address projectOwner,
        address platformAdmin
    ) ERC20(name, symbol) {
        require(_maxSupply > 0, "PT: max supply = 0");
        require(initialSupply <= _maxSupply, "PT: initial > max");
        require(projectOwner != address(0), "PT: zero project owner");
        require(platformAdmin != address(0), "PT: zero platform admin");

        maxSupply = _maxSupply;

        // Roles
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin); // plataforma administra roles
        _grantRole(PAUSER_ROLE, platformAdmin); // emergency override
        _grantRole(MINTER_ROLE, projectOwner); // creador mintea
        _grantRole(PAUSER_ROLE, projectOwner); // creador pausa su proyecto

        if (initialSupply > 0) {
            _mint(projectOwner, initialSupply);
        }
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "PT: mint to zero");
        require(amount > 0, "PT: amount = 0");
        require(totalSupply() + amount <= maxSupply, "PT: cap exceeded");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) public override nonReentrant whenNotPaused {
        require(amount > 0, "PT: amount = 0");
        super.burn(amount);
        emit Burned(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public override nonReentrant whenNotPaused {
        require(amount > 0, "PT: amount = 0");
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        super._update(from, to, value);

        // Notificar al distributor solo en transferencias entre holders
        // (no en mint: from == 0, ni en burn: to == 0)
        if (from != address(0) && to != address(0)) {
            if (address(dividendDistributor) != address(0)) {
                dividendDistributor.onTokenTransfer(from, to, value);
            }
        }
    }

    // Solo DEFAULT_ADMIN_ROLE puede conectar el distributor
    function setDistributor(address _distributor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_distributor != address(0), "PT: zero distributor");
        dividendDistributor = IDividendDistributor(_distributor);
        emit DistributorSet(_distributor);
    }
}
