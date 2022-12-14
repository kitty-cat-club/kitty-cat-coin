pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "quasar-v1-periphery/contracts/interfaces/IQuasarRouter02.sol";
import "quasar-v1-core/contracts/interfaces/IQuasarFactory.sol";
import "./interfaces/ISphynxRouter.sol";
import "./interfaces/ISphynxFactory.sol";
import "./interfaces/IUniswapv2Factory.sol";
import "./interfaces/IUniswapv2Router.sol";
import "./helpers/TransferHelpers.sol";

contract VefiEcosystemTokenV2 is Ownable, AccessControl, ERC20 {
  using SafeMath for uint256;

  address public taxCollector;

  bytes32 public taxExclusionPrivilege = keccak256(abi.encode("TAX_EXCLUSION_PRIVILEGE"));
  bytes32 public liquidityExclusionPrivilege = keccak256(abi.encode("LIQUIDITY_EXCLUSION_PRIVILEGE"));

  IQuasarRouter02 qRouter;
  ISphynxRouter sRouter;
  IUniswapV2Router02 uRouter;

  uint8 public taxPercentage;
  uint8 public liquidityPercentageForEcosystem = 8;
  uint256 public maxAmount = 700000000 * 10**18;
  uint256 public minHoldOfTokenForContract = 120000 * 10**18;

  bool public swapAndLiquifyEnabled;
  bool public inSwapAndLiquify;

  modifier lockswap() {
    inSwapAndLiquify = true;
    _;
    inSwapAndLiquify = false;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 amount,
    address _taxCollector,
    uint8 _taxPercentage
  ) ERC20(name_, symbol_) {
    taxCollector = _taxCollector;
    taxPercentage = _taxPercentage;
    _mint(_msgSender(), amount);
    _grantRole(taxExclusionPrivilege, _msgSender());
    _grantRole(taxExclusionPrivilege, _taxCollector);
    qRouter = IQuasarRouter02(0x518206922Ce10787791578299Dde90d94Dd6FAA0);
    sRouter = ISphynxRouter(0x83f465457c8caFbe85aBB941F20291F826C7F72A);
    uRouter = IUniswapV2Router02(0xBb5e1777A331ED93E07cF043363e48d320eb96c4);

    address pair1 = IQuasarFactory(qRouter.factory()).createPair(qRouter.WETH(), address(this));
    address pair2 = ISphynxFactory(sRouter.factory()).createPair(sRouter.WETH(), address(this));
    address pair3 = IUniswapV2Factory(uRouter.factory()).createPair(uRouter.WETH(), address(this));

    _grantRole(liquidityExclusionPrivilege, pair1);
    _grantRole(liquidityExclusionPrivilege, pair2);
    _grantRole(liquidityExclusionPrivilege, pair3);
    _grantRole(liquidityExclusionPrivilege, address(qRouter));
    _grantRole(liquidityExclusionPrivilege, address(sRouter));
    _grantRole(liquidityExclusionPrivilege, address(uRouter));
  }

  function _splitFeesFromTransfer(uint256 amount)
    internal
    view
    returns (
      uint256 forHolders,
      uint256 forPools,
      uint256 forTaxCollector
    )
  {
    uint256 totalTaxValue = amount.mul(uint256(taxPercentage)).div(100);
    forHolders = totalTaxValue.div(3);
    forPools = totalTaxValue.div(3);
    forTaxCollector = totalTaxValue.div(3);
  }

  function _swapAndLiquify(uint256 amount) private lockswap {
    uint256 half = amount.div(2);
    uint256 otherHalf = amount.sub(half);
    uint256 initialETHBalance = address(this).balance;

    _swapThisTokenForEth(half);

    uint256 newETHBalance = address(this).balance.sub(initialETHBalance);

    // Ecosystem's fee
    uint256 ecosystemFee = newETHBalance.mul(liquidityPercentageForEcosystem).div(100);
    uint256 etherForLiquidity = newETHBalance.sub(ecosystemFee);

    if (ecosystemFee > 0) TransferHelpers._safeTransferEther(taxCollector, ecosystemFee);
    _addLiquidity(otherHalf, etherForLiquidity);
  }

  function _addLiquidity(uint256 tokenAmount, uint256 etherAmount) private {
    (uint256 splitTAmount, uint256 splitEAmount) = (tokenAmount.div(3), etherAmount.div(3));

    _approve(address(this), address(qRouter), splitTAmount);
    _approve(address(this), address(sRouter), splitTAmount);
    _approve(address(this), address(uRouter), splitTAmount);

    qRouter.addLiquidityETH{value: splitEAmount}(
      address(this),
      splitTAmount,
      0,
      0,
      address(this),
      block.timestamp.add(60 * 20)
    );
    sRouter.addLiquidityETH{value: splitEAmount}(
      address(this),
      splitTAmount,
      0,
      0,
      address(this),
      block.timestamp.add(60 * 20)
    );
    uRouter.addLiquidityETH{value: splitEAmount}(
      address(this),
      splitTAmount,
      0,
      0,
      address(this),
      block.timestamp.add(60 * 20)
    );
  }

  function _swapThisTokenForEth(uint256 amount) private {
    uint256 splitForPools = amount.div(3);

    _approve(address(this), address(qRouter), splitForPools);
    _approve(address(this), address(sRouter), splitForPools);
    _approve(address(this), address(uRouter), splitForPools);

    {
      IQuasarFactory factory = IQuasarFactory(qRouter.factory());
      address[] memory path = new address[](2);
      path[0] = address(this);
      path[1] = qRouter.WETH();

      if (IERC20(qRouter.WETH()).balanceOf(factory.getPair(address(this), qRouter.WETH())) > 0)
        qRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
          splitForPools,
          0,
          path,
          taxCollector,
          block.timestamp.add(60 * 20)
        );
    }
    {
      ISphynxFactory factory = ISphynxFactory(sRouter.factory());
      address[] memory path = new address[](2);
      path[0] = address(this);
      path[1] = sRouter.WETH();

      if (IERC20(sRouter.WETH()).balanceOf(factory.getPair(address(this), sRouter.WETH())) > 0)
        sRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
          splitForPools,
          0,
          path,
          taxCollector,
          block.timestamp.add(60 * 20)
        );
    }
    {
      IUniswapV2Factory factory = IUniswapV2Factory(uRouter.factory());
      address[] memory path = new address[](2);

      if (IERC20(uRouter.WETH()).balanceOf(factory.getPair(address(this), uRouter.WETH())) > 0)
        uRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
          splitForPools,
          0,
          path,
          taxCollector,
          block.timestamp.add(60 * 20)
        );
    }
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20) {
    if ((from != owner() && from != taxCollector) && (to != owner() && to != taxCollector))
      require(amount <= maxAmount, "transfer_amount_cannot_exceed_max_amount");

    if (!hasRole(taxExclusionPrivilege, from) && from != address(this)) {
      (uint256 forHolders, uint256 forPools, uint256 forTaxCollector) = _splitFeesFromTransfer(amount);
      uint256 perHolder = forHolders.div(2);

      uint256 tBalance = balanceOf(address(this));

      if (tBalance >= maxAmount) tBalance = maxAmount;

      bool isMinTokenBalance = tBalance >= minHoldOfTokenForContract;

      if (
        !hasRole(liquidityExclusionPrivilege, from) && isMinTokenBalance && !inSwapAndLiquify && swapAndLiquifyEnabled
      ) _swapAndLiquify(tBalance);

      super._transfer(from, to, amount.sub(forHolders + forPools + forTaxCollector).add(perHolder));
      super._transfer(from, from, perHolder);
      super._transfer(from, address(this), forPools);
      super._transfer(from, taxCollector, forTaxCollector);
    } else {
      super._transfer(from, to, amount);
    }
  }

  function setTaxPercentage(uint8 _taxPercentage) external onlyOwner {
    taxPercentage = _taxPercentage;
  }

  function setLiquidityPercentageForEcosystem(uint8 _lpPercentage) external onlyOwner {
    liquidityPercentageForEcosystem = _lpPercentage;
  }

  function setMaxAmount(uint256 _max) external onlyOwner {
    maxAmount = _max;
  }

  function switchSwapAndLiquifyEnabled() external onlyOwner {
    swapAndLiquifyEnabled = !swapAndLiquifyEnabled;
  }

  function setTaxCollector(address _taxCollector) external onlyOwner {
    _revokeRole(taxExclusionPrivilege, taxCollector);
    taxCollector = _taxCollector;
    _grantRole(taxExclusionPrivilege, _taxCollector);
  }

  function setQuasarRouter(address router) external onlyOwner {
    qRouter = IQuasarRouter02(router);
  }

  function setSphynxRouter(address router) external onlyOwner {
    sRouter = ISphynxRouter(router);
  }

  function setIUniswapV2Router(address router) external onlyOwner {
    uRouter = IUniswapV2Router02(router);
  }

  function setMinHoldOfTokenForContract(uint256 minHold) external onlyOwner {
    minHoldOfTokenForContract = minHold;
  }

  function excludeFromPayingTax(address account) external onlyOwner {
    require(!hasRole(taxExclusionPrivilege, account), "already_excluded_from_paying_tax");
    _grantRole(taxExclusionPrivilege, account);
  }

  function includeInTaxPayment(address account) external onlyOwner {
    require(hasRole(taxExclusionPrivilege, account), "already_pays_tax");
    _revokeRole(taxExclusionPrivilege, account);
  }

  function retrieveEther(address to) external onlyOwner {
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function retrieveERC20(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    TransferHelpers._safeTransferERC20(token, to, amount);
  }

  receive() external payable {}
}
