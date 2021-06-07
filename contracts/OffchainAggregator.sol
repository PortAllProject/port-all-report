// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

import "./AccessControllerInterface.sol";
import "./AggregatorInterface.sol";
import "./PortTokenInterface.sol";
import "./Owned.sol";
import "./OffchainAggregatorBilling.sol";

contract OffchainAggregator is
    Owned,
    OffchainAggregatorBilling,
    AggregatorInterface
{
    uint256 private constant maxUint32 = (1 << 32) - 1;

    struct HotVars {
        bytes16 latestConfigDigest;
        uint64 latestRoundId;
    }
    HotVars internal s_hotVars;

    struct Transmission {
        bytes32[] answer;
        uint64 timestamp;
        uint8 validBytes;
        bytes32 multipleObservationsIndex;
        bytes32 multipleObservationsValidBytes;
        bytes32[] multipleObservations;
    }
    mapping(uint64 => Transmission) internal s_transmissions;
    uint32 internal s_configCount;
    uint32 internal s_latestConfigBlockNumber; // makes it easier for offchain systems

    constructor(
        uint32 _maximumGasPrice,
        uint32 _reasonableGasPrice,
        uint32 _microPortPerEth,
        uint32 _portGweiPerObservation,
        uint32 _portGweiPerTransmission,
        address _port,
        AccessControllerInterface _billingAccessController,
        AccessControllerInterface _requesterAccessController,
        uint8 _decimals,
        string memory _description
    )
        OffchainAggregatorBilling(
            _maximumGasPrice,
            _reasonableGasPrice,
            _microPortPerEth,
            _portGweiPerObservation,
            _portGweiPerTransmission,
            _port,
            _billingAccessController
        )
    {
        decimals = _decimals;
        s_description = _description;
        setRequesterAccessController(_requesterAccessController);
    }

    event ConfigSet(
        uint32 previousConfigBlockNumber,
        uint64 configCount,
        address[] signers,
        address[] transmitters,
        uint64 encodedConfigVersion,
        bytes encoded
    );

    modifier checkConfigValid(uint256 _numSigners, uint256 _numTransmitters) {
        require(_numSigners <= maxNumOracles, "too many signers");
        require(
            _numSigners == _numTransmitters,
            "oracle addresses out of registration"
        );
        _;
    }

    function setConfig(
        address[] calldata _signers,
        address[] calldata _transmitters,
        uint64 _encodedConfigVersion,
        bytes calldata _encoded
    )
        external
        checkConfigValid(_signers.length, _transmitters.length)
        onlyOwner()
    {
        while (s_signers.length != 0) {
            uint256 lastIdx = s_signers.length - 1;
            address signer = s_signers[lastIdx];
            address transmitter = s_transmitters[lastIdx];
            payOracle(transmitter);
            delete s_oracles[signer];
            delete s_oracles[transmitter];
            s_signers.pop();
            s_transmitters.pop();
        }

        for (uint256 i = 0; i < _signers.length; i++) {
            require(
                s_oracles[_signers[i]].role == Role.Unset,
                "repeated signer address"
            );
            s_oracles[_signers[i]] = Oracle(uint8(i), Role.Signer);
            require(
                s_payees[_transmitters[i]] != address(0),
                "payee must be set"
            );
            require(
                s_oracles[_transmitters[i]].role == Role.Unset,
                "repeated transmitter address"
            );
            s_oracles[_transmitters[i]] = Oracle(uint8(i), Role.Transmitter);
            s_signers.push(_signers[i]);
            s_transmitters.push(_transmitters[i]);
        }
        uint32 previousConfigBlockNumber = s_latestConfigBlockNumber;
        s_latestConfigBlockNumber = uint32(block.number);
        s_configCount += 1;
        uint64 configCount = s_configCount;
        {
            s_hotVars.latestConfigDigest = configDigestFromConfigData(
                address(this),
                configCount,
                _signers,
                _transmitters,
                _encodedConfigVersion,
                _encoded
            );
        }
        emit ConfigSet(
            previousConfigBlockNumber,
            configCount,
            _signers,
            _transmitters,
            _encodedConfigVersion,
            _encoded
        );
    }

    function configDigestFromConfigData(
        address _contractAddress,
        uint64 _configCount,
        address[] calldata _signers,
        address[] calldata _transmitters,
        uint64 _encodedConfigVersion,
        bytes calldata _encodedConfig
    ) internal pure returns (bytes16) {
        return
            bytes16(
                keccak256(
                    abi.encode(
                        _contractAddress,
                        _configCount,
                        _signers,
                        _transmitters,
                        _encodedConfigVersion,
                        _encodedConfig
                    )
                )
            );
    }

    function latestConfigDetails()
        external
        view
        returns (
            uint32 configCount,
            uint32 blockNumber,
            bytes16 configDigest
        )
    {
        return (
            s_configCount,
            s_latestConfigBlockNumber,
            s_hotVars.latestConfigDigest
        );
    }


    function transmitters() external view returns (address[] memory) {
        return s_transmitters;
    }

    AccessControllerInterface internal s_requesterAccessController;

    event RequesterAccessControllerSet(
        AccessControllerInterface old,
        AccessControllerInterface current
    );

    event RoundRequested(
        address indexed requester,
        bytes16 configDigest,
        uint64 roundId
    );

    function requesterAccessController()
        external
        view
        returns (AccessControllerInterface)
    {
        return s_requesterAccessController;
    }

    function setRequesterAccessController(
        AccessControllerInterface _requesterAccessController
    ) public onlyOwner() {
        AccessControllerInterface oldController = s_requesterAccessController;
        if (_requesterAccessController != oldController) {
            s_requesterAccessController = AccessControllerInterface(
                _requesterAccessController
            );
            emit RequesterAccessControllerSet(
                oldController,
                _requesterAccessController
            );
        }
    }

    function requestNewRound() external returns (uint80) {
        require(
            msg.sender == owner ||
                s_requesterAccessController.hasAccess(msg.sender, msg.data),
            "Only owner&requester can call"
        );

        HotVars memory hotVars = s_hotVars;

        emit RoundRequested(
            msg.sender,
            hotVars.latestConfigDigest,
            hotVars.latestRoundId
        );
        return hotVars.latestRoundId + 1;
    }

    event NewTransmission(
        uint64 indexed roundId,
        bytes32[] answer,
        address transmitter,
        bytes observers,
        bytes32 rawReportContext
    );

    function decodeReport(bytes memory _report)
        internal
        pure
        returns (
            bytes32 rawReportContext,
            bytes32 rawObservers,
            bytes32 observersCount,
            bytes32 observation,
            bytes32 observationIndex,
            bytes32 observationLength,
            bytes32[] memory multipleObservation
        )
    {
        (
            rawReportContext,
            rawObservers,
            observersCount,
            observation,
            observationIndex,
            observationLength,
            multipleObservation
        ) = abi.decode(
            _report,
            (bytes32, bytes32, bytes32, bytes32, bytes32, bytes32, bytes32[])
        );
    }

    struct ReportData {
        HotVars hotVars;
        bytes observers;
        bytes observersCount;
        bytes32[] observation;
        bytes vs;
        bytes32 rawReportContext;
    }

    function latestTransmissionDetails()
        external
        view
        returns (
            bytes16 configDigest,
            uint64 latestRoundId,
            bytes32[] memory latestAnswer,
            uint8 validBytes,
            bytes32 multipleObservationsIndex,
            bytes32 multipleObservationsValidBytes,
            bytes32[] memory multipleObservations,
            uint64 latestTimestamp
        )
    {
        require(msg.sender == tx.origin, "Only callable by EOA");
        Transmission memory transmission =
            s_transmissions[s_hotVars.latestRoundId];
        return (
            s_hotVars.latestConfigDigest,
            s_hotVars.latestRoundId,
            transmission.answer,
            transmission.validBytes,
            transmission.multipleObservationsIndex,
            transmission.multipleObservationsValidBytes,
            transmission.multipleObservations,
            transmission.timestamp
        );
    }

    uint16 private constant TRANSMIT_MSGDATA_CONSTANT_LENGTH_COMPONENT =
        4 + // function selector
            32 + // _report value
            32 + // _rs value
            32 + // _ss value
            32 + // _rawVs value
            32 + // length of _report
            32 + // length _rs
            32 + // length of _ss
            0; // placeholder

    function expectedMsgDataLength(
        bytes calldata _report,
        bytes32[] calldata _rs,
        bytes32[] calldata _ss
    ) private pure returns (uint256 length) {
        return
            uint256(TRANSMIT_MSGDATA_CONSTANT_LENGTH_COMPONENT) +
            _report.length +
            _rs.length *
            32 +
            _ss.length *
            32 + 
            0;
    }

    function transmit(
        bytes calldata _report,
        bytes32[] calldata _rs,
        bytes32[] calldata _ss,
        bytes32 _rawVs // signatures
    ) external {
        uint256 initialGas = gasleft();
        require(
            msg.data.length == expectedMsgDataLength(_report, _rs, _ss),
            "transmit message too long"
        );
        uint64 roundId;
        ReportData memory r;
        {
            r.hotVars = s_hotVars;

            bytes32 rawObservers;
            bytes32 observersCount;
            bytes32 observationIndex;
            bytes32 observationLength;
            bytes32[] memory multipleObservation;
            (
                r.rawReportContext,
                rawObservers,
                observersCount,
                r.observation,
                observationIndex,
                observationLength,
                multipleObservation
            ) = abi.decode(
                _report,
                (
                    bytes32,
                    bytes32,
                    bytes32,
                    bytes32[],
                    bytes32,
                    bytes32,
                    bytes32[]
                )
            );

            // rawReportContext consists of:
            // 6-byte zero padding
            // 16-byte configDigest
            // 8-byte round id
            // 1-byte observer count
            // 1-byte valid byte count (answer)

            bytes16 configDigest = bytes16(r.rawReportContext << 48);
            require(
                r.hotVars.latestConfigDigest == configDigest,
                "configDigest mismatch"
            );

            roundId = uint64(bytes8(r.rawReportContext << 176));
            require(
                s_transmissions[roundId].timestamp == 0,
                "data has been transmitted"
            );

            uint8 observerCount = uint8(bytes1(r.rawReportContext << 240));
            s_transmissions[roundId] = Transmission(
                r.observation,
                uint64(block.timestamp),
                uint8(uint256(r.rawReportContext)),
                observationIndex,
                observationLength,
                multipleObservation
            );
            require(_rs.length <= maxNumOracles, "too many signatures");
            require(_ss.length == _rs.length, "signatures out of registration");

            r.vs = new bytes(_rs.length);
            for (uint8 i = 0; i < _rs.length; i++) {
                r.vs[i] = _rawVs[i];
            }

            r.observers = new bytes(observerCount);
            r.observersCount = new bytes(observerCount);
            bool[maxNumOracles] memory seen;
            for (uint8 i = 0; i < observerCount; i++) {
                uint8 observerIdx = uint8(rawObservers[i]);
                require(!seen[observerIdx], "observer index repeated");
                seen[observerIdx] = true;
                r.observers[i] = rawObservers[i];
                r.observersCount[i] = observersCount[i];
            }

            Oracle memory transmitter = s_oracles[msg.sender];
            require(
                transmitter.role == Role.Transmitter &&
                    msg.sender == s_transmitters[transmitter.index],
                "unauthorized transmitter"
            );
        }

        {
            bytes32 h = keccak256(_report);
            bool[maxNumOracles] memory signed;

            Oracle memory o;
            for (uint256 i = 0; i < _rs.length; i++) {
                address signer =
                    ecrecover(h, uint8(r.vs[i]) + 27, _rs[i], _ss[i]);
                o = s_oracles[signer];
                require(
                    o.role == Role.Signer,
                    "address not authorized to sign"
                );
                require(!signed[o.index], "non-unique signature");
                signed[o.index] = true;
            }
        }

        {
            if (roundId > r.hotVars.latestRoundId) {
                r.hotVars.latestRoundId = roundId;
            }
            emit NewTransmission(
                r.hotVars.latestRoundId,
                r.observation,
                msg.sender,
                r.observers,
                r.rawReportContext
            );
            emit NewRound(
                r.hotVars.latestRoundId,
                address(0x0),
                block.timestamp
            );
            emit AnswerUpdated(
                r.observation,
                r.hotVars.latestRoundId,
                block.timestamp,
                uint8(uint256(r.rawReportContext))
            );
        }
        s_hotVars = r.hotVars;
        assert(initialGas < maxUint32); // ？
        reimburseAndRewardOracles(
            uint32(initialGas),
            r.observers,
            r.observersCount
        );
    }

    function latestAnswer()
        public
        view
        virtual
        override
        returns (
            bytes32[] memory,
            uint8,
            bytes32,
            bytes32,
            bytes32[] memory
        )
    {
        return (
            s_transmissions[s_hotVars.latestRoundId].answer,
            s_transmissions[s_hotVars.latestRoundId].validBytes,
            s_transmissions[s_hotVars.latestRoundId].multipleObservationsIndex,
            s_transmissions[s_hotVars.latestRoundId]
                .multipleObservationsValidBytes,
            s_transmissions[s_hotVars.latestRoundId].multipleObservations
        );
    }

    function latestTimestamp() public view virtual override returns (uint256) {
        return s_transmissions[s_hotVars.latestRoundId].timestamp;
    }

    function latestRound() public view virtual override returns (uint256) {
        return s_hotVars.latestRoundId;
    }

    function getAnswer(uint256 _roundId)
        public
        view
        virtual
        override
        returns (
            bytes32[] memory,
            uint8,
            bytes32,
            bytes32,
            bytes32[] memory
        )
    {
        if (_roundId > 0xFFFFFFFF) {
            return (new bytes32[](0), 0, 0, 0, new bytes32[](0));
        }
        return (
            s_transmissions[uint32(_roundId)].answer,
            s_transmissions[uint32(_roundId)].validBytes,
            s_transmissions[uint32(_roundId)].multipleObservationsIndex,
            s_transmissions[uint32(_roundId)].multipleObservationsValidBytes,
            s_transmissions[uint32(_roundId)].multipleObservations
        );
    }

    function getTimestamp(uint256 _roundId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (_roundId > 0xFFFFFFFF) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].timestamp;
    }

    string private constant V3_NO_DATA_ERROR = "No data present";

    uint8 public immutable override decimals;

    uint256 public constant override version = 4;

    string internal s_description;

    function description()
        public
        view
        virtual
        override
        returns (string memory)
    {
        return s_description;
    }

    function getRoundData(uint80 _roundId)
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            bytes32[] memory answer,
            uint8 validBytes,
            bytes32 multipleObservationsIndex,
            bytes32 multipleObservationsValidBytes,
            bytes32[] memory multipleObservations,
            uint256 updatedAt
        )
    {
        require(_roundId <= 0xFFFFFFFF, V3_NO_DATA_ERROR);
        Transmission memory transmission = s_transmissions[uint32(_roundId)];
        return (
            _roundId,
            transmission.answer,
            transmission.validBytes,
            transmission.multipleObservationsIndex,
            transmission.multipleObservationsValidBytes,
            transmission.multipleObservations,
            transmission.timestamp
        );
    }

    function latestRoundData()
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            bytes32[] memory answer,
            uint8 validBytes,
            bytes32 multipleObservationsIndex,
            bytes32 multipleObservationsValidBytes,
            bytes32[] memory multipleObservations,
            uint256 updatedAt
        )
    {
        roundId = s_hotVars.latestRoundId;
        Transmission memory transmission = s_transmissions[uint32(roundId)];
        return (
            roundId,
            transmission.answer,
            transmission.validBytes,
            transmission.multipleObservationsIndex,
            transmission.multipleObservationsValidBytes,
            transmission.multipleObservations,
            transmission.timestamp
        );
    }
}
