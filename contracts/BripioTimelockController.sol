// SPDX-License-Identifier: PropietarioUnico
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract BripioTimelockController is TimelockController {
    // Variable para rastrear el retraso mínimo actual
    uint256 private _currentMinDelay;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");

    constructor(
        uint256 minDelay, // Retraso mínimo en segundos
        address[] memory proposers, // Dirección de los proponentes iniciales
        address[] memory executors, // Dirección de los ejecutores iniciales
        address admin // Dirección que recibe el rol de administrador inicialmente
    ) TimelockController(minDelay, proposers, executors, admin) {
        // Inicializar el retraso mínimo
        _currentMinDelay = minDelay;
    }

    // Función para actualizar el retraso mínimo
    function setDelay(uint256 newDelay) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        require(newDelay > 0, "Delay must be greater than zero");
        _currentMinDelay = newDelay;
    }

    // Función para obtener el retraso actual
    function getMinDelay() public view override returns (uint256) {
        return _currentMinDelay;
    }

    // Función personalizada que aplica el retraso mínimo actual en las operaciones de timelock
    function scheduleWithCustomDelay(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external onlyRole(PROPOSER_ROLE) {
        schedule(target, value, data, predecessor, salt, _currentMinDelay);
    }

    // Función para añadir un proponente
    function addProposer(address proposer) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        grantRole(PROPOSER_ROLE, proposer);
    }

    // Función para eliminar un proponente
    function removeProposer(address proposer) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        revokeRole(PROPOSER_ROLE, proposer);
    }

    // Función para añadir un ejecutor
    function addExecutor(address executor) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        grantRole(EXECUTOR_ROLE, executor);
    }

    // Función para eliminar un ejecutor
    function removeExecutor(address executor) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        revokeRole(EXECUTOR_ROLE, executor);
    }

    // Función para asignar el rol de administrador a otro usuario
    function assignAdminRole(address newAdmin) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        grantRole(TIMELOCK_ADMIN_ROLE, newAdmin);
    }

    // Función para revocar el rol de administrador
    function revokeAdminRole(address admin) external onlyRole(TIMELOCK_ADMIN_ROLE) {
        revokeRole(TIMELOCK_ADMIN_ROLE, admin);
    }
}