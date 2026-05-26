// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// contracts/src/LKNSale.sol

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LinkenToken} from "./LinkenToken.sol";
import {ProjectRegistry} from "./ProjectRegistry.sol";

/**
 * @title LKNSale
 * @notice Pasarela de compra de LKN con USDC.
 *
 * Flujo:
 *   1. Inversor aprueba USDC a este contrato.
 *   2. Inversor llama buyLKN(projectId, usdcAmount).
 *   3. El contrato consulta el precio vigente al ProjectRegistry.
 *   4. Calcula cuántos LKN corresponden: lknAmount = usdcAmount * 1e18 / price
 *   5. Transfiere USDC del inversor al treasury.
 *   6. Mintea LKN al inversor.
 *   7. Emite evento TokensPurchased (indexable off-chain por proyecto).
 *
 * Tabla de conversión:
 *   price = USDC por LKN con 6 decimales.
 *   lknAmount = (usdcAmount * 1e18) / price
 *
 *   Ejemplo early bird: price = 100000 (0.10 USDC/LKN)
 *     usdcAmount = 10_000_000 (10 USDC)
 *     lknAmount  = 10_000_000 * 1e18 / 100_000 = 100 LKN
 *
 *   Ejemplo standard: price = 250000 (0.25 USDC/LKN)
 *     usdcAmount = 10_000_000 (10 USDC)
 *     lknAmount  = 10_000_000 * 1e18 / 250_000 = 40 LKN
 */
contract LKNSale is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    LinkenToken public immutable lkn;
    IERC20 public immutable usdc;
    ProjectRegistry public immutable registry;
    address public immutable treasury;

    uint256 public totalUsdcCollected;

    event TokensPurchased(
        address indexed buyer,
        uint256 indexed projectId,
        uint256 usdcAmount,
        uint256 lknAmount,
        uint256 price,
        ProjectRegistry.Stage stage
    );

    constructor(address _lkn, address _usdc, address _registry, address _treasury, address platformAdmin) {
        require(_lkn != address(0), "SALE: zero lkn");
        require(_usdc != address(0), "SALE: zero usdc");
        require(_registry != address(0), "SALE: zero registry");
        require(_treasury != address(0), "SALE: zero treasury");
        require(platformAdmin != address(0), "SALE: zero admin");

        lkn = LinkenToken(_lkn);
        usdc = IERC20(_usdc);
        registry = ProjectRegistry(_registry);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, platformAdmin);
    }

    /**
     * @notice Compra LKN pagando USDC para participar en un proyecto.
     * @param projectId  ID del proyecto en el que se invierte.
     * @param usdcAmount Cantidad de USDC a pagar (6 decimales).
     */
    function buyLKN(uint256 projectId, uint256 usdcAmount) external nonReentrant whenNotPaused {
        // Checks
        require(usdcAmount > 0, "SALE: amount = 0");

        ProjectRegistry.Project memory project = registry.getProject(projectId);
        require(project.stage != ProjectRegistry.Stage.PAUSED, "SALE: project paused");

        uint256 price = registry.currentPrice(projectId);
        require(price > 0, "SALE: invalid price");

        // Calcular LKN: usdcAmount tiene 6 decimales, LKN tiene 18
        // lknAmount = usdcAmount * 1e18 / price
        uint256 lknAmount = (usdcAmount * 1e18) / price;
        require(lknAmount > 0, "SALE: lkn amount too small");

        // Effects
        totalUsdcCollected += usdcAmount;

        // Interactions — CEI: primero cobrar, después mintear
        usdc.safeTransferFrom(msg.sender, treasury, usdcAmount);
        lkn.mint(msg.sender, lknAmount);

        emit TokensPurchased(msg.sender, projectId, usdcAmount, lknAmount, price, project.stage);
    }

    // ── Circuit-breaker ──────────────────────────────────────
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
