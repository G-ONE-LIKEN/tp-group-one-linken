# Linken (LKN) — Token de Energías Renovables

Monorepo con contrato ERC-20 auditado + frontend mínimo para interactuar desde el navegador.

---

## Índice

1. [Estructura del monorepo](#estructura-del-monorepo)
2. [Decisiones de arquitectura](#decisiones-de-arquitectura)
3. [Prerequisitos](#prerequisitos)
4. [Setup — Contratos](#setup--contratos)
5. [Tests y coverage](#tests-y-coverage)
6. [Análisis estático con Slither](#análisis-estático-con-slither)
7. [Setup — Frontend](#setup--frontend)
8. [Variables de entorno](#variables-de-entorno)
9. [Checklist de seguridad](#checklist-de-seguridad)
10. [Deploy oficial (leer antes de ejecutar)](#deploy-oficial-leer-antes-de-ejecutar)

---

## Estructura del monorepo

```
linken/
├── contracts/          # Foundry: contrato, tests, scripts
│   ├── src/
│   │   └── Linken.sol
│   ├── test/
│   │   └── Linken.t.sol
│   ├── script/
│   │   └── DeployLinken.s.sol
│   ├── foundry.toml
│   └── remappings.txt
├── frontend/           # Next.js + RainbowKit + wagmi v2 + viem
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   └── lib/
│   └── package.json
├── .gitignore
└── README.md
```

---

## Decisiones de arquitectura

### Monorepo
Contratos y frontend viven en el mismo repositorio para simplificar el flujo:
un solo `git clone`, referencias cruzadas claras entre el ABI del contrato
y el frontend, y un único historial de cambios para la entrega.

### OpenZeppelin v5
Se eligió OZ v5 (última versión estable con soporte activo) porque:
- Compatibilidad nativa con Solidity 0.8.24
- `ERC20Pausable` usa `_update` en lugar del deprecado `_beforeTokenTransfer`
- `Ownable` requiere pasar `initialOwner` explícitamente (más seguro que `msg.sender` implícito)
- `ReentrancyGuard` mejorado con menor overhead de gas

### Solidity 0.8.24
- Overflow/underflow revertidos por defecto (sin `SafeMath`)
- Custom errors disponibles
- Última versión estable al momento del desarrollo

### Stack frontend
- **RainbowKit v2**: UI de conexión de wallet lista para usar, soporte multi-wallet
- **wagmi v2**: hooks de React para leer/escribir en blockchain
- **viem**: librería de bajo nivel para interactuar con EVM, reemplaza a ethers.js
- **Next.js 14**: App Router, SSR compatible con wagmi v2

---

## Prerequisitos

### Node.js (requerido para el frontend)

```bash
# Arch Linux
sudo pacman -S nodejs npm

# Ubuntu / Debian
sudo apt install nodejs npm

# macOS
brew install node

# Verificar
node --version   # >= 18
npm --version
```

### Foundry (requerido para los contratos)

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc   # o ~/.zshrc en Arch/zsh
foundryup
forge --version
cast --version
```

### Slither (opcional, para análisis estático)

```bash
pip install slither-analyzer --break-system-packages
slither --version
```

---

## Setup — Contratos

```bash
cd contracts

# 1. Instalar dependencias
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std

# 2. Variables de entorno
cp .env.example .env
# Editar .env con tu SEPOLIA_RPC_URL y ETHERSCAN_API_KEY

# 3. Compilar
forge build

# 4. Correr tests
forge test -vv
```

---

## Tests y coverage

```bash
cd contracts

# Todos los tests con output detallado
forge test -vv

# Solo fuzz tests
forge test --match-test testFuzz -vv

# Coverage (apuntar a >= 95%)
forge coverage

# Coverage con reporte HTML
forge coverage --report lcov
genhtml lcov.info --output-dir coverage-report
# Abrir coverage-report/index.html en el navegador
```

### Tests incluidos

| Test | Tipo | Qué verifica |
|---|---|---|
| `test_InitialSupplyGoesToOwner` | Unit | Supply inicial al deployer |
| `test_NameAndSymbol` | Unit | Nombre y símbolo correctos |
| `test_OwnerCanMint` | Unit | Owner puede mintear |
| `test_NonOwnerCannotMint` | Unit | No-owner no puede mintear |
| `test_MintToZeroAddressReverts` | Unit | Revierte en address cero |
| `test_MintZeroAmountReverts` | Unit | Revierte si amount = 0 |
| `test_MintBeyondCapReverts` | Unit | No supera MAX_SUPPLY |
| `test_MintUpToCapSucceeds` | Unit | Puede llegar exactamente al cap |
| `test_HolderCanBurnOwnTokens` | Unit | Cualquier holder puede quemar |
| `test_BurnZeroReverts` | Unit | Revierte si burn(0) |
| `test_BurnFromWithAllowance` | Unit | burnFrom con allowance |
| `test_BurnFromWithoutAllowanceReverts` | Unit | burnFrom sin allowance revierte |
| `test_OwnerCanPauseAndUnpause` | Unit | Circuit-breaker funciona |
| `test_NonOwnerCannotPause` | Unit | No-owner no puede pausar |
| `test_TransferBlockedWhenPaused` | Unit | Transfer bloqueada si paused |
| `test_MintBlockedWhenPaused` | Unit | Mint bloqueado si paused |
| `test_BurnBlockedWhenPaused` | Unit | Burn bloqueado si paused |
| `test_MintEmitsMintedEvent` | Unit | Evento Minted emitido |
| `test_BurnEmitsBurnedEvent` | Unit | Evento Burned emitido |
| `test_ReentrancyOnBurnFails` | Unit | Ataque de reentrancy falla |
| `testFuzz_MintAnyValidAmount` | Fuzz | Mint con cualquier monto válido |
| `testFuzz_BurnAnyValidAmount` | Fuzz | Burn con cualquier monto válido |
| `testFuzz_TransferAnyValidAmount` | Fuzz | Transfer con cualquier monto |
| `testFuzz_MintNeverExceedsCap` | Fuzz | Cap nunca superado |
| `invariant_TotalSupplyNeverExceedsCap` | Invariant | Supply <= MAX en todo momento |

---

## Análisis estático con Slither

```bash
cd contracts

# Instalar si no está instalado
pip install slither-analyzer --break-system-packages

# Correr análisis
slither src/Linken.sol --config-file slither.config.json

# Generar reporte
slither src/Linken.sol --json slither-report.json
```

`slither.config.json` sugerido:

```json
{
  "filter_paths": "lib/",
  "solc_remaps": [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
  ]
}
```

Hallazgos conocidos y su resolución:
- **erc20-unchecked-transfer**: resuelto usando `SafeERC20` o verificando que OZ ya lo maneja internamente
- **reentrancy**: mitigado con `ReentrancyGuard` + patrón CEI

---

## Setup — Frontend

```bash
cd frontend

# 1. Instalar dependencias
npm install

# 2. Variables de entorno
cp .env.example .env.local
# Completar NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID y NEXT_PUBLIC_LINKEN_ADDRESS

# 3. Correr en desarrollo
npm run dev
# Abrir http://localhost:3000
```

### Obtener WalletConnect Project ID

1. Ir a https://cloud.walletconnect.com
2. Crear cuenta gratuita
3. Crear nuevo proyecto
4. Copiar el Project ID al `.env.local`

---

## Variables de entorno

### contracts/.env

```bash
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
ETHERSCAN_API_KEY=<tu_api_key>    # https://etherscan.io/myapikey
DEPLOYER_ADDRESS=<tu_address_0x>

# Después del deploy:
LINKEN_ADDRESS=
```

### frontend/.env.local

```bash
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=<tu_project_id>
NEXT_PUBLIC_LINKEN_ADDRESS=<address_del_contrato>
```

> **IMPORTANTE**: `.env` y `.env.local` están en `.gitignore`.
> Nunca commitear claves privadas, API keys ni seeds.
> Verificar con `git status` antes de cada push.

---

## Checklist de seguridad

| Item | Estado | Detalle |
|---|---|---|
| ReentrancyGuard | ✅ | `mint`, `burn`, `burnFrom` protegidos |
| Patrón CEI | ✅ | Checks → Effects → Interactions en todas las funciones de escritura |
| Overflow | ✅ | Solidity 0.8.24, sin `unchecked` salvo donde se justifica |
| Access control | ✅ | `onlyOwner` en `mint`, `pause`, `unpause` |
| Pausable | ✅ | Circuit-breaker en transferencias, mint y burn |
| Cap de supply | ✅ | `MAX_SUPPLY` = 1.000.000 LKN |
| Sin loops | ✅ | No hay iteraciones sobre arrays ni envío de ETH en loops |
| Sin ETH | ✅ | El contrato no recibe ni envía ETH |
| Front-running | ✅ | No aplica: mint es solo-owner, burn no tiene incentivo de MEV |
| .env gitignored | ✅ | `.env`, `.env.local` en `.gitignore` |
| Tests ≥ 95% | ✅ | 25 tests: unit + fuzz + invariant |

---

## Deploy oficial (leer antes de ejecutar)

> ⚠️ **En blockchain no hay rollbacks. El contrato queda en la red para siempre.**
> Completar todo el checklist antes de ejecutar el deploy.

### Pasos previos obligatorios

- [ ] `forge test -vv` — todos los tests en verde
- [ ] `forge coverage` — coverage ≥ 95%
- [ ] Slither corrido y hallazgos revisados
- [ ] `.env` completo con RPC URL y API key de Etherscan
- [ ] Wallet con SepoliaETH para gas (faucet: https://cloud.google.com/application/web3/faucet/ethereum/sepolia)
- [ ] Revisión en grupo del contrato final

### Comandos de deploy

```bash
cd contracts
source .env

# 1. Deploy
forge script script/DeployLinken.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --account dev \
  --broadcast

# 2. Guardar la address que imprime y agregarla al .env
# LINKEN_ADDRESS=0x...

# 3. Verificar en Etherscan
forge verify-contract $LINKEN_ADDRESS src/Linken.sol:Linken \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia

# 4. Actualizar frontend/.env.local con la nueva address
# 5. npm run build en frontend para verificar que compila
```

---

## Changelog

| Versión | Fecha | Cambio |
|---|---|---|
| 0.1.0 | 2025-05 | Setup inicial: contrato + tests + frontend |
