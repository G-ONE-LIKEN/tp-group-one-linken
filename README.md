# Linken (LKN) — Plataforma de Tokenización de Proyectos Energéticos

Monorepo con smart contracts en Solidity (Foundry) + frontend web para interactuar con la plataforma desde el navegador.

El proyecto evolucionó desde un único token ERC-20 hacia una arquitectura modular compuesta por:

- `LinkenToken` (LKN)
- `ProjectRegistry`
- `DividendDistributor`
- `LKNSale`
- Frontend Next.js

---

# Índice

1. Arquitectura general
2. Estructura del monorepo
3. Smart Contracts
4. Flujo del sistema
5. Prerrequisitos
6. Setup — Contratos
7. Tests
8. Coverage
9. Slither
10. Setup — Frontend
11. Variables de entorno
12. Deploy
13. Seguridad
14. Roadmap

---

# Arquitectura general

Linken es una plataforma de tokenización de proyectos energéticos renovables.

La arquitectura actual separa responsabilidades entre múltiples contratos:

| Contrato | Responsabilidad |
|---|---|
| `LinkenToken.sol` | Token principal LKN |
| `ProjectRegistry.sol` | Registro y administración de proyectos |
| `DividendDistributor.sol` | Distribución de dividendos a holders |
| `LKNSale.sol` | Venta primaria de tokens |

La idea principal es representar proyectos energéticos mediante activos tokenizados y permitir:

- Registro de proyectos
- Emisión de tokens
- Venta de tokens
- Distribución de dividendos
- Integración con frontend Web3

---

# Estructura del monorepo

```text
linken/
├── contracts/
│   ├── src/
│   │   ├── DividendDistributor.sol
│   │   ├── LinkenToken.sol
│   │   ├── LKNSale.sol
│   │   ├── ProjectRegistry.sol
│   │   └── interfaces/
│   │
│   ├── test/
│   │   ├── DividendDistributor.t.sol
│   │   ├── LinkenToken.t.sol
│   │   ├── LKNSale.t.sol
│   │   └── ProjectRegistry.t.sol
│   │
│   ├── script/
│   ├── foundry.toml
│   ├── remappings.txt
│   └── lib/
│
├── frontend/
├── docs/
├── legacy-contracts/
└── README.md
```

---

# Smart Contracts

## LinkenToken.sol

Token ERC-20 principal del ecosistema.

Características:

- Basado en OpenZeppelin
- Mint controlado
- Supply configurable
- Integración con contratos de venta
- Compatible con frontend Web3

---

## ProjectRegistry.sol

Registro central de proyectos energéticos.

Responsabilidades:

- Crear proyectos
- Asociar metadata
- Registrar contratos relacionados
- Mantener estado de proyectos

Ejemplos de proyectos:

- Campo solar
- Parque eólico
- Planta biomasa

---

## DividendDistributor.sol

Permite distribuir dividendos a holders de tokens.

Características:

- Distribución proporcional
- Compatible con ERC-20
- Soporte para stablecoins
- Gestión de depósitos y reclamos

---

## LKNSale.sol

Contrato de venta primaria.

Responsabilidades:

- Venta de tokens
- Gestión de precios
- Control de supply
- Recepción de fondos

---

# Flujo del sistema

```text
Usuario
   ↓
Frontend Next.js
   ↓
Smart Contracts
   ├── LinkenToken
   ├── ProjectRegistry
   ├── LKNSale
   └── DividendDistributor
```

Flujo típico:

1. Se registra un proyecto
2. Se habilita una venta de tokens
3. Usuarios compran tokens
4. El proyecto genera rendimiento
5. DividendDistributor distribuye ganancias

---

# Prerrequisitos

## Node.js

```bash
# Arch Linux
sudo pacman -S nodejs npm

# Ubuntu / Debian
sudo apt install nodejs npm

# macOS
brew install node
```

Verificar:

```bash
node --version
npm --version
```

---

## Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

forge --version
cast --version
```

---

## Slither (opcional)

```bash
pip install slither-analyzer --break-system-packages
slither --version
```

---

# Setup — Contratos

```bash
cd contracts

# Instalar dependencias
forge install

# Compilar
forge build

# Ejecutar tests
forge test -vv
```

---

# Tests

Tests disponibles:

| Archivo |
|---|
| `DividendDistributor.t.sol` |
| `LinkenToken.t.sol` |
| `LKNSale.t.sol` |
| `ProjectRegistry.t.sol` |

Ejecutar todos:

```bash
forge test -vv
```

Ejecutar test específico:

```bash
forge test --match-contract LinkenTokenTest -vv
```

---

# Coverage

```bash
forge coverage
```

Reporte HTML:

```bash
forge coverage --report lcov
genhtml lcov.info --output-dir coverage-report
```

---

# Slither

Análisis estático:

```bash
slither src/
```

Ejemplo:

```bash
slither src/LinkenToken.sol
```

---

# Setup — Frontend

```bash
cd frontend

npm install
npm run dev
```

Abrir:

```text
http://localhost:3000
```

---

# Variables de entorno

## contracts/.env

```bash
SEPOLIA_RPC_URL=
ETHERSCAN_API_KEY=
PRIVATE_KEY=
```

---

## frontend/.env.local

```bash
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=
NEXT_PUBLIC_LKN_ADDRESS=
NEXT_PUBLIC_REGISTRY_ADDRESS=
```

---

# Deploy

## Local (Anvil)

```bash
anvil
```

En otra terminal:

```bash
cd contracts
forge script script/DeployAll.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
```

---

## Sepolia

```bash
forge script script/DeployAll.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

---

# Seguridad

Checklist general:

- Reentrancy protection
- Uso de OpenZeppelin
- Solidity 0.8.x
- Tests unitarios
- Fuzz tests
- Coverage
- Slither
- Control de permisos
- Validación de inputs

---

# Desarrollo recomendado

Antes de cada push:

```bash
forge fmt
forge build
forge test
```

Opcional:

```bash
alias prepush='forge fmt && forge build && forge test'
```

---

# Roadmap

- Integración completa frontend ↔ contratos
- Dashboard de dividendos
- Gestión avanzada de proyectos
- Deploy productivo
- Auditoría externa
- Soporte multi-chain

---

# Licencia

MIT

