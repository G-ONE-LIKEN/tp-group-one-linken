# Proyecto de Energia Renovable

Financiación fraccionada de parques solares y eólicos.

El unico proyecto de la materia SIP con rendimiento objetivamente medible en tiempo real. El medidor IoT del parque reporta kWh on-chain.

## 1. El token lo llaman $RNW

* 1 token $RNW = 1 participacion proporcional en un parque de generacion de energia renovable y en los ingresos por venta de energia de red electrica.
* $RNW usa ERC-20 con supply fijo por parque.
* Oráculo IoT de kWh — el medidor reporta on-chain, dividendo automático

En resumen, un token es un pedazo proporcional de un parque solar y la energía que vende a la red.

### Caracteristica distintiva

* Energía Renovable
* ERC-20 de participación fraccionada en infraestructura de generación (parque solar / eólico).
* Oráculo IoT que reporta kWh generados on-chain y dispara la distribución de forma automatizada.
* Verificabilidad objetiva del rendimiento mediante medición física continua y posible extensión a certificados de carbono.

En resumen:
* Estándar técnico: ERC-20
* Símbolo: $RNW
* Naturaleza legal: Security token (CP del fideicomiso dueño del parque)
* Supply: Fijo, definido en el constructor según tamaño del parque.
* Un token por: parque (cada parque tiene su propio $RNW)
* Particularidad: Oráculo IoT mide kWh → contrato calcula dividendo automático

### Consideración crítica

El token no genera valor por sí solo. El valor proviene siempre del activo subyacente. La blockchain es el mecanismo de registro, transferencia y distribución, no la fuente del valor.

En el caso de este proyecto, si un parque solar genera menos kWh que lo proyectado (climatología adversa, falla técnica, baja de la tarifa PPA), entonces el oráculo reporta menos generación. La distribución mensual a holders de $RNW cae proporcionalmente.

### T.G.E. (Token Gen. Event)

Deployás un contrato. En el constructor decís “supply = 100.000”. El contrato crea 100.000 tokens una sola vez y se los manda al emisor. Nunca más se pueden crear nuevos.

El proyecto escribio (no subio/cargo) un contrato con mint(...) eso esta mal. Hay que corregir.

El TGE es de 200.000 $RNW por parque de 5MW, lo emite el SPE dueño del parque, 1 vez por parque.

## 2. ¿Cómo se vende? (la ronda)

El emisor mete los tokens en un contrato de venta (OfferingContract). Los inversores pagan con USDC (o pesos) y reciben tokens a un precio fijo.

### 3 parámetros a definir:

* Precio ($USD por token) — fijo en la ronda
* Soft cap — mínimo a recaudar para que el proyecto arranque. Si no llega, los inversores recuperan su plata.
* Hard cap — máximo a recaudar. Una vez alcanzado, la ronda cierra.

En el contexto del proyecto, el precio del token es USD 10 / $RNW. El capital total de ejemplo: USD 2.000.000 (parque 5MW). Recauda por medio de Inversores que compran 0.0005% del parque cada 1 $RNW.

### Consideración crítica

El precio NO sube mágicamente. En la ronda primaria, el precio es fijo. Después, en el mercado secundario, sube o baja según oferta y demanda basada en lo que la gente cree que el activo va a producir. Si el complejo factura el doble de lo esperado, $DPF sube. Si factura la mitad, baja. No hay “subir por hype” sostenible.

## 3. ¿Cómo se paga? (dividendos)

Acá viene lo crucial: cómo el token se conecta con plata real que entra al sistema.

El activo real (complejo, parque, cervecería) genera ingresos en el mundo físico. Esos ingresos:

1. Llegan al fideicomiso o SPE que es dueño legal del activo
2. El fiduciario convierte a USDC (estable, no a cripto volátil)
3. Deposita los USDC en el contrato DividendDistributor
4. El contrato registra cuánto le toca a cada holder según su tenencia
5. Cada holder llama a claim() y cobra su parte

El paso 4 es ingenioso: no se itera sobre todos los holders (eso costaría una fortuna en gas si hay 10.000 inversores). Se usa un acumulador global dividendPerToken y cada uno calcula su parte cuando reclama.

El proyecto dispone de un DividendDistributor que hay que revisar y refactorizar de ser necesario.

En el proyecto, la plata sale de la venta de kWh a la red eléctrica (oráculo IoT mide y reporta), con una frecuencia mensual, por ejemplo: 500 $RNW (0.25%) → USD 200/mes.

