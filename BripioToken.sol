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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./BripioVault.sol";

contract BripioToken is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    Ownable,
    ERC20Permit,
    ERC20Votes
{
    // Referencia al contrato Tesoro
    BripioVault public vault;

    // Oráculos de precios
    AggregatorV3Interface public ethPriceFeed;
    AggregatorV3Interface public stablecoinPriceFeed;

    // Parámetros económicos y de tesorería
    uint256 public alpha;
    uint256 public beta;
    uint256 public pibValue;
    uint256 public immutable maxSupply;
    uint256 public maxTransactionAmount;
    bool public tradingEnabled = false;

    // Estado de inicialización
    bool private initialized;

    // Eventos
    event VaultUpdated(
        uint256 ethBalance,
        uint256 stablecoinBalance,
        uint256 pib
    );
    event WeightsUpdated(uint256 alpha, uint256 beta);
    event TradingEnabled();
    event TokensPurchased(
        address indexed buyer,
        uint256 amountPaid,
        uint256 tokensMinted,
        string paymentMethod
    );
    event Minted(address indexed to, uint256 amount);

    modifier initializer() {
        require(!initialized, "Already initialized");
        initialized = true;
        _;
    }

    constructor(
        //address initialOwner,
        //address _ethPriceFeed,
        //address _stablecoinPriceFeed,
        address payable _vaultAddress
    )
        ERC20("Bripio Token", "BRP")
        Ownable(msg.sender)
        ERC20Permit("Bripio Token")
    {
        vault = BripioVault(_vaultAddress);
        maxSupply = 1_440_216_000 * 10**18;
        _init();
    }

    function _init() internal initializer {
        alpha = 60;
        beta = 40;
        pibValue = 2_400_000_000;
        maxTransactionAmount = 10 * 10**18; // Dinámico, inicial en 10 ETH
        ethPriceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        stablecoinPriceFeed = AggregatorV3Interface(
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        );
        _mint(address(this), maxSupply / 10);
    }

    // Habilitar trading
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled();
    }

    // Actualizar el límite de transacción
    function updateMaxTransactionAmount(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Max transaction amount must be greater than 0");
        maxTransactionAmount = newLimit;
    }

    // Actualizar valor del PIB
    function updatePibValue(uint256 _pibValue) external onlyOwner {
        pibValue = _pibValue;
        (uint256 ethBalance, uint256 stablecoinBalance) = vault
            .getTreasuryBalances();
        emit VaultUpdated(ethBalance, stablecoinBalance, pibValue);
    }

    // Actualizar el valor de alpha
    function updateAlpha(uint256 newAlpha) external onlyOwner {
        require(newAlpha + beta == 100, "Alpha and Beta must sum up to 100");
        alpha = newAlpha;
        emit WeightsUpdated(alpha, beta);
    }

    // Actualizar el valor de beta
    function updateBeta(uint256 newBeta) external onlyOwner {
        require(alpha + newBeta == 100, "Alpha and Beta must sum up to 100");
        beta = newBeta;
        emit WeightsUpdated(alpha, beta);
    }

    // Comprar tokens con ETH
    function buyWithEth() external payable {
        require(tradingEnabled, "Trading is not enabled yet");

        uint256 ethPrice = getEthPrice();
        uint256 price = calculatePrice();
        uint256 tokensToMint = (msg.value * ethPrice) / price;

        require(
            tokensToMint <= maxTransactionAmount,
            "Exceeds max transaction limit"
        );
        require(
            totalSupply() + tokensToMint <= maxSupply,
            "Exceeds max supply"
        );

        (bool success, ) = address(vault).call{value: msg.value}("");
        require(success, "Transfer to vault failed");

        _mint(msg.sender, tokensToMint);

        emit TokensPurchased(msg.sender, msg.value, tokensToMint, "ETH");
    }

    // Comprar tokens con stablecoins
    function buyWithStablecoins(uint256 stablecoinAmount) external {
        require(tradingEnabled, "Trading is not enabled yet");

        uint256 stablecoinPrice = getStablecoinPrice();
        uint256 price = calculatePrice();
        uint256 tokensToMint = (stablecoinAmount * stablecoinPrice) / price;

        require(
            tokensToMint <= maxTransactionAmount,
            "Exceeds max transaction limit"
        );
        require(
            totalSupply() + tokensToMint <= maxSupply,
            "Exceeds max supply"
        );

        require(
            vault.stablecoin().transferFrom(
                msg.sender,
                address(vault),
                stablecoinAmount
            ),
            "Stablecoin transfer failed"
        );

        _mint(msg.sender, tokensToMint);

        emit TokensPurchased(
            msg.sender,
            stablecoinAmount,
            tokensToMint,
            "Stablecoin"
        );
    }

    // Pausar el contrato
    function pause() public onlyOwner {
        _pause();
        emit Paused(msg.sender);
    }

    // Reanudar el contrato
    function unpause() public onlyOwner {
        _unpause();
        emit Unpaused(msg.sender);
    }

    // Calcular el precio del token en función de las reservas y parámetros
    function calculatePrice() public view returns (uint256) {
        (uint256 ethBalance, uint256 stablecoinBalance) = vault
            .getTreasuryBalances();

        // Verificar que haya al menos una reserva no nula
        require(
            ethBalance > 0 || stablecoinBalance > 0,
            "Treasury has insufficient reserves"
        );

        uint256 ethValueUSD = getEthPrice() * ethBalance;
        uint256 stablecoinValueUSD = getStablecoinPrice() * stablecoinBalance;

        uint256 totalRespaldo = (alpha * pibValue) /
            100 +
            (beta * (ethValueUSD + stablecoinValueUSD)) /
            100;

        // Verificar que totalSupply no sea 0 para evitar división por 0
        require(totalSupply() > 0, "Total supply must be greater than 0");

        return totalRespaldo / totalSupply();
    }

    // Obtener precio actual del ETH
    function getEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH price");
        return uint256(price) * 10**10;
    }

    // Obtener precio actual de la stablecoin
    function getStablecoinPrice() public view returns (uint256) {
        (, int256 price, , , ) = stablecoinPriceFeed.latestRoundData();
        require(price > 0, "Invalid stablecoin price");
        return uint256(price) * 10**10;
    }

    // Función de mint solo para el propietario
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    // Sobreescribir funciones requeridas por Solidity para manejar herencia múltiple
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
