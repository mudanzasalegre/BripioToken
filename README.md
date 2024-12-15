# Bripio

Bripio es un sistema de gestión de activos digitales basado en contratos inteligentes en la red Ethereum. Este sistema incluye un token ERC20 llamado Bripio Token (BRP) respaldado por una tesorería gestionada mediante el contrato BripioVault. Además, utiliza un sistema de gobernanza descentralizada implementado con `BripioGovernor` y `BripioTimelockController`, permitiendo a los poseedores del token participar en la toma de decisiones.

## Características principales

- **Token ERC20 con capacidades extendidas**:
  - Funcionalidades de quema (burn) y pausa (pause).
  - Sistema de gobernanza basado en votos (ERC20Votes).
  - Compatibilidad con permisos y firmas off-chain (ERC20Permit).

- **Tesorería gestionada con reservas de ETH y stablecoins**:
  - Control total mediante el contrato `BripioVault`.
  - Respaldo del token basado en el valor combinado de las reservas y el PIB.

- **Oráculos de precios**:
  - Precios de ETH y USDC obtenidos de Chainlink para cálculos dinámicos.

- **Gobernanza descentralizada**:
  - Propuestas y votaciones gestionadas por los poseedores del token BRP.
  - Ejecución automática de decisiones a través del `BripioTimelockController`.

- **Configuración económica flexible**:
  - Parámetros ajustables como `alpha` (peso del PIB) y `beta` (peso de activos digitales).
  - Límites dinámicos de transacción.

---

## Contratos

### 1. BripioVault
El contrato `BripioVault` gestiona las reservas de la tesorería. Permite recibir y retirar tanto ETH como stablecoins, proporcionando respaldo económico al sistema.

#### Funciones principales
- **Depositar ETH**:  
  Los usuarios pueden depositar ETH directamente en la tesorería mediante:  
  `function depositEth() external payable;`

- **Depositar stablecoins**:  
  Los usuarios pueden transferir USDC al contrato con:  
  `function depositStablecoins(uint256 amount) external;`

- **Consultar reservas**:  
  Permite obtener los saldos actuales de ETH y stablecoins:  
  `function getTreasuryBalances() external view returns (uint256 ethBalance, uint256 stablecoinBalance);`

- **Retirar fondos**:  
  Solo el propietario puede retirar fondos (ETH y/o stablecoins) del contrato:  
  `function withdrawFunds(address recipient, uint256 ethAmount, uint256 stablecoinAmount) external onlyOwner;`

- **Actualizar dirección de stablecoin**:  
  Permite cambiar la dirección del contrato de la stablecoin utilizada:  
  `function updateStablecoinAddress(address _newStablecoin) external onlyOwner;`

---

### 2. BripioToken
El contrato `BripioToken` define el token ERC20 BRP, que está respaldado por la tesorería gestionada por el contrato `BripioVault`. La economía del token está basada en las reservas de ETH y stablecoins, junto con el valor aproximado del PIB configurado.

#### Funciones principales
- **Habilitar trading**:  
  Permite habilitar el intercambio de tokens:  
  `function enableTrading() external onlyOwner;`

- **Comprar tokens con ETH**:  
  Los usuarios pueden adquirir tokens BRP utilizando ETH, que será enviado a la tesorería:  
  `function buyWithEth() external payable;`

- **Comprar tokens con stablecoins**:  
  Los usuarios pueden adquirir tokens BRP utilizando stablecoins (USDC):  
  `function buyWithStablecoins(uint256 stablecoinAmount) external;`

- **Actualizar parámetros económicos**:  
  El propietario puede ajustar valores como el PIB y los pesos económicos (`alpha` y `beta`):  
  - `function updatePibValue(uint256 _pibValue) external onlyOwner;`  
  - `function updateWeights(uint256 newAlpha, uint256 newBeta) external onlyOwner;`

- **Actualizar límite máximo de transacción**:  
  Permite modificar el límite máximo de tokens que un usuario puede adquirir en una única transacción:  
  `function updateMaxTransactionAmount(uint256 newLimit) external onlyOwner;`

- **Consultar el precio del token**:  
  Calcula el precio del token en función de las reservas de la tesorería y los parámetros económicos configurados:  
  `function calculatePrice() public view returns (uint256);`

---

### 3. BripioTimelockController
El contrato `BripioTimelockController` gestiona la ejecución de propuestas aprobadas con un retraso configurable. Este contrato permite un control descentralizado al ejecutar automáticamente las decisiones aprobadas por los gobernadores.

#### Funciones principales
- **Actualizar retraso mínimo**:  
  Permite modificar el retraso mínimo antes de ejecutar propuestas:  
  `function setDelay(uint256 newDelay) external onlyRole(TIMELOCK_ADMIN_ROLE);`

- **Programar con retraso personalizado**:  
  Programa operaciones utilizando el retraso actual:  
  `function scheduleWithCustomDelay(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt) external onlyRole(PROPOSER_ROLE);`

- **Gestión de roles**:  
  Permite añadir o eliminar proponentes y ejecutores, así como asignar o revocar el rol de administrador.  

---

### 4. BripioGovernor
El contrato `BripioGovernor` implementa la lógica de gobernanza, permitiendo a los poseedores de BRP crear propuestas, votar y gestionar el sistema.

#### Funciones principales
- **Crear propuestas**:  
  Los gobernadores pueden crear propuestas para ejecutar cambios en el sistema.

- **Votar**:  
  Los poseedores de BRP pueden votar las propuestas en función de su poder de voto.

- **Ejecución automática**:  
  Las propuestas aprobadas se ejecutan automáticamente mediante el `BripioTimelockController`.

---

## Cálculo del precio del token
El precio del token se calcula considerando los siguientes factores:
1. **Reservas en la tesorería**:  
   - ETH y USDC depositados en el contrato `BripioVault`.  
   - Valores de mercado obtenidos a través de oráculos Chainlink.
2. **Parámetros económicos**:  
   - `alpha`: peso asignado al PIB en el cálculo.  
   - `beta`: peso asignado a los activos digitales (ETH y stablecoins).  
3. **Total Supply**:  
   - La cantidad de tokens actualmente en circulación.  

La fórmula utilizada es:  
```
totalRespaldo = (alpha * pibValue) / 100 + (beta * (ethValueUSD + stablecoinValueUSD)) / 100;
price = totalRespaldo / totalSupply;
```

---

## Requisitos
- Red Ethereum compatible con contratos inteligentes.
- Contratos implementados con Solidity 0.8.28.
- Oráculos Chainlink para precios de ETH y USDC:
  - ETH/USD: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
  - USDC/USD: `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6`

---

## Cómo empezar
1. Clona el repositorio:  
   `git clone https://github.com/tu-usuario/bripio.git`

2. Compila los contratos:  
   Usa una herramienta como Remix o Hardhat para compilar los contratos.

3. Despliega los contratos:  
   - Despliega primero el contrato `BripioVault`.
   - Usa la dirección del contrato desplegado para inicializar `BripioToken`.

4. Configura la gobernanza:  
   - Despliega `BripioTimelockController` con los parámetros iniciales.  
   - Inicializa `BripioGovernor` con el token de votos (`BripioToken`) y el timelock.  

5. Configura la tesorería:  
   - Deposita ETH o USDC en el contrato `BripioVault`.  
   - Actualiza los parámetros económicos (`alpha`, `beta`, `pibValue`) según sea necesario.

6. Habilita el trading:  
   Ejecuta `enableTrading` en el contrato `BripioToken` para permitir la compra de tokens.

---

## Licencia
Este proyecto está bajo la licencia PropietarioUnico.