### Consideración crítica

El medidor inteligente del parque reporta kWh al oráculo, el contrato calcula el dividendo automático. No hay confianza en que el emisor “deposite los dividendos correctos” — el oráculo lo hace.

## 4. ¿Cómo ESCALA esto a una economía? (la pregunta del millón)

Un token aislado es plata muerta. Lo que lo convierte en economía es que tenga:

### Demanda genuina (alguien lo quiere por algo más que especular)

El compromiso ambiental verificable + staking que financia parques nuevos, es el "Por qué" la gente querría el token (más allá del precio)

### Sinks (cosas que QUEMAN o BLOQUEAN tokens)

Sin sinks, el supply circulante crece infinito → precio cae. Sinks típicos:

* Marketplace fees: 2% por transacción (se sugiere quemar 1%).
* Staking: bloquear $RNW genera +2% APY y financia colateral para nuevos parques iniciales. Mientras este stakeado, el token está fuera de circulación.
* Governance lock: votar requiere bloquear tokens.

### Faucets controlados (cómo entran nuevos tokens)

En el modelo base, no entran tokens nuevos después del TGE. El supply es fijo para siempre. Cero inflación.

Una vez mas recalco que hay que correjir los contratos para que refleje esto.

* TGE por parque: 200.000 $RNW (5MW), una sola vez por parque.
* Nuevos parques: cada parque nuevo es su propio contrato con su propio $RNW.

### Consideración crítica

“Cuanto más se use, más vale” solo funciona si los sinks queman más rápido de lo que crece el supply circulante.

Si el equipo emite tokens nuevos al mismo ritmo que la gente los quema en fees, el precio no sube. Si emite más rápido, baja. La economía del token vive o muere en el balance entre faucets y sinks, y ese balance tiene que estar escrito en el código del contrato, no en una promesa.

## 5. Las 5 preguntas que tu grupo TIENE que responder antes de codear

Antes de escribir una sola línea de Solidity:

1. ¿Qué representa exactamente tu token? (1 oración. Si no podés en 1 oración, no lo entendés todavía.)
2. ¿De dónde sale la plata real que se reparte? (Si no podés señalar un flujo de ingresos del mundo físico, no hay dividendos.)
3. ¿Por qué alguien lo querría además de para revenderlo? (Si la única respuesta es “porque sube”, no hay economía.)
4. ¿Qué quema o bloquea tokens? (Sin sinks, inflación → muerte.)
5. Si mañana hay 100x más usuarios, ¿el modelo aguanta? (¿El gas explota? ¿Los oráculos colapsan? ¿El fideicomiso da abasto?)

1. Un token representa una participacion proporcional en un parque de generacion de energia y en los ingresos por venta de energia en la red electrica.
2. Sale de la venta de energia electrica a las compañias de energia.
3. Un token le permite al inversor hacer un voto ponderado en la toma de decisiones sobre el parque, como realizar inversiones para poner mas paneles solares (por ejemplo). Entonces, cuanto mas tokens tenga, mayor es la probabilidad que su decision se lleve a cabo.
4. Un posible sink es el antes mencionado holding de tokens que realizan los inversores cuanto mas tokens tenga, mayor es la capacidad de decision sobre el parque y se reduce el total de tokens en circulacion. Ademas, se definio en el contrato del proyecto la posibilidad que un holder de tokens (el inversor) pueda quemar libremente sus propios tokens. Por ultimo, tenemos los fees (a definir el %) por transaccion.
5. No se dispone de una respuesta (TODO)

## 6. MVP escalable — qué hay que construir, mínimo

Esta es la lista inevitable. Si falta algo de acá, no es un MVP, es un demo.

### Contratos on-chain (mínimo viable)

* AssetToken (ERC-20) para el token del activo. Supply fijo en el constructor.
* OfferingContract para la venta primaria: USDC → tokens, con soft/hard cap.
* DividendDistributor par repartir USDC entre holders, sistema claim(). [Ya implementado, refactorizar para que se acomode a este modelo]
* Marketplace secundario: Listar / comprar tokens entre holders. Cobrar fee.

### Estructura legal off-chain (sin esto, el token no vale nada legalmente)

Si bien esto esta fuera del marco de contratos, se menciona para futuro desarrollo.

