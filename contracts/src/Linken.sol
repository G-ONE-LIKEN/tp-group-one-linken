// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Linken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ReentrancyGuard {
    /// @notice Supply inicial acreditado al deployer.
    uint256 public constant INITIAL_SUPPLY = 10_000 * 10 ** 18;

    /// @notice Cap máximo de supply para evitar mint ilimitado.
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;

    // =========================================================
    // Eventos
    // =========================================================

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    // =========================================================
    // Constructor
    // =========================================================

    constructor(address initialOwner)
        ERC20("LINKEN", "LKN")
        Ownable(initialOwner)
    {
        // CEI: no hay checks externos; efecto directo sobre el estado.
        _mint(initialOwner, INITIAL_SUPPLY);
    }

    // =========================================================
    // Funciones admin (solo owner)
    // =========================================================

    /**
     * @notice Mintea `amount` tokens a `to`.
     * @dev ReentrancyGuard + CEI: checks → effects (_mint) → no interactions externas.
     */
    function mint(address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        // Checks
        require(to != address(0), "LKN: mint to zero address");
        require(amount > 0, "LKN: amount must be > 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "LKN: cap exceeded");

        // Effects
        _mint(to, amount);

        // (no interactions externas)
        emit Minted(to, amount);
    }

    /**
     * @notice Pausa todas las transferencias (circuit-breaker).
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Reanuda las transferencias.
     */
    function unpause() external onlyOwner {
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
    function burn(uint256 amount)
        public
        override
        nonReentrant
        whenNotPaused
    {
        // Checks
        require(amount > 0, "LKN: amount must be > 0");

        // Effects + (no interactions externas)
        super.burn(amount);

        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Quema `amount` tokens de `account` con allowance.
     */
    function burnFrom(address account, uint256 amount)
        public
        override
        nonReentrant
        whenNotPaused
    {
        require(amount > 0, "LKN: amount must be > 0");
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    // =========================================================
    // Overrides requeridos por Solidity (herencia múltiple)
    // =========================================================

    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
