# Guía de Deploy — Linken en Sepolia

Paso a paso para compilar, testear y deployar los contratos en Sepolia testnet.

---

## Índice

1. [Instalar Foundry](#1-instalar-foundry)
2. [Configurar RPC de Sepolia](#2-configurar-rpc-de-sepolia)
3. [Configurar la wallet](#3-configurar-la-wallet)
4. [Instalar dependencias y compilar](#4-instalar-dependencias-y-compilar)
5. [Correr los tests](#5-correr-los-tests)
6. [Crear el .env](#6-crear-el-env)
7. [Deploy en Sepolia](#7-deploy-en-sepolia)
8. [Verificar los contratos en Etherscan](#8-verificar-los-contratos-en-etherscan)
9. [Checklist final](#9-checklist-final)

---

## 1. Instalar Foundry

Foundry es el toolchain para compilar, testear y deployar los contratos.

```bash
# Instalar
curl -L https://foundry.paradigm.xyz | bash

# Cerrar y reabrir la terminal, luego:
foundryup

# Verificar instalación
forge --version
cast --version
anvil --version
```

Esperás ver algo como:
```
forge 0.2.0 (abc1234 2025-xx-xx)
```

> **Windows**: si usás PowerShell o CMD, usá Git Bash o WSL para correr estos comandos.

---

## 2. Configurar RPC de Sepolia

Necesitás una URL de RPC para conectarte a la red Sepolia. Es gratis.

### Opción A — RPC público (sin registro, gratis)

No necesitás crear ninguna cuenta. Usá directamente:

```
https://ethereum-sepolia-rpc.publicnode.com
```

### Opción B — Alchemy o Infura (solo si el público falla)

Si el RPC público se cae o es lento, podés crear una cuenta gratis en [alchemy.com](https://alchemy.com) o [infura.io](https://infura.io) y obtener una URL propia.

---

## 3. Configurar la wallet

Necesitás exportar la **private key** de tu wallet para que Foundry pueda firmar transacciones.

### Opción A — Cuenta nombrada (recomendado, más seguro)

```bash
# Importar tu wallet como cuenta nombrada "dev"
cast wallet import dev --interactive
# Te va a pedir la private key y una contraseña para encriptarla
```

Para verificar:
```bash
cast wallet list
# Deberías ver: dev
```

### Opción B — Variable de entorno (más simple)

Guardás la private key en el `.env` (ver Paso 6). Menos seguro pero más directo para testing.

> **Importante**: nunca subas la private key a git. El `.env` ya está en `.gitignore`.

---

## 4. Instalar dependencias y compilar

```bash
cd tp-group-one-linken/contracts

# Instalar dependencias (OpenZeppelin + forge-std)
forge install

# Si da error, instalar manualmente:
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit

# Compilar
forge build
```

Resultado esperado:
```
Compiling 15 files with Solc 0.8.24
Solc 0.8.24 finished in X.XXs
Compiler run successful!
```

> Si `forge build` pasa sin errores, los contratos están listos para deployar.

---

## 5. Correr los tests

```bash
cd tp-group-one-linken/contracts

# Todos los tests con detalle
forge test -vv

# Ver también coverage
forge coverage \
  --no-match-path "script/**" \
  --no-match-path "test/legacy/**" \
  --report summary
```

Resultado esperado de los tests:
```
Running X tests for test/LinkenToken.t.sol:LinkenTokenTest
[PASS] testXxx() (gas: XXXXX)
...
Test result: ok. X passed; 0 failed; finished in Xs
```

El coverage debe ser **≥ 95%** antes del deploy oficial.

> Si algún test falla, **no deployar** hasta resolverlo.

---

## 6. Crear el .env

```bash
cd tp-group-one-linken/contracts

# Crear el archivo de entorno
cp .env.example .env
```

Editá `.env` y completá los valores:

```env
# RPC de Sepolia (del Paso 2)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_API_KEY

# API key de Etherscan para verificar contratos (conseguila en etherscan.io)
ETHERSCAN_API_KEY=TU_ETHERSCAN_API_KEY

# Tu wallet (la que tiene SepoliaETH)
DEPLOYER_ADDRESS=0xTU_WALLET_ADDRESS

# Parámetros del deploy
PLATFORM_ADMIN=0xTU_WALLET_ADDRESS
EMISOR=0xTU_WALLET_ADDRESS
TREASURY=0xTU_WALLET_ADDRESS

# USDC en Sepolia (dirección oficial de Circle en Sepolia)
USDC=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

# Opcional: private key si no usás cuenta nombrada (ver Paso 3)
# PRIVATE_KEY=0xTU_PRIVATE_KEY
```

> La dirección de USDC en Sepolia es `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` (Circle oficial).

### Conseguir API key de Etherscan

1. Entrá a [etherscan.io](https://etherscan.io) → registrate
2. My Account → **API Keys** → **Add**
3. Copiá la key al `.env`

---

## 7. Deploy en Sepolia

```bash
cd tp-group-one-linken/contracts
source .env

# Con cuenta nombrada (Opción A del Paso 3)
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $SEPOLIA_RPC_URL \
  --account dev \
  --broadcast \
  --verify

# Con private key directa (Opción B del Paso 3)
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Qué esperar durante el deploy

```
== Logs ==
  LinkenToken deployed at:      0xAAAA...
  ProjectRegistry deployed at:  0xBBBB...
  OfferingContract deployed at: 0xCCCC...
  DividendDistributor deployed at: 0xDDDD...

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
Total Paid: X ETH (X gas * X gwei)
```

### Guardar las addresses

Copiá las addresses del output y guardálas en el `.env`:

```env
LINKEN_ADDRESS=0xAAAA...
REGISTRY_ADDRESS=0xBBBB...
OFFERING_ADDRESS=0xCCCC...
DISTRIBUTOR_ADDRESS=0xDDDD...
```

---

## 8. Verificar los contratos en Etherscan

Si el `--verify` del paso anterior funcionó, los contratos ya están verificados automáticamente.

Para verificar manualmente (si algo falló):

```bash
source .env

forge verify-contract $LINKEN_ADDRESS src/LinkenToken.sol:LinkenToken \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia

forge verify-contract $REGISTRY_ADDRESS src/ProjectRegistry.sol:ProjectRegistry \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia

forge verify-contract $OFFERING_ADDRESS src/OfferingContract.sol:OfferingContract \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia

forge verify-contract $DISTRIBUTOR_ADDRESS src/DividendDistributor.sol:DividendDistributor \
  --rpc-url $SEPOLIA_RPC_URL \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia
```

Después del deploy, podés ver los contratos en:
```
https://sepolia.etherscan.io/address/0xAAAA...
```

---

## 9. Checklist final

### Antes del deploy
- [ ] `forge --version` responde correctamente
- [ ] `forge build` compila sin errores
- [ ] `forge test -vv` — 0 tests fallidos
- [ ] `forge coverage` — ≥ 95%
- [ ] `.env` completo con RPC URL, Etherscan key y wallet
- [ ] Wallet tiene SepoliaETH (mínimo 0.05 ETH para gas)

### Después del deploy
- [ ] Las 4 addresses están guardadas en el `.env`
- [ ] Los contratos aparecen verificados en [sepolia.etherscan.io](https://sepolia.etherscan.io)
- [ ] Actualizar `liken-plataform-frontend/.env.local` con las addresses
- [ ] Actualizar `liken-plataform-backend/.env` con las addresses y el RPC

### Actualizar el frontend (liken-plataform-frontend)

```env
# liken-plataform-frontend/.env.local
NEXT_PUBLIC_LKN_ADDRESS=0xAAAA...
NEXT_PUBLIC_REGISTRY_ADDRESS=0xBBBB...
NEXT_PUBLIC_DISTRIBUTOR_ADDRESS=0xDDDD...
NEXT_PUBLIC_USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

### Actualizar el backend (liken-plataform-backend)

```env
# liken-plataform-backend/.env
WEB3_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/TU_API_KEY
WEB3_CHAIN_ID=11155111
LKN_ADDRESS=0xAAAA...
REGISTRY_ADDRESS=0xBBBB...
DISTRIBUTOR_ADDRESS=0xDDDD...
USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

---

## Problemas comunes

### `forge: command not found`
Foundry no está en el PATH. Corré `source ~/.bashrc` (o `~/.zshrc`) y volvé a intentar.

### `forge install` falla
```bash
# Intentar con --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit
```

### `Insufficient funds`
Tu wallet no tiene suficiente SepoliaETH. Conseguí del faucet:
- [faucet.google.com/web3/faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia) (Google, requiere cuenta)
- [faucets.chain.link](https://faucets.chain.link/sepolia) (Chainlink)
- [sepoliafaucet.com](https://sepoliafaucet.com) (Alchemy)

### `Error: transaction failed`
Revisá que el `PLATFORM_ADMIN`, `EMISOR` y `TREASURY` en el `.env` sean la misma wallet que el deployer, o que las wallets correspondan a las correctas.

### Tests fallan con `forge test`
Corré con más verbosidad para ver el error exacto:
```bash
forge test -vvvv --match-test NOMBRE_DEL_TEST
```
