# Linken (LKN) — Plataforma de Tokenización de Proyectos Energéticos

Monorepo con smart contracts en Solidity (Foundry) + frontend web para interactuar con la plataforma desde el navegador.

---

## Índice

1. [Arquitectura general](#arquitectura-general)
2. [Estructura del monorepo](#estructura-del-monorepo)
3. [Smart Contracts](#smart-contracts)
4. [Flujo del sistema](#flujo-del-sistema)
5. [Prerrequisitos](#prerrequisitos)
6. [Setup — Contratos](#setup--contratos)
7. [Tests y coverage](#tests-y-coverage)
8. [Análisis estático con Slither](#análisis-estático-con-slither)
9. [Setup — Frontend](#setup--frontend)
10. [Variables de entorno](#variables-de-entorno)
11. [Deploy](#deploy)
12. [Seguridad](#seguridad)
13. [Decisiones de arquitectura (ADRs)](#decisiones-de-arquitectura-adrs)
14. [Roadmap](#roadmap)

---

## Arquitectura general

Linken es una plataforma de tokenización de proyectos de generación de energía renovable. Permite a inversores adquirir participaciones fraccionadas en parques solares, eólicos y similares mediante tokens ERC-20, y recibir dividendos proporcionales a los ingresos generados por cada proyecto.

### Contratos productivos

| Contrato | Responsabilidad |
|---|---|
| `LinkenToken.sol` | Token ERC-20 global LKN. Supply fijo emitido en el TGE, sin mint posterior. |
| `ProjectRegistry.sol` | Registro de proyectos con ciclo de vida (FUNDING → ACTIVE → PAUSED) y precios por etapa. |
| `OfferingContract.sol` | Venta primaria de LKN con precio fijo, soft cap, hard cap y refund. Activa el proyecto en el Registry al finalizar. |
| `DividendDistributor.sol` | Recibe USDC y los distribuye proporcionalmente entre holders de LKN usando el patrón pull payment. |

### Contratos deprecados (en `src/legacy/`)

| Contrato | Motivo |
|---|---|
| `LinkenToken.sol` (v1) | Reemplazado — tenía mint ilimitado y supply infinito. |
| `ProjectToken.sol` | Reemplazado — el modelo de subtokens por proyecto fue simplificado a token global LKN. |
| `ProjectFactory.sol` | Reemplazado por `ProjectRegistry.sol`. |
| `LKNSale.sol` | Reemplazado por `OfferingContract.sol`. |

---

## Estructura del monorepo

```
linken/
├── contracts/
│   ├── src/
│   │   ├── LinkenToken.sol
│   │   ├── ProjectRegistry.sol
│   │   ├── OfferingContract.sol
│   │   ├── DividendDistributor.sol
│   │   ├── interfaces/
│   │   │   └── IDividendDistributor.sol
│   │   └── legacy/
│   │       ├── ProjectToken.sol
│   │       ├── ProjectFactory.sol
│   │       └── LKNSale.sol
│   ├── test/
│   │   ├── LinkenToken.t.sol
│   │   ├── ProjectRegistry.t.sol
│   │   ├── OfferingContract.t.sol
│   │   ├── DividendDistributor.t.sol
│   │   ├── Integration.t.sol
│   │   └── legacy/
│   ├── script/
│   │   ├── DeployAll.s.sol
│   │   └── legacy/
│   ├── foundry.toml
│   └── remappings.txt
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   └── lib/
│   └── package.json
├── docs/
│   ├── 0001-monorepo.md
│   ├── 0002-openzeppelin-v5.md
│   ├── 0003-solidity-0.8.24.md
│   ├── 0004-stack-frontend.md
│   ├── 0005-access-control-roles.md
│   ├── 0006-creator-role-factory.md
│   ├── 0007-factory-pattern-project-tokens.md
│   ├── 0008-pull-payment-dividends.md
│   ├── 0009-linken-deprecado.md
│   ├── 0010-simplificacion-token-global-lkn.md  [DEPRECADO]
│   ├── 0011-token-global-tge-fijo.md
│   ├── 0012-offering-contract-tge-flow.md
│   ├── 0013-lknsale-deprecado.md
│   └── 0014-offering-registry-integration.md
└── README.md
```

---

## Smart Contracts

### LinkenToken.sol

Token ERC-20 global de la plataforma.

- **TGE (Token Generation Event)**: el supply se define en el constructor y se emite una única vez al emisor (SPE dueño del parque). No hay mint posterior.
- **Burn libre**: cualquier holder puede quemar sus tokens, reduciendo el supply circulante.
- **AccessControl**: roles separados para administración (`DEFAULT_ADMIN_ROLE`) y pausa (`PAUSER_ROLE`).
- **ReentrancyGuard**: protege burn contra ataques de reentrada.
- **DividendDistributor hook**: notifica al distributor en cada transferencia entre holders para mantener las correcciones de dividendos actualizadas.

```solidity
constructor(address platformAdmin, address tgeRecipient, uint256 tgeSupply)
```

---

### ProjectRegistry.sol

Registro central de proyectos energéticos.

- **Ciclo de vida**: `FUNDING → ACTIVE → PAUSED`
- **Precios por etapa**: `earlyBirdPrice` (FUNDING) y `standardPrice` (ACTIVE), ambos en USDC/LKN con 6 decimales.
- **CREATOR_ROLE**: solo desarrolladores aprobados pueden registrar proyectos.
- **OFFERING_ROLE**: solo `OfferingContract` autorizados pueden activar proyectos automáticamente.

```
earlyBirdPrice < standardPrice  (validado en el contrato)
```

---

### OfferingContract.sol

Venta primaria de LKN a precio fijo con garantías para el inversor.

- **Escrow de LKN**: el emisor deposita los tokens antes de abrir la ronda.
- **Soft cap**: si no se alcanza antes del deadline, los inversores pueden pedir refund.
- **Hard cap**: al alcanzarse, la ronda cierra automáticamente.
- **Activación automática**: al finalizar exitosamente, activa el proyecto en el `ProjectRegistry` (FUNDING → ACTIVE).
- **Refund (pull payment)**: si la ronda falla, cada inversor retira su USDC individualmente.

```
lknAmount = (usdcAmount * 1e18) / tokenPrice
```

---

### DividendDistributor.sol

Distribuye USDC entre holders de LKN usando el algoritmo *dividends per share*.

- **Patrón pull**: la plataforma deposita USDC una vez; cada holder retira cuando quiere.
- **Sin loops**: no itera sobre holders — escala a cualquier cantidad de inversores.
- **Corrección por transferencia**: cuando un holder transfiere tokens, sus derechos adquiridos se preservan.
- **DEPOSITOR_ROLE**: solo la plataforma puede depositar dividendos.

```
magnifiedDPShare += (depositado * 2^128) / totalSupply
pendiente(user)   = (balance(user) * magnifiedDPShare + corrección(user)) / 2^128
```

---

## Flujo del sistema

```
TGE
  Emisor despliega LinkenToken → recibe N LKN

SETUP DE RONDA
  Admin registra proyecto en ProjectRegistry (stage=FUNDING, precios)
  Admin despliega OfferingContract (precio, soft cap, hard cap, deadline)
  Admin otorga OFFERING_ROLE al OfferingContract en el Registry
  Emisor deposita LKN en OfferingContract (escrow)
  Emisor abre la ronda

RONDA ABIERTA (stage=FUNDING — precio early bird)
  Inversor aprueba USDC al OfferingContract
  Inversor llama buy(usdcAmount)
  → USDC va al treasury
  → LKN van al inversor

CIERRE EXITOSO (soft cap alcanzado)
  Por hard cap: cierre automático en buy()
  Por finalize(): emisor cierra manualmente
  → LKN no vendidos devueltos al emisor
  → ProjectRegistry actualiza stage=ACTIVE automáticamente

POST-APERTURA (stage=ACTIVE — precio estándar)
  Frontend muestra el nuevo precio
  La plataforma conecta DividendDistributor al token

DIVIDENDOS
  Plataforma deposita USDC en DividendDistributor
  Cada holder llama claimDividends() cuando quiere

RONDA FALLIDA (deadline sin soft cap)
  Cada inversor llama refund()
  → Treasury devuelve USDC individualmente
  → Proyecto permanece en FUNDING para nueva ronda
```

---

## Prerrequisitos

### Node.js (frontend)

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

### Foundry (contratos)

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc   # o ~/.zshrc
foundryup

forge --version
cast --version
```

### Slither (análisis estático, opcional)

```bash
pip install slither-analyzer --break-system-packages
slither --version
```

---

## Setup — Contratos

```bash
cd contracts

# Instalar dependencias
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std

# Compilar
forge build

# Tests
forge test -vv
```

---

## Tests y coverage

```bash
# Todos los tests
forge test -vv

# Test específico
forge test --match-contract LinkenTokenTest -vv

# Solo fuzz
forge test --match-test testFuzz -vv

# Coverage
forge coverage \
  --no-match-path "script/**" \
  --no-match-path "test/legacy/**" \
  --report summary

# Coverage con reporte HTML
forge coverage --report lcov
genhtml lcov.info --output-dir coverage-report
```

### Tests incluidos

| Suite | Tipos |
|---|---|
| `LinkenToken.t.sol` | Unit + Fuzz + Invariant |
| `ProjectRegistry.t.sol` | Unit + Fuzz |
| `OfferingContract.t.sol` | Unit + Fuzz |
| `DividendDistributor.t.sol` | Unit + Fuzz |
| `Integration.t.sol` | Integration + Fuzz |

---

## Análisis estático con Slither

```bash
cd contracts

slither src/ --config-file slither.config.json
```

`slither.config.json` recomendado:

```json
{
  "filter_paths": "lib/,src/legacy/",
  "solc_remaps": [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
  ]
}
```

---

## Setup — Frontend

Ver [FRONTEND.md](./frontend/FRONTEND.md) para instrucciones detalladas.

```bash
cd frontend
cp .env.example .env.local
npm install
npm run dev
# http://localhost:3000
```

### Desarrollo local con Anvil

```bash
# Terminal 1
anvil

# Terminal 2
cd contracts
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

# Terminal 3 — copiar addresses del output al .env.local
cd frontend && npm run dev
```

---

## Variables de entorno

### contracts/.env

```bash
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
ETHERSCAN_API_KEY=
DEPLOYER_ADDRESS=

# Después del deploy:
# LINKEN_ADDRESS=
# REGISTRY_ADDRESS=
# OFFERING_ADDRESS=
# DISTRIBUTOR_ADDRESS=
```

### frontend/.env.local

```bash
NEXT_PUBLIC_USE_ANVIL=true
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
NEXT_PUBLIC_FACTORY_ADDRESS=
NEXT_PUBLIC_USDC_ADDRESS=
```

> Los archivos `.env` y `.env.local` están en `.gitignore`.
> Verificar con `git status` antes de cada push.

---

## Deploy

> ⚠️ En blockchain no hay rollbacks. El contrato queda en la red para siempre.
> Completar el checklist antes del deploy oficial.

### Checklist pre-deploy

- [ ] `forge test -vv` — todos los tests en verde
- [ ] `forge coverage` — coverage ≥ 95%
- [ ] Slither corrido y hallazgos revisados
- [ ] `.env` completo
- [ ] Wallet con SepoliaETH para gas
- [ ] Revisión en grupo del código final

### Deploy en Sepolia

```bash
cd contracts
source .env

forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $SEPOLIA_RPC_URL \
  --account dev \
  --broadcast

forge verify-contract $LINKEN_ADDRESS src/LinkenToken.sol:LinkenToken \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia
```

---

## Seguridad

| Item | Implementación |
|---|---|
| Reentrancy | `ReentrancyGuard` en todas las funciones de escritura |
| Patrón CEI | Checks → Effects → Interactions en todos los contratos |
| Overflow | Solidity 0.8.24 — revert automático, sin `unchecked` injustificado |
| Access control | `AccessControl` con roles explícitos |
| Sin loops | No hay iteración sobre arrays de holders |
| Sin ETH | Los contratos solo manejan USDC y LKN |
| Supply fijo | No hay `mint()` post-TGE |
| Soft cap | Inversores recuperan USDC si la ronda falla |
| `.env` protegido | Gitignore + secret detection en CI |
| Tests | Unit + Fuzz + Invariant + Integration |

---

## Decisiones de arquitectura (ADRs)

Las decisiones de diseño están documentadas en [`docs/`](./docs/).

| ADR | Título | Estado |
|---|---|---|
| [0001](./docs/0001-monorepo.md) | Monorepo | Vigente |
| [0002](./docs/0002-openzeppelin-v5.md) | OpenZeppelin v5 | Vigente |
| [0003](./docs/0003-solidity-0.8.24.md) | Solidity 0.8.24 | Vigente |
| [0004](./docs/0004-stack-frontend.md) | Stack frontend | Vigente |
| [0005](./docs/0005-access-control-roles.md) | AccessControl en lugar de Ownable | Vigente |
| [0006](./docs/0006-creator-role-factory.md) | CREATOR_ROLE para desarrolladores | Vigente |
| [0007](./docs/0007-factory-pattern-project-tokens.md) | Factory pattern para ProjectTokens | [Deprecado — ver ADR-0011](./docs/0011-simplificacion-token-global-lkn.md) |
| [0008](./docs/0008-pull-payment-dividends.md) | Pull payment para dividendos | Vigente |
| [0009](./docs/0009-linken-deprecado.md) | Linken.sol (v1) deprecado | Vigente |
| [0010](./docs/0010-refactor-ProjectFactory-createProject.md) | Simplificación token global | [Deprecado — ver ADR-0011](./docs/0011-simplificacion-token-global-lkn.md) |
| [0011](./docs/0011-simplificacion-token-global-lkn.md) | Token global LKN con TGE fijo | Vigente |
| [0012](./docs/0012-offering-contract-tge-flow.md) | OfferingContract: flujo TGE | Vigente |
| [0013](./docs/0013-lknsale-deprecado.md) | LKNSale deprecado | Vigente |
| [0014](./docs/0014-offering-registry-integration.md) | Integración OfferingContract ↔ ProjectRegistry | Vigente |
| [0015](./docs/0015-sin-pausable.md) | Eliminación de Pausable en todos los contratos | Vigente |

---

## Roadmap

- Límite máximo de compra por wallet en `OfferingContract` (anti-monopolio)
- Diagrama de interacción Web2 ↔ Web3
- Integración frontend completa con los nuevos contratos
- Oráculo de producción para kWh → dividendos automáticos
- Mercado secundario P2P de tokens
- Soporte multi-parque con múltiples instancias de `OfferingContract`
- Auditoría externa
- Deploy productivo en mainnet

---

## Changelog

| Versión | Fecha | Cambio |
|---|---|---|
| 0.3.1 | 2025-05 | Pausable quitado de los contratos |
| 0.3.0 | 2025-05 | OfferingContract + integración con ProjectRegistry |
| 0.2.0 | 2025-05 | Token global LKN con TGE fijo, sin mint |
| 0.1.0 | 2025-05 | Setup inicial: Linken ERC-20 + tests + frontend |

---

## Licencia

MIT