* Fideicomiso financiero o SPE: Tiene legalmente el activo. Es lo que conecta el on-chain con la justicia argentina.
* Certificados de Participación (CP): El token on-chain es la representación digital de un CP. Sin CP no hay respaldo jurídico.
* Auditoría periódica: Verifica que la facturación reportada al oráculo o al fiduciario sea real.

Aunque claro, para el oraculo, hay que buscar formas de crear (o simular) oraculos y enchufarlos al contrato.
El Oráculo de datos (Chainlink IoT o feed de precios) es escencial para el funcionamiento del sistema.

## 7. ¿Cómo evita esto ser una estafa?

3 mecanismos obligatorios:

* Código auditado y verificado en explorador (Etherscan para L1, Basescan para L2). Cualquiera puede leer el contrato.
* Supply fijo y dividendos automáticos. No hay un humano que “decida pagar”. El contrato paga lo que entra.
* Estructura legal off-chain auditable. El fideicomiso tiene contabilidad, papeles, balance. Si el equipo miente sobre la facturación, hay responsabilidad legal.

## Ejemplos concretos

### Números concretos del modelo base

Parque solar de 5 MW en San Juan, valuación USD 2.000.000.

|    Parametro      |             Valor              |     Cómo se calcula / por qué    |
|-------------------|--------------------------------|----------------------------------|
| Supply total      |         200.000 $RNW           | Definido por el SPE en el deploy |
| Precio de emisión |         USD 10 / token         |     USD 2M ÷ 200.000 tokens      |
|    % por token    |       0.0005% del parque       |           1 / 200.000            |
|    Soft cap       | A definir (ej: USD 1.4M = 70%) |   Para arrancar la construcción  |
|    Hard cap       |         USD 2.000.000          |     Capital total del parque     |

Ejemplo de inversor:
Si Comprás 500 $RNW pagando USD 5.000 (vía USDC). Tenés un 0.25% del parque solar. El medidor reporta que el parque generó 600.000 kWh este mes a una tarifa promedio de USD 0.066/kWh (PPA con CAMMESA). Eso son USD 39.600 de ingresos mensuales. Tu parte: USD 99. Después de fees del fideicomiso, recibís ~USD 80 en USDC.

La clave: el cálculo lo hace el contrato solo. El oráculo IoT reporta los kWh, el contrato multiplica por la tarifa, y dispara la distribución. No hay un humano que “deposite” los dividendos.

## El flujo de la plata (con oráculo IoT)

```bash
┌──────────────────────┐
│ PARQUE SOLAR 5MW     │   Genera energía:
│ (paneles + medidor)  │   Medidor inteligente cuenta kWh.
└──────────┬───────────┘
           │ datos IoT (cada hora)
           ▼
┌──────────────────────┐
│ CHAINLINK ORACLE     │   Lee del medidor.
│ (red descentralizada)│   Reporta kWh on-chain.
└──────────┬───────────┘
           │ updateGeneration(kwh)
           ▼
┌──────────────────────┐
│ AssetTokenRNW        │   Contrato calcula:
│ (smart contract)     │   revenue = kWh × tarifa_PPA
└──────────┬───────────┘   Dispara distribución automática.
           │
           ▼
┌──────────────────────┐
│ DividendDistributor  │   Acumula USDC.
│ (smart contract)     │   Holders reclaman con claim().
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ HOLDER DE $RNW       │   Recibe USDC proporcional.
└──────────────────────┘

┌──────────────────────┐
│ FIDEICOMISO / SPE    │   En paralelo: vende la energía
│ (dueño legal)        │   a CAMMESA/red, recibe pesos,
└──────────────────────┘   convierte a USDC, deposita
                            en el DividendDistributor.
```

### caracteristicas

En este modelo, el oráculo reporta kWh (verificable contra el medidor físico). Eso significa:

* Confianza reducida en el emisor — el rendimiento es medible y auditable por cualquier tercero.
* Automatización total — sin intervención humana en el cálculo del dividendo.

A tener en cuenta que persiste un punto de confianza: el medidor IoT físico. Si se manipula, el dato es incorrecto. Por eso se requiere:
  - Medidor certificado (norma IRAM)
  - Múltiples oráculos cruzando datos (la app de CAMMESA + Chainlink + auditor independiente)

## Parámetros del modelo Energía Renovable

