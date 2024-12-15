// SPDX-License-Identifier: PropietarioUnico
//                 valores iniciales
//                 -----------------
// -  ETH / USD Price Feed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
// - USDC / USD Price Feed: 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
//                   Alpha: 60 (PIB)
//                    Beta: 40 (Activos digitales)
//              max supply: 1_440_216_000 * 10**18
//    maxTransactionAmount: 2_880_432 * 10**18;
//               pib value: 2_400_000_000;
//                    Eth : 20 * 10**18;
//                  stable: 500_000 * 10**6;
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BripioVault is Ownable {
    // Estado de inicialización
    bool private initialized;

    // Eventos
    event FundsDeposited(
        address indexed sender,
        uint256 ethAmount,
        uint256 stablecoinAmount
    );
    event FundsWithdrawn(
        address indexed recipient,
        uint256 ethAmount,
        uint256 stablecoinAmount
    );
    event StablecoinAddressUpdated(
        address indexed oldAddress,
        address indexed newAddress
    );

    modifier initializer() {
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }

    // Dirección del stablecoin (USDC por ejemplo)
    IERC20 public stablecoin;

    constructor() Ownable(msg.sender) {
        _init();
    }

    function _init() internal initializer {

        stablecoin = IERC20(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    }

    // Actualizar la dirección del stablecoin
    function updateStablecoinAddress(address _newStablecoin)
        external
        onlyOwner
    {
        address oldAddress = address(stablecoin);
        stablecoin = IERC20(_newStablecoin);
        emit StablecoinAddressUpdated(oldAddress, _newStablecoin);
    }

     // Función para depositar ETH manualmente
    function depositEth() external payable {
        require(msg.value > 0, "Must send ETH to deposit");
        emit FundsDeposited(msg.sender, msg.value, 0);
    }

    // Depositar stablecoins manualmente
    function depositStablecoins(uint256 amount) external {
        require(
            stablecoin.transferFrom(msg.sender, address(this), amount),
            "Stablecoin transfer failed"
        );
        emit FundsDeposited(msg.sender, 0, amount);
    }

    // Retirar ETH y stablecoins
    function withdrawFunds(
        address recipient,
        uint256 ethAmount,
        uint256 stablecoinAmount
    ) external onlyOwner {
        // Enviar ETH
        if (ethAmount > 0) {
            require(
                address(this).balance >= ethAmount,
                "Insufficient ETH balance"
            );
            payable(recipient).transfer(ethAmount);
        }

        // Enviar stablecoins
        if (stablecoinAmount > 0) {
            require(
                stablecoin.balanceOf(address(this)) >= stablecoinAmount,
                "Insufficient stablecoin balance"
            );
            stablecoin.transfer(recipient, stablecoinAmount);
        }

        emit FundsWithdrawn(recipient, ethAmount, stablecoinAmount);
    }

    // Consultar saldos
    function getTreasuryBalances()
        external
        view
        returns (uint256 ethBalance, uint256 stablecoinBalance)
    {
        ethBalance = address(this).balance;

        // Manejar errores al llamar balanceOf del stablecoin
        try stablecoin.balanceOf(address(this)) returns (uint256 balance) {
            stablecoinBalance = balance;
        } catch {
            stablecoinBalance = 0;
        }

        return (ethBalance, stablecoinBalance);
    }
    
    // Función para recibir ETH
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value, 0);
    }
}
