// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "./AccessControllerInterface.sol";
import "./PortTokenInterface.sol";
import "./Owned.sol";
import "../library/SafeMath.sol";

contract OffchainAggregatorBilling is Owned {
  using SafeMath for uint256;

  uint256 constant internal maxNumOracles = 31;

  struct Billing {
    uint32 maximumGasPrice;
    uint32 reasonableGasPrice;
    uint32 microPortPerEth;
    uint32 portGweiPerObservation;
    uint32 portGweiPerTransmission;
  }
  Billing internal s_billing;
  PortTokenInterface immutable public PORT;
  AccessControllerInterface internal s_billingAccessController;
  uint16[maxNumOracles] internal s_oracleObservationsCounts;
  mapping (address => address)
    internal
    s_payees;

  mapping (address => address)
    internal
    s_proposedPayees;
  
  uint256[maxNumOracles] internal s_gasReimbursementsPortWei;
  enum Role {
    Unset,
    Signer,
    Transmitter
  }

  struct Oracle {
    uint8 index;
    Role role;
  }

  mapping (address => Oracle)
    internal s_oracles;

  address[] internal s_signers;
  address[] internal s_transmitters;

  uint256 constant private  maxUint16 = (1 << 16) - 1;
  uint256 constant internal maxUint128 = (1 << 128) - 1;

  constructor(
    uint32 _maximumGasPrice,
    uint32 _reasonableGasPrice,
    uint32 _microPortPerEth,
    uint32 _portGweiPerObservation,
    uint32 _portGweiPerTransmission,
    address _port,
    AccessControllerInterface _billingAccessController
  )
  {
    setBillingInternal(_maximumGasPrice, _reasonableGasPrice, _microPortPerEth,
      _portGweiPerObservation, _portGweiPerTransmission);
    setBillingAccessControllerInternal(_billingAccessController);
    PORT = PortTokenInterface(_port);
    uint16[maxNumOracles] memory counts;
    uint256[maxNumOracles] memory gas;
    for (uint8 i = 0; i < maxNumOracles; i++) {
      counts[i] = 0;
      gas[i] = 0;
    }
    s_oracleObservationsCounts = counts;
    s_gasReimbursementsPortWei = gas;

  }

  event BillingSet(
    uint32 maximumGasPrice,
    uint32 reasonableGasPrice,
    uint32 microPortPerEth,
    uint32 portGweiPerObservation,
    uint32 portGweiPerTransmission
  );

  function setBillingInternal(
    uint32 _maximumGasPrice,
    uint32 _reasonableGasPrice,
    uint32 _microPortPerEth,
    uint32 _portGweiPerObservation,
    uint32 _portGweiPerTransmission
  )
    internal
  {
    s_billing = Billing(_maximumGasPrice, _reasonableGasPrice, _microPortPerEth,
      _portGweiPerObservation, _portGweiPerTransmission);
    emit BillingSet(_maximumGasPrice, _reasonableGasPrice, _microPortPerEth,
      _portGweiPerObservation, _portGweiPerTransmission);
  }

  function setBilling(
    uint32 _maximumGasPrice,
    uint32 _reasonableGasPrice,
    uint32 _microPortPerEth,
    uint32 _portGweiPerObservation,
    uint32 _portGweiPerTransmission
  )
    external
  {
    AccessControllerInterface access = s_billingAccessController;
    require(msg.sender == owner || access.hasAccess(msg.sender, msg.data),
      "Only owner&billingAdmin can call");
    payOracles();
    setBillingInternal(_maximumGasPrice, _reasonableGasPrice, _microPortPerEth,
      _portGweiPerObservation, _portGweiPerTransmission);
  }

  function getBilling()
    external
    view
    returns (
      uint32 maximumGasPrice,
      uint32 reasonableGasPrice,
      uint32 microPortPerEth,
      uint32 portGweiPerObservation,
      uint32 portGweiPerTransmission
    )
  {
    Billing memory billing = s_billing;
    return (
      billing.maximumGasPrice,
      billing.reasonableGasPrice,
      billing.microPortPerEth,
      billing.portGweiPerObservation,
      billing.portGweiPerTransmission
    );
  }

  event BillingAccessControllerSet(AccessControllerInterface old, AccessControllerInterface current);

  function setBillingAccessControllerInternal(AccessControllerInterface _billingAccessController)
    internal
  {
    AccessControllerInterface oldController = s_billingAccessController;
    if (_billingAccessController != oldController) {
      s_billingAccessController = _billingAccessController;
      emit BillingAccessControllerSet(
        oldController,
        _billingAccessController
      );
    }
  }

  function setBillingAccessController(AccessControllerInterface _billingAccessController)
    external
    onlyOwner
  {
    setBillingAccessControllerInternal(_billingAccessController);
  }

  function billingAccessController()
    external
    view
    returns (AccessControllerInterface)
  {
    return s_billingAccessController;
  }

  function withdrawPayment(address _transmitter)
    external
  {
    require(msg.sender == s_payees[_transmitter], "Only payee can withdraw");
    payOracle(_transmitter);
  }

  function owedPayment(address _transmitter)
    public
    view
    returns (uint256)
  {
    Oracle memory oracle = s_oracles[_transmitter];
    if (oracle.role == Role.Unset) { return 0; }
    Billing memory billing = s_billing;
    uint256 portWeiAmount =
      uint256(s_oracleObservationsCounts[oracle.index])
      .mul(uint256(billing.portGweiPerObservation))
      .mul((1 gwei));
    portWeiAmount = s_gasReimbursementsPortWei[oracle.index].add(portWeiAmount);
    return portWeiAmount;
  }

  event OraclePaid(address transmitter, address payee, uint256 amount);

  function payOracle(address _transmitter)
    internal
  {
    Oracle memory oracle = s_oracles[_transmitter];
    uint256 portWeiAmount = owedPayment(_transmitter);
    if (portWeiAmount > 0) {
      address payee = s_payees[_transmitter];
      require(PORT.transfer(payee, portWeiAmount), "insufficient funds");
      s_oracleObservationsCounts[oracle.index] = 0;
      s_gasReimbursementsPortWei[oracle.index] = 0;
      emit OraclePaid(_transmitter, payee, portWeiAmount);
    }
  }

  function payOracles()
    internal
  {
    Billing memory billing = s_billing;
    uint16[maxNumOracles] memory observationsCounts = s_oracleObservationsCounts;
    uint256[maxNumOracles] memory gasReimbursementsPortWei =
      s_gasReimbursementsPortWei;
    address[] memory transmitters = s_transmitters;
    for (uint transmitteridx = 0; transmitteridx < transmitters.length; transmitteridx++) {
      uint256 reimbursementAmountPortWei = gasReimbursementsPortWei[transmitteridx];
      uint256 obsCount = observationsCounts[transmitteridx];
      uint256 portWeiAmount =
        obsCount.mul(uint256(billing.portGweiPerObservation)).mul(1 gwei).add(reimbursementAmountPortWei);
      if (portWeiAmount > 0) {
          address payee = s_payees[transmitters[transmitteridx]];
          require(PORT.transfer(payee, portWeiAmount), "insufficient funds");
          observationsCounts[transmitteridx] = 0;
          gasReimbursementsPortWei[transmitteridx] = 0;
          emit OraclePaid(transmitters[transmitteridx], payee, portWeiAmount);
        }
    }
    s_oracleObservationsCounts = observationsCounts;
    s_gasReimbursementsPortWei = gasReimbursementsPortWei;
  }

  function oracleRewards(
    bytes memory observers,
    bytes memory observersCount,
    uint16[maxNumOracles] memory observations
  )
    internal
    pure
    returns (uint16[maxNumOracles] memory)
  {
    for (uint obsIdx = 0; obsIdx < observers.length; obsIdx++) {
      uint8 observer = uint8(observers[obsIdx]);
      observations[observer] = saturatingAddUint16(observations[observer], uint8(observersCount[obsIdx]));
    }
    return observations;
  }
  uint256 internal constant accountingGasCost = 6035;

  function impliedGasPrice(
    uint256 txGasPrice,
    uint256 reasonableGasPrice,   
    uint256 maximumGasPrice
  )
    internal
    pure
    returns (uint256)
  {
    uint256 gasPrice = txGasPrice;
    if (txGasPrice < reasonableGasPrice) {
      gasPrice = reasonableGasPrice.sub(txGasPrice).div(2).add(gasPrice);
    }
    return min(gasPrice, maximumGasPrice);
  }

  function transmitterGasCostEthWei(
    uint256 initialGas,
    uint256 gasPrice,
    uint256 callDataCost,
    uint256 gasLeft
  )
    internal
    pure
    returns (uint128 gasCostEthWei)
  {
    require(initialGas >= gasLeft, "gasLeft cannot exceed initialGas");
    uint256 gasUsed =
      initialGas.sub(gasLeft).add(callDataCost).add(accountingGasCost);
    uint256 fullGasCostEthWei = gasUsed.mul(gasPrice).mul(1 gwei);
    assert(fullGasCostEthWei < maxUint128);
    return uint128(fullGasCostEthWei);
  }

  function withdrawFunds(address _recipient, uint256 _amount)
    external
  {
    require(msg.sender == owner || s_billingAccessController.hasAccess(msg.sender, msg.data),
      "Only owner&billingAdmin can call");
    uint256 portDue = totalPORTDue();
    uint256 portBalance = PORT.balanceOf(address(this));
    require(portBalance >= portDue, "insufficient balance");
    require(PORT.transfer(_recipient, min(portBalance.sub(portDue), _amount)), "insufficient funds");
  }

  function totalPORTDue()
    internal
    view
    returns (uint256 portDue)
  {
    uint16[maxNumOracles] memory observationCounts = s_oracleObservationsCounts;
    for (uint i = 0; i < maxNumOracles; i++) {
      portDue += observationCounts[i];
    }
    Billing memory billing = s_billing;
    portDue = uint256(billing.portGweiPerObservation).mul(1 gwei).mul(portDue);
    address[] memory transmitters = s_transmitters;
    uint256[maxNumOracles] memory gasReimbursementsPortWei =
      s_gasReimbursementsPortWei;
    for (uint i = 0; i < transmitters.length; i++) {
      portDue = uint256(gasReimbursementsPortWei[i]).add(portDue);
    }
  }

  function portAvailableForPayment()
    external
    view
    returns (int256 availableBalance)
  {
    int256 balance = int256(PORT.balanceOf(address(this)));
    int256 due = int256(totalPORTDue());
    return int256(balance) - int256(due);
  }

  function oracleObservationCount(address _signerOrTransmitter)
    external
    view
    returns (uint16)
  {
    Oracle memory oracle = s_oracles[_signerOrTransmitter];
    if (oracle.role == Role.Unset) { return 0; }
    return s_oracleObservationsCounts[oracle.index];
  }


  function reimburseAndRewardOracles(
    uint32 initialGas,
    bytes memory observers,
    bytes memory observerCount
  )
    internal
  {
    Oracle memory txOracle = s_oracles[msg.sender];
    Billing memory billing = s_billing;
    s_oracleObservationsCounts =
      oracleRewards(observers, observerCount, s_oracleObservationsCounts);
    require(txOracle.role == Role.Transmitter,
      "sent by undesignated transmitter"
    );
    uint256 gasPrice = impliedGasPrice(
      tx.gasprice.div(1 gwei),
      billing.reasonableGasPrice,
      billing.maximumGasPrice
    );
    uint256 callDataGasCost = 16 * msg.data.length;
    uint256 gasLeft = gasleft();
    uint256 gasCostEthWei = transmitterGasCostEthWei(
      uint256(initialGas),
      gasPrice,
      callDataGasCost,
      gasLeft
    );
    uint256 gasCostPortWei = gasCostEthWei.mul(billing.microPortPerEth).div(1e6);
    s_gasReimbursementsPortWei[txOracle.index] =
      s_gasReimbursementsPortWei[txOracle.index]
      .add(gasCostPortWei)
      .add(uint256(billing.portGweiPerTransmission).mul(1 gwei));
  }

  event PayeeshipTransferRequested(
    address indexed transmitter,
    address indexed current,
    address indexed proposed
  );

  event PayeeshipTransferred(
    address indexed transmitter,
    address indexed previous,
    address indexed current
  );

  function setPayees(
    address[] calldata _transmitters,
    address[] calldata _payees
  )
    external
    onlyOwner()
  {
    require(_transmitters.length == _payees.length, "transmitters.size != payees.size");

    for (uint i = 0; i < _transmitters.length; i++) {
      address transmitter = _transmitters[i];
      address payee = _payees[i];
      address currentPayee = s_payees[transmitter];
      bool zeroedOut = currentPayee == address(0);
      require(zeroedOut || currentPayee == payee, "payee already set");
      s_payees[transmitter] = payee;

      if (currentPayee != payee) {
        emit PayeeshipTransferred(transmitter, currentPayee, payee);
      }
    }
  }

  function transferPayeeship(
    address _transmitter,
    address _proposed
  )
    external
  {
      require(msg.sender == s_payees[_transmitter], "only current payee can update");
      require(msg.sender != _proposed, "cannot transfer to self");

      address previousProposed = s_proposedPayees[_transmitter];
      s_proposedPayees[_transmitter] = _proposed;

      if (previousProposed != _proposed) {
        emit PayeeshipTransferRequested(_transmitter, msg.sender, _proposed);
      }
  }

  function acceptPayeeship(
    address _transmitter
  )
    external
  {
    require(msg.sender == s_proposedPayees[_transmitter], "only proposed payees can accept");

    address currentPayee = s_payees[_transmitter];
    s_payees[_transmitter] = msg.sender;
    s_proposedPayees[_transmitter] = address(0);

    emit PayeeshipTransferred(_transmitter, currentPayee, msg.sender);
  }

  function saturatingAddUint16(uint16 _x, uint16 _y)
    internal
    pure
    returns (uint16)
  {
    return uint16(min(uint256(_x)+uint256(_y), maxUint16));
  }

  function min(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
  {
    if (a < b) { return a; }
    return b;
  }
}
