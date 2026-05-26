// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// contracts/src/LinkenToken.sol

/**
 * @title Linken (LKN)
 * @notice ERC-20 token para plataforma de tokenización de energías renovables.
 *
 * Decisiones de diseño:
 * - OpenZeppelin v5: última versión estable con soporte activo, mejoras de gas
 *   en ERC-20, y compatibilidad nativa con Solidity 0.8.24.
 * - ReentrancyGuard: protege mint/burn contra ataques de reentrada.
 * - Pausable: circuit-breaker de emergencia para detener transferencias.
 * - Patrón CEI (Checks-Effects-Interactions): validaciones primero,
 *   cambios de estado después, llamadas externas al final.
 * - Sin loops: no hay iteraciones sobre arrays ni envío de ETH en loops.
 * - Sin unchecked: Solidity 0.8+ previene overflow por defecto;
 *   no se usa unchecked salvo donde se justifica explícitamente.
 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDividendDistributor} from "./interfaces/IDividendDistributor.sol";

contract LinkenToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IDividendDistributor public dividendDistributor;

    // =========================================================
    // Eventos
    // =========================================================
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event DistributorSet(address indexed distributor);

    // =========================================================
    // Constructor
    // =========================================================
    constructor(address platformAdmin) ERC20("Linken", "LKN") {
        require(platformAdmin != address(0), "LKN: zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
        _grantRole(MINTER_ROLE, platformAdmin);
        _grantRole(PAUSER_ROLE, platformAdmin);
    }

    // =========================================================
    // Funciones admin (solo owner)
    // =========================================================

    /**
     * @notice Mintea `amount` tokens a `to`.
     * @dev ReentrancyGuard + CEI: checks → effects (_mint) → no interactions externas.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(to != address(0), "LKN: mint to zero");
        require(amount > 0, "LKN: amount = 0");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Pausa todas las transferencias (circuit-breaker).
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Reanuda las transferencias.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // =========================================================
    // Burn público (cualquier holder puede quemar sus tokens)
    // =========================================================

    /**
     * @notice Quema `amount` tokens propios.
     * @dev ERC20Burnable.burn ya implementa CEI internamente.
     *      ReentrancyGuard agrega una capa extra.
     */
    function burn(uint256 amount) public override nonReentrant whenNotPaused {
        // Checks
        require(amount > 0, "LKN: amount must be > 0");

        // Effects + (no interactions externas)
        super.burn(amount);

        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Quema `amount` tokens de `account` con allowance.
     */
    function burnFrom(address account, uint256 amount) public override nonReentrant whenNotPaused {
        require(amount > 0, "LKN: amount must be > 0");
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    function setDistributor(address newDistributor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newDistributor != address(0), "LKN: zero distributor");
        dividendDistributor = IDividendDistributor(newDistributor);
        emit DistributorSet(newDistributor);
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
        if (from != address(0) && to != address(0)) {
            if (address(dividendDistributor) != address(0)) {
                dividendDistributor.onTokenTransfer(from, to, value);
            }
        }
    }
}