* Supply por parque: Variable según tamaño. Parque 5MW: 200.000 $RNW a USD 10 c/u
* Base del dividendo: kWh generados × precio de venta (tarifa regulada o PPA)
* Cálculo: Automatizable via oráculo IoT — único de los 4 proyectos
* Dos perfiles de riesgo: Inicial (en construcción, más barato, más riesgo) vs. Consolidado (operando, track record probado)
* Staking: Bloquear $RNW genera +2% APY extra y da colateral para nuevos parques
* Fee emisión: 3% sobre capital recaudado
* Fee marketplace: 2% por compra/venta
* Impacto on-chain: kWh generados quedan registrados en blockchain. Verificable por cualquier auditor.

## El concepto de “dos perfiles de riesgo”

El modelo le ofrece al inversor dos productos distintos en función de su tolerancia al riesgo:
| Perfil | Estado del parque |Precio del token |Yield esperado |Riesgo|
-----------------------------------------------------------------------
| Inicial | En construcción (12-18 meses para operar) | Más barato (descuento por riesgo) | Más alto cuando entra en operación | Demora, sobrecostos, no llegar a generar
| Consolidado | Operando con track record (12+ meses) | Más caro (riesgo descontado) | Más predecible | Climático, regulatorio |


## La extensión: $GREEN (moneda de plataforma + créditos de carbono)

El proyecto tiene la oportunidad más diferenciadora de los 4 (de la materia). Estoy ultimo, es para una etapa mas "cocinada", ya que primero hay que finalizar los contratos del $RNW.

> $GREEN puede ser simultáneamente moneda de plataforma + certificado de crédito de carbono on-chain.

Cada $GREEN representa un certificado verificable. Esto significa:

* Empresas que necesitan offset de carbono comprarían $GREEN para reportar su huella → demanda externa al ecosistema de inversión.
* Integración con estándares internacionales (Gold Standard, VCS) → caso de uso fuera de Argentina.
* Es la primera plataforma local que combina inversión renovable + créditos de carbono tokenizados verificables.

|Capa | Qué es | Para qué sirve |
|-----|--------|----------------|
| $RNW (por parque) | Token del activo. Supply fijo. | Participación en ese parque + dividendos.
| $GREEN (plataforma) | Moneda transversal + certificado de carbono. |Medio de pago de fees, governance, offset corporativo.

### Por qué $GREEN es especialmente potente acá

A diferencia de los otros 3 proyectos donde la moneda de plataforma solo tiene utilidad dentro del ecosistema, $GREEN tiene utilidad externa:

* Empresas con compromisos ESG necesitan offset de carbono → compran $GREEN, lo queman, reportan reducción.
* Eso crea demanda continua del token sin depender de que crezca la plataforma.
* El staking de $GREEN puede financiar el fondo de garantía para parques en construcción (perfil inicial).
* La governance vota qué parques entran a la plataforma → los inversores controlan la calidad del flujo.

### Consideración crítica

Para que $GREEN sea un certificado de carbono verificable, no nominal, se requiere:

* Validación de un estándar internacional (Gold Standard, VCS, Verra). No podés inventarte un certificado.
* Verificación independiente del CO2 evitado (relacionado con los kWh que ya mide tu oráculo).
* Mecanismo de “retire”: cuando una empresa usa el certificado, se quema y queda registro on-chain de quién compensó cuánto.

Sin esos 3 elementos, $GREEN es un token verde de marketing. Con ellos, es un activo financiero real con demanda global.

## MVP escalable — qué tiene que construir el grupo

### Contratos mínimos (fase 1: un parque)

| # | Contrato | Funciones clave | Tests críticos |
|---|----------|-----------------|----------------|
| 1 | RnwToken (ERC-20) | Supply fijo en constructor. Sin función mint(). |Supply post-deploy no crece. |
| 2 | OfferingContract | invest(usdcAmount), perfiles inicial / consolidado, soft cap, hard cap. | Distinción entre perfiles, refund si no llega soft cap. |
| 3 |OracleAdapter | Recibe updateGeneration(kwh) del Chainlink IoT. Solo el oráculo puede llamar. | Rechaza llamadas de wallets no autorizadas. |
| 4 | DividendDistributor | distributeFromKwh(kwh, tariffUsdc) automático cuando entra el oráculo. | Cálculo correcto con kWh variables. |
| 5 | StakingVault | stake(amount), unstake(), +2% APY, colateral para nuevos parques. | Cálculo correcto de APY, cooldown de unstake. |
| 6 | Marketplace | Lista, compra, vende $RNW. Fee 2%. | Spread entre perfiles inicial/consolidado. |

