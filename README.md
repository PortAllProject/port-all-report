# AElf - OCR Contract

## 布置合约

PORT Token contract => SimpleWriteAccessController contract => AccessControlledOffchainAggregator contract

migrations中有具体的配置信息。

## 初始化合约

1. 设置payee信息，AccessControlledOffchainAggregator contract： setPayees。
2. 设置节点配置信息，AccessControlledOffchainAggregator contract： setConfig。
3. 打入Port token到AccessControlledOffchainAggregator合约地址。

## 经济系统

1. 合约使用者需要先向该合约中打入一定量的Port token，用于支付transmitter和observer。

2. transmitter搬运数据获得Port的补偿。
计算思路：估算用户transmit交易大概花费的gas fee， 按照一定比例换算成Port。

3. aelf上搬运数据的节点获得Port。
计算思路：按照用户在AElf上搬运数据的次数进行支付Port。

## 合约主要api

### **设置收费地址(setPayees)**

```plain
  function setPayees(
    address[] calldata _transmitters,
    address[] calldata _payees
  )
    external
    onlyOwner()
    
  event PayeeshipTransferred(
    address indexed transmitter,
    address indexed previous,
    address indexed current
  );
```

由合约owner调用，用于设置收费地址。所有的收益都将打入该payee地址。

* **输入参数**
    * **_transmitters**: 数据提交者的地址。
    * **_payees**:**配置版本。

* **PayeeshipTransferred事件**
    * **transmitter**: transmitter的地址。
    * **previous**: transmiiter前一次收费地址。
    * **current**: transmitter当前的收费地址。

### **设置合约的配置(setConfig)**

```plain
function setConfig(
        address[] calldata _signers,
        address[] calldata _transmitters,
        uint64 _encodedConfigVersion,
        bytes calldata _encoded
    )
        external
        checkConfigValid(_signers.length, _transmitters.length)
        onlyOwner()
    event ConfigSet(
        uint32 previousConfigBlockNumber,
        uint64 configCount,
        address[] signers,
        address[] transmitters,
        uint64 encodedConfigVersion,
        bytes encoded
    );
```

由合约owner调用，signer地址为transmitter用于进行签名的私钥的地址。调用该接口后会将前一次配置中的收益结清。

* **输入参数**
    * **_signers**:签名者的地址。
    * **_transmitters**: 数据提交者的地址。
    * **_encodedConfigVersion:**配置版本。
    * **_encoded:**线下配置的编码。

* **ConfigSet事件**
    * **previousConfigBlockNumber**: 上一次修改配置的block高度。
    * **configCount**: 修改配置的次数。
    * **signers**: 签名者的地址。
    * **transmitters**: 数据提交者的地址。
    * **encodedConfigVersion:**配置版本。
    * **encoded:**线下配置的版本的编码。

### **提交数据(transmit)**

```plain
function transmit(
        bytes calldata _report,
        bytes32[] calldata _rs,
        bytes32[] calldata _ss,
        bytes32 _rawVs
    ) external 
```

transmitter通过该接口提交数据。
r、s、v的生成：对report进行hash，使用私钥以及椭圆曲线对其签名生成地址：singer。
r、s、v的作用：通过使用ecrecover函数还原签名的address地址，即合约中的singer。
report: 由context、observers、observersCount、observation、observationIndex、observationLength、 multipleObservation组成。

* **输入参数**
    * **_report**: aelf上reprot的序列化。
    * **_rs**: 还原signer签名地址的r值。
    * **_ss**: 还原signer签名地址的s值。
    * **_rawVs**: 还原signer签名地址的v值。

* **report**
    * **context**: 全长32个byte，由6个0 byte、16个byte的config digest(setConfig时根据设置的信息hash生成，transmit时的config digest需要与合约中当前的config digest相同)、8个byte的round id、1个byte的observer count、一个byte的valid byte count构成。
    * **observers**: 全长32个byte，记录的是s_oracleObservationsCounts的index，即每一个observer的index，最多记录32个obserer的index，一轮提交中observer的数量记录在context中的observer count。
    * **observersCount**: 全长32个byte，记录的是每一个observer在本轮数据提交中提供数据的个数。为s_oracleObservationsCounts\[index] = count，每一个byte记录一个observer的count，最多记录32个observer的count。
    * **observation**: 全长32个byte，数据观测值，当一轮只查询一个数据时，该observation为该数据的确切值，其中数据的具体长度记录在context的valid byte count中；当一轮查询多个数据时，observation记录的是这些数据生成的MerkleTree root，此时具体的多个数据记录在multipleObservation中。一个数据的最长存储是32个byte。
    * **observationIndex**: 全长32个byte，当一轮查询中有多个数据时，记录每个数据的index。每个数据的index用一个byte来记录。
    * **observationLength**: 全长32个byte，当一轮查询中有多个数据时，记录每个数据的的有效长度。每个数据的长度用一个byte来记录。
    * **multipleObservation**: 为bytes32[]，当一轮查询中有多个数据时用于记录各个数据的值。

## 签名工具
参考./tool/ReportGenerator。