#### Infraestructura off-chain crítica
* Medidor inteligente certificado: IRAM o similar. Sin esto, el oráculo no es confiable.
* Nodo Chainlink IoT: Lee del medidor cada hora, reporta a la red.
* SPE / Fideicomiso: Dueño legal del parque. Firma el PPA con CAMMESA.
* PPA (Power Purchase Agreement): Contrato de venta de energía a la red. Define la tarifa $/kWh.
* Auditoría energética anual: Verifica que el medidor no fue manipulado.

### Fase 2 (cuando haya 3+ parques)

* GreenToken (ERC-20 con cap máximo) — moneda de plataforma + certificado de carbono
* Integración con Gold Standard / VCS para certificación
* Pool de liquidez $GREEN ↔ USDC en DEX
* Mecanismo de “retire” para que empresas quemen $GREEN al usarlo

## Riesgos específicos de Energía Renovable
|Riesgo | Por qué importa | Mitigación |
| Generación variable | Días nublados / sin viento → menos kWh → menos dividendo. | Comunicar variabilidad esperada (ej: factor de capacidad 25-30% típico). |
| Cambio en tarifa PPA | Si el regulador cambia la tarifa, el ingreso cambia. | PPA a largo plazo (10-20 años) con tarifa fija o indexada a USD. |
| Manipulación del medidor IoT | Alguien con acceso físico podría falsear kWh. | Medidor certificado + múltiples fuentes (medidor + app CAMMESA + auditor). |
| Fallo del oráculo Chainlink | Si el nodo Chainlink se cae, no se distribuyen dividendos. | Múltiples nodos + fallback manual con timeout (ej: si oráculo no reporta en 48h, fiduciario reporta manualmente con auditoría). |
| Riesgo regulatorio energético | Cambios en el régimen de generación distribuida. | Asesoramiento legal sectorial (no solo crypto). |
| Validación de $GREEN como carbono | Si no se valida con estándar internacional, no tiene demanda externa. | Iniciar proceso de certificación con Gold Standard antes del TGE de $GREEN. |

## Checklist pre-codear

Antes de escribir el primer contrato Solidity:

- [ ] ¿Cuál es el parque concreto del MVP? (ubicación, MW, tecnología solar/eólica)
- [ ] ¿Quién va a ser el SPE / fiduciario? (entidad legal dueña del parque)
- [ ] ¿Hay PPA firmado o pendiente? (sin PPA, no hay venta de energía garantizada)
- [ ] ¿Cuál es la tarifa $/kWh esperada? (CAMMESA tarifa horaria estacional)
- [ ] ¿Qué factor de capacidad asume el modelo? (solar AR: 22-28%, eólico patagónico: 35-45%)
- [ ] ¿Qué medidor IoT van a usar? (marca, modelo, certificación)
- [ ] ¿Qué nodo Chainlink van a contratar? (o desarrollan uno propio)
- [ ] ¿Van a perseguir certificación Gold Standard para $GREEN? (sí / no impacta toda la fase 2)
- [ ] ¿En qué red deployamos? (Stack del curso: Base Sepolia para el PoC; Base mainnet recomendado para producción por el costo bajo de las transacciones recurrentes del oráculo)

Regla: si no podés responder estas 9 preguntas, no escribas todavía un solo contrato. El twist de tu proyecto es el oráculo IoT — diseñalo bien antes de programar.

## Implementación MÍNIMA (PoC / demo del cuatrimestre)

Objetivo: demostrar el flujo end-to-end con un oráculo IoT mockeado que dispare distribución automática. El twist único del proyecto va en el PoC.

### Stack técnico recomendado
| Capa | Tecnología | Por qué
| Smart contracts | Solidity 0.8.x + OpenZeppelin 5.x | OZ trae ERC-20 + Ownable + AccessControl auditados |
| Framework de desarrollo | Hardhat + Chainlink Hardhat Plugin | Hardhat se integra con Chainlink local node |
| Red de prueba | Base Sepolia | Chainlink Functions y Data Feeds disponibles en Base Sepolia; EVM idéntica a Ethereum |
| Oráculo (mock) | Cuenta ORACLE_ROLE que firma updateGeneration(kwh) | En PoC el “oráculo” es una wallet con role que simula reportar |
| Oráculo (real opcional) | Chainlink Functions con un endpoint HTTP que devuelve kWh mock 	Si querés ir más lejos, hay un tutorial oficial de Functions |
| USDC mock | Contrato propio | El USDC real de Circle vive en Base mainnet; en Base Sepolia se mockea
| Frontend  | Next.js 14 + wagmi + viem + RainbowKit + chart de kWh | Mostrar la generación en tiempo real
| Indexer  | Eventos directos del contrato | Para PoC alcanza

### Los 5 contratos en pseudocódigo (con oráculo)

A continuacion, el profesor sugirio este pseudo codigo, hay que checkear/revisar y aplicar los cambios necesarios los contratos ya hechos para que reflejen un comportamiento similar.

```bash
// 1. RnwToken — ERC-20 supply fijo (igual a DepFund)
contract RnwToken is ERC20 {
    constructor(uint256 supply, address issuer)
        ERC20("RNW Parque Solar San Juan", "RNW") {
        _mint(issuer, supply);
    }
}

// 2. OracleAdapter — recibe reportes del medidor IoT
contract OracleAdapter is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 public lastReportedKwh;
    uint256 public lastReportTimestamp;
    uint256 public constant TARIFF_USDC_PER_KWH = 66_000;  // 6.6 centavos × 1e6 USDC

    event GenerationUpdated(uint256 kwh, uint256 revenueUsdc, uint256 timestamp);

    // SOLO el oráculo puede llamar
    function updateGeneration(uint256 kwhThisMonth) external onlyRole(ORACLE_ROLE) {
        lastReportedKwh = kwhThisMonth;
        lastReportTimestamp = block.timestamp;
        uint256 revenueUsdc = kwhThisMonth * TARIFF_USDC_PER_KWH / 1000;  // kWh * tarifa
        emit GenerationUpdated(kwhThisMonth, revenueUsdc, block.timestamp);
        dividends.distributeFromOracle(revenueUsdc);
    }
}

// 3. DividendDistributor — recibe del oráculo, no del fiduciario
contract Dividends {
    uint256 public dividendPerToken;
    mapping(address => uint256) public claimedPerToken;

    function distributeFromOracle(uint256 usdcAmount) external onlyOracle {
        // El SPE pre-deposita USDC en este contrato (de la venta de energía a CAMMESA)
        // El oráculo solo dispara la actualización del acumulador
        require(usdc.balanceOf(address(this)) >= usdcAmount, "underfunded");
        dividendPerToken += (usdcAmount * 1e18) / rnw.totalSupply();
    }

    function claim() external {
        uint256 amt = pending(msg.sender);
        claimedPerToken[msg.sender] = dividendPerToken;
        usdc.transfer(msg.sender, amt);
    }
}

// 4. OfferingContract — DOS perfiles de riesgo
contract Offering {
    enum Profile { INITIAL, CONSOLIDATED }
    mapping(Profile => uint256) public priceUsdc;  // Initial más barato

    function invest(uint256 usdcAmount, Profile p) external {
        uint256 price = priceUsdc[p];
        uint256 tokens = (usdcAmount * 1e18) / price;
        usdc.transferFrom(msg.sender, treasury, usdcAmount);
        rnw.transfer(msg.sender, tokens);
    }
}

// 5. StakingVault — bloquea $RNW, +2% APY, colateral para parques nuevos
contract StakingVault {
    mapping(address => uint256) public staked;
    mapping(address => uint256) public stakedAt;
    uint256 public constant APY_BPS = 200;  // 2%

    function stake(uint256 amount) external {
        rnw.transferFrom(msg.sender, address(this), amount);
        staked[msg.sender] += amount;
        stakedAt[msg.sender] = block.timestamp;
    }

    function unstake() external {
        uint256 amount = staked[msg.sender];
        uint256 elapsed = block.timestamp - stakedAt[msg.sender];
        uint256 reward = (amount * APY_BPS * elapsed) / (365 days * 10000);
        staked[msg.sender] = 0;
        rnw.transfer(msg.sender, amount + reward);  // reward del pool de tesorería
    }
}
```

Comandos para arrancar (copy-paste)
```bash
# 1. Setup
npx hardhat init
npm install @openzeppelin/contracts @chainlink/contracts

# 2. Test local con oracle simulado
npx hardhat test
# Test crítico: simular 12 meses de generación variable (verano vs invierno)
# y verificar que la distribución acumulada coincide con kWh × tarifa

# 3. Deploy a Base Sepolia
npx hardhat run scripts/deploy.js --network baseSepolia

# 4. Script de simulación del oráculo
# Un cron job (o GitHub Action) que cada hora llama:
node scripts/simulate-oracle.js --kwh-min 500 --kwh-max 800

# 5. Frontend con chart de generación
npx create-next-app@latest rnw-app --typescript --tailwind
npm install wagmi viem @rainbow-me/rainbowkit recharts
# El chart lee eventos GenerationUpdated del contrato
```

Qué tiene que mostrar la demo (criterio de “PoC funciona”)

- [ ] Deploy de los 5 contratos en Base Sepolia con tx hashes públicos en Basescan
- [ ] Wallet A invierte USDC en perfil INITIAL (más barato) → recibe $RNW
- [ ] Wallet B invierte USDC en perfil CONSOLIDATED (más caro) → recibe $RNW
- [ ] Script “oráculo” simula 3 meses de generación con valores variables
- [ ] El contrato distribuye automáticamente sin que nadie deposite manualmente
- [ ] Wallet A stakea $RNW, espera, hace unstake() y recibe +2% APY
- [ ] Frontend muestra: chart de kWh generados por mes, balance de RNW, dividendos pendientes, posición de staking

Lo que NO hay en el PoC (y está bien)

- ❌ Medidor IoT real (el oráculo se mockea con una wallet)
- ❌ SPE / fideicomiso real
- ❌ PPA con CAMMESA
- ❌ Certificado de carbono $GREEN validado por Gold Standard
- ❌ Auditoría de smart contracts
- ❌ Múltiples nodos Chainlink (un mock alcanza)

## 11. Implementación REAL (producción)

Objetivo: entender qué falta entre el PoC y un parque tokenizado operando con plata real.

### 11.1 — Stack / infraestructura productiva
| Componente | PoC | Producción | Por qué cambia |
| Red | Base Sepolia | Base mainnet (L2 Ethereum) | Gas mínimo + finalidad rápida + EVM compatible |
| Oráculo de kWh | Wallet mock con role | Chainlink Functions + Adapter custom al medidor | Verificable, descentralizado
| Medidor IoT | — | Medidor inteligente certificado IRAM (Schneider PowerLogic, Itron, Landis+Gyr) | Sin certificación, el oráculo no es confiable |
| Backend oráculo | Script local | Node.js + signed payloads + redundancia 3 nodos | Si un nodo cae, los otros 2 confirman |
| Wallet emisor | EOA | Multi-sig Safe 3-de-5 | Una key comprometida = parque robado |
| Indexer | Eventos directos | The Graph subgraph con histórico de generación | Dashboards regulatorios, auditoría |
| Monitoring | Logs | Tenderly + alertas si el oráculo no reporta en 48h | Fallback manual del fiduciario |
| Frontend | Vercel free | Vercel Pro + dominio + chart con histórico | UX para inversores institucionales |

### 11.2 — Legal / regulatorio Argentina

| Pieza | Para qué | Cómo |
|-------|----------|------|
| SPE / Fideicomiso financiero | Dueño legal del parque solar/eólico | Constituido vía escribano. El SPE firma el PPA con CAMMESA. |
| PPA (Power Purchase Agreement) | Contrato de venta de energía a la red | Con CAMMESA o privado (PPA corporativo). Define tarifa $/kWh y plazo (10-20 años). |
| Marco CNV | $RNW es security token (CP de fideicomiso) | Resolución CNV 717/2017 PFC + asesoría sectorial |
| Marco ENRE / régimen MATER | Habilitación del parque para inyectar a la red | Generación distribuida o gran usuario (depende del MW). Régimen MATER para renovables. |
| KYC/AML | Onfido / Veriff | Obligatorio para inversores AR |
| Asesoramiento legal sectorial | NO alcanza con un abogado crypto | Estudio con expertise en energía + financiero + crypto. Combinación rara. |
| Auditoría energética | Verificar que el medidor no fue manipulado | Empresa especializada (ej: TÜV Rheinland, Bureau Veritas) — anual mínimo |
| Certificación de carbono $GREEN | Para que el certificado tenga valor real | Gold Standard o Verra VCS. Proceso de certificación 6-12 meses, costo USD 30-80k. |

### 11.3 — Oráculos y auditorías
|Componente 	Para qué 	Proveedor / costo estimado
Medidor IoT certificado 	Hardware en el parque 	Schneider / Itron / Landis+Gyr → USD 2.000 – 8.000 por punto de medición
Chainlink Functions 	Backend que conecta el medidor con el contrato 	Setup técnico ~USD 5.000 + USD 100-500/mes en LINK
Redundancia de oráculos 	3 nodos independientes cruzan datos 	USD 1.500 – 3.000/mes (3 nodos × ~USD 500-1.000)
Auditoría smart contracts 	CertiK / Trail of Bits / OpenZeppelin 	USD 30.000 – 80.000 (oráculos suman complejidad)
Auditoría energética anual 	TÜV / Bureau Veritas 	USD 8.000 – 20.000
Certificación Gold Standard 	Para $GREEN como carbono real 	USD 30.000 – 80.000 (single project)
Bug bounty 	Immunefi 	Pool USD 50k – 500k
11.4 — Costos estimados (USD) para arrancar el primer parque en producción
Concepto 	Costo único 	Costo mensual
Smart contract audit 	USD 40.000 – 80.000 	—
Asesoramiento legal (crypto + energía + financiero) 	USD 25.000 – 50.000 	USD 3.000 – 6.000
Constitución SPE + PPA con CAMMESA 	USD 10.000 – 30.000 	USD 1.500 – 4.000
Inscripción CNV PFC 	USD 5.000 – 20.000 	USD 500 – 2.000
Habilitación ENRE / régimen MATER 	USD 5.000 – 15.000 	—
Medidor IoT certificado 	USD 2.000 – 8.000 	—
Chainlink Functions setup + nodes redundantes 	USD 5.000 – 10.000 	USD 1.500 – 3.500
Auditoría energética anual 	— 	USD 700 – 1.700 (prorrateado)
Certificación Gold Standard ($GREEN) 	USD 30.000 – 80.000 	USD 1.000 – 3.000 (verificación)
KYC/AML provider 	USD 1.000 setup 	USD 2 – 5 por inversor
Multi-sig Safe 	USD 10 (gas) 	—
The Graph subgraph 	— 	USD 200 – 800
Tenderly + Alchemy + Vercel 	USD 200 setup 	USD 400 – 1.200
Bug bounty pool 	USD 50.000 – 500.000 (escrow) 	—
Gas de deploy + operación 	USD 1.000 – 3.000 	USD 200 – 800
TOTAL ESTIMADO 	USD 125.000 – 305.000 	USD 9.000 – 23.000

### Consideración crítica (cierre)

El proyecto es más caro de producir que resto de la materia porque agrega el costo de oráculos certificados + auditoría energética + certificación de carbono. Pero también es el más defensible ante regulación y ante inversores institucionales, justamente por la verificabilidad. Vale la pena solo si proyectás USD 300-500k de fees el primer año (que es realista con un parque de 5MW operando).

## Hitos del salto PoC → Producción

1. PoC funcional con oráculo mock — demo en Base Sepolia con generación simulada
2. Asesoramiento legal triple (crypto + energía + financiero) — estructura legal validada
3. Constitución SPE + firma PPA — parque legal + contrato de venta de energía
4. Instalación medidor IoT + integración Chainlink Functions — oráculo real reportando kWh on-chain
5. Auditoría smart contracts — reporte firmado + correcciones
6. Inscripción CNV PFC + habilitación ENRE — resoluciones obtenidas
7. Certificación Gold Standard $GREEN — $GREEN validado como crédito de carbono real
8. KYC/AML + frontend productivo — app lista para inversores reales
9. Mainnet deploy + multi-sig + monitoring — infraestructura productiva
10. TGE del primer parque — primera ronda con USDC real

12. Próximo paso

* Releé esta página y discutí los 9 puntos del checklist con tu grupo.
* Arrancá la implementación mínima — esa es la entrega del cuatrimestre. El truco es mockear el oráculo bien: que el flujo end-to-end se sienta automático.
* Investigá Chainlink Functions y medidores certificados IRAM para entender la fase 4.
* Investigá Gold Standard o Verra VCS para entender qué necesita $GREEN como certificado real.
* Finalmente, consultar el documento técnico de referencia (tokenizacion_crowdfunding_v2.md) — sección Energía Renovable.

De momento, como grupo, nos enfocamos al PoC y que funcione.
La informacion de este modelo fue extraido de estas paginas:
* https://dpetrocelli.github.io/sip2026/tokenization/EnergiaRenovable_token.html
* https://dpetrocelli.github.io/sip2026/tokenization/intro_simple.html
