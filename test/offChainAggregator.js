const testContract = artifacts.require("AccessControlledOffchainAggregator");
const PortContract = artifacts.require("MockPortToken");

contract('master chef', (accounts) => {
    it('single one observation with byte length less than 32', async () => {
        const testInstance = await testContract.deployed();
        const portTokenInstance = await PortContract.deployed();
        let transmitterOne = accounts[0];
        let payeeOne = accounts[1];
        let transmitterTwo = accounts[3];
        let payeeTwo = accounts[4];

        let signerOneAddress = "0x824b3998700F7dcB7100D484c62a7b472B6894B6";  // generate on aelf
        //let signerOnePrivateKey = "7f6965ae260469425ae839f5abc85b504883022140d5f6fc9664a96d480c068d";
        let signerOneR = "0xf9695dc7083907c2ca96a8cee321f6750ad7e3f3908275e51e678550308445e5";
        let signerOneS = "0x70b43c2c78affcbbafa52e915b974fc95b305558475b747a97ac8b17714e8d89";
        let signerOneV = 0;

        let signerTwoAddress = "0x90aE559e07f46eebF91bD95DD28889ef60A1E87B";  // generated on aelf
        //let signerTwoPrivateKey = "996e00ecd273f49a96b1af85ee24b6724d8ba3d9957c5bdc5fc16fd1067d542a";
        let signerTwoR = "0xf940160691534e08a096d264facc20610db02561aabe2df400bf0c34f4181da3";
        let signerTwoS = "0x0420d475f59addfe0eb92e5b8c2d5d4837c20f698801d25f7d6d14e429b9729d";
        let signerTwoV = 1;

        let transmiters = [transmitterOne, transmitterTwo];
        let payees = [payeeOne, payeeTwo];
        let signers = [signerOneAddress, signerTwoAddress];

        let configVersion = 1;
        let encoded = "0x012df";

        await testInstance.setPayees(transmiters, payees);
        await testInstance.setConfig(signers, transmiters, configVersion, encoded);
        let config = await testInstance.latestConfigDetails();
        //console.log(config.configDigest);

        let report = "0x000000000000f6f3ed664fd0e7be332f035ec351acf1000000000000000a02050001020000000000000000000000000000000000000000000000000000000000000102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000161736461730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        let rs = [signerOneR, signerTwoR];
        let ss = [signerOneS, signerTwoS];
        let vs = web3.utils.bytesToHex([signerOneV, signerTwoV, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0]);
        await testInstance.transmit(report, rs, ss, vs);
        let latestAnswer = await testInstance.latestAnswer();
        assert.equal(latestAnswer['0'][0], "0x6173646173000000000000000000000000000000000000000000000000000000", "wrong latest answer");
        assert.equal(latestAnswer['1'].toString(), 5, "wrong latest answer length");
        let latestRound = await testInstance.latestRound();
        assert.equal(latestRound, 10, "wrong round id");

        let payeeOneBal = await portTokenInstance.balanceOf(payeeOne);
        assert.equal(payeeOneBal, 0, "before withrawing, balance should be 0");
        let owedPayment = await testInstance.owedPayment(transmitterOne);

        let depositAmount = '10000000000000000';
        await portTokenInstance.deposit(testContract.address, depositAmount);
        await testInstance.withdrawPayment(transmitterOne, {from: payeeOne});
        payeeOneBal = await portTokenInstance.balanceOf(payeeOne);
        assert.equal(payeeOneBal.toString(), owedPayment.toString(), "withdraw failed");
    });

    it('multiple observations with answer length less than 32', async () => {
        const testInstance = await testContract.deployed();
        let transmitterOne = accounts[0];
        let payeeOne = accounts[1];
        let transmitterTwo = accounts[3];
        let payeeTwo = accounts[4];

        let signerOneAddress = "0x824b3998700F7dcB7100D484c62a7b472B6894B6";  // generated on aelf
        //let signerOnePrivateKey = "7f6965ae260469425ae839f5abc85b504883022140d5f6fc9664a96d480c068d";
        let signerOneR = "0xa758ee2f20093d90001ab0b15b70146bee8944dd5a8617e0d897288e225128c2";
        let signerOneS = "0x455e4bb504e2d4cca922053de9bf412467dcf52368cb8bfa5601c960abf47309";
        let signerOneV = 1;


        let signerTwoAddress = "0x90aE559e07f46eebF91bD95DD28889ef60A1E87B";  // generated on aelf
        //let signerTwoPrivateKey = "996e00ecd273f49a96b1af85ee24b6724d8ba3d9957c5bdc5fc16fd1067d542a";
        let signerTwoR = "0x15308c81653f919a94d0cfab9805f693d4e847101f2d02e8c9211f599ffb2adf";
        let signerTwoS = "0x2b936d6ed5b67fc18c2a463de02d87a8bab4fcce553145dc9cb3a2e143d6b95f";
        let signerTwoV = 0;

        let transmiters = [transmitterOne, transmitterTwo];
        let payees = [payeeOne, payeeTwo];
        let signers = [signerOneAddress, signerTwoAddress];

        let configVersion = 1;
        let encoded = "0x012df";

        await testInstance.setPayees(transmiters, payees);
        await testInstance.setConfig(signers, transmiters, configVersion, encoded);
        let config = await testInstance.latestConfigDetails();
        //console.log(config.configDigest);

        let report = "0x00000000000022d6f8928689ea183a3eb24df3919a94000000000000000b02400001020000000000000000000000000000000000000000000000000000000000000102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000010200000000000000000000000000000000000000000000000000000000000a0b0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000026334326564656663373538373165346365323134366663646136376430336464613035636332366664663933623137623535663432633165616466646333323200000000000000000000000000000000000000000000000000000000000000037177656f6c657763776a000000000000000000000000000000000000000000006a756e61656c696f76656100000000000000000000000000000000000000000031323332313433322e3132333132330000000000000000000000000000000000";
        let rs = [signerOneR, signerTwoR];
        let ss = [signerOneS, signerTwoS];
        let vs = web3.utils.bytesToHex([signerOneV, signerTwoV, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0]);
        await testInstance.transmit(report, rs, ss, vs);
        let latestAnswer = await testInstance.latestAnswer();
        assert.equal(latestAnswer['0'][0], "0x6334326564656663373538373165346365323134366663646136376430336464", "wrong half latest answer");
        assert.equal(latestAnswer['0'][1], "0x6130356363323666646639336231376235356634326331656164666463333232", "wrong half latest answer");
        assert.equal(latestAnswer['1'], 64, "wrong latest answer length");
        assert.equal(latestAnswer['2'], "0x0001020000000000000000000000000000000000000000000000000000000000", "invalid observations's index");
        assert.equal(latestAnswer['3'], "0x0a0b0f0000000000000000000000000000000000000000000000000000000000", "observations's data valid bytes should all be 6");
        assert.equal(latestAnswer['4'].length, 3, "observations's count should be 3");
        assert.equal(latestAnswer['4'][0], "0x7177656f6c657763776a00000000000000000000000000000000000000000000", "invalid observation at index 0");
        assert.equal(latestAnswer['4'][1], "0x6a756e61656c696f766561000000000000000000000000000000000000000000", "invalid observation at index 1");
        assert.equal(latestAnswer['4'][2], "0x31323332313433322e3132333132330000000000000000000000000000000000", "invalid observation at index 2");       
        let latestRound = await testInstance.latestRound();
        assert.equal(latestRound, 11, "wrong round id");

        let transmitOneObservationCount = await testInstance.oracleObservationCount(transmitterOne);
        assert.equal(transmitOneObservationCount.toString(), 0, "transmitter one  with wrong observer cound");

        let transmitTwoObservationCount = await testInstance.oracleObservationCount(transmitterTwo);
        assert.equal(transmitTwoObservationCount.toString(), 1, "transmitter one  with wrong observer cound");
    });

    it('multiple observations with answer length greater than 32', async () => {
        const testInstance = await testContract.deployed();

        let signerOneAddress = "0x824b3998700F7dcB7100D484c62a7b472B6894B6";  // generated on aelf
        //let signerOnePrivateKey = "7f6965ae260469425ae839f5abc85b504883022140d5f6fc9664a96d480c068d";
        let signerOneR = "0x4528ce84aa2af6bd417290608454fb0292c0caf5f65b61309ba42b47dd7b7a9c";
        let signerOneS = "0x6c332d4ff2c55edbd44660290335d5e7c395eb782780e722924a9057bdca34a3";
        let signerOneV = 1;


        let signerTwoAddress = "0x90aE559e07f46eebF91bD95DD28889ef60A1E87B";  // generated on aelf
        //let signerTwoPrivateKey = "996e00ecd273f49a96b1af85ee24b6724d8ba3d9957c5bdc5fc16fd1067d542a";
        let signerTwoR = "0xb84081ff9ebeba8bfb109783434b5aebb981363de9c4e6fa8ef4f2889d5ce473";
        let signerTwoS = "0x28e9c1257191109e608b84d19472433d3faae2d8a252506b3e385d7ec4826d60";
        let signerTwoV = 1;

        let report = "0x00000000000022d6f8928689ea183a3eb24df3919a94000000000000000c02400001020000000000000000000000000000000000000000000000000000000000000102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000010203000000000000000000000000000000000000000000000000000000000a408089000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000263343265646566633735383731653463653231343666636461363764303364646130356363323666646639336231376235356634326331656164666463333232000000000000000000000000000000000000000000000000000000000000000c7177656f6c657763776a0000000000000000000000000000000000000000000063343265646566633735383731653463653231343666636461363764303364646130356363323666646639336231376235356634326331656164666463333232633432656465666337353837316534636532313436666364613637643033646461303563633236666466393362313762353566343263316561646664633332326334326564656663373538373165346365323134366663646136376430336464613035636332366664663933623137623535663432633165616466646333323263343265646566633735383731653463653231343666636461363764303364646130356363323666646639336231376235356634326331656164666463333232633432656465666337353837316534636532313436666364613637643033646461303563633236666466393362313762353566343263316561646664633332326164736461646164640000000000000000000000000000000000000000000000";
        let rs = [signerOneR, signerTwoR];
        let ss = [signerOneS, signerTwoS];
        let vs = web3.utils.bytesToHex([signerOneV, signerTwoV, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0]);
        await testInstance.transmit(report, rs, ss, vs);
        let latestAnswer = await testInstance.latestAnswer();
        assert.equal(latestAnswer['0'][0], "0x6334326564656663373538373165346365323134366663646136376430336464", "wrong half latest answer");
        assert.equal(latestAnswer['0'][1], "0x6130356363323666646639336231376235356634326331656164666463333232", "wrong half latest answer");
        assert.equal(latestAnswer['1'], 64, "wrong latest answer length");
        assert.equal(latestAnswer['2'], "0x0001020300000000000000000000000000000000000000000000000000000000", "invalid observations's index");
        assert.equal(latestAnswer['3'], "0x0a40808900000000000000000000000000000000000000000000000000000000", "observations's data valid bytes should all be 6");
        assert.equal(latestAnswer['4'].length, 12, "observations's count should be 12");
        assert.equal(latestAnswer['4'][0], "0x7177656f6c657763776a00000000000000000000000000000000000000000000", "invalid observation at index 0");
        assert.equal(latestAnswer['4'][1], "0x6334326564656663373538373165346365323134366663646136376430336464", "invalid observation at index 1");
        assert.equal(latestAnswer['4'][2], "0x6130356363323666646639336231376235356634326331656164666463333232", "invalid observation at index 2");
        assert.equal(latestAnswer['4'][3], "0x6334326564656663373538373165346365323134366663646136376430336464", "invalid observation at index 3");
        assert.equal(latestAnswer['4'][4], "0x6130356363323666646639336231376235356634326331656164666463333232", "invalid observation at index 4");
        assert.equal(latestAnswer['4'][5], "0x6334326564656663373538373165346365323134366663646136376430336464", "invalid observation at index 5");
        assert.equal(latestAnswer['4'][6], "0x6130356363323666646639336231376235356634326331656164666463333232", "invalid observation at index 6");
        assert.equal(latestAnswer['4'][7], "0x6334326564656663373538373165346365323134366663646136376430336464", "invalid observation at index 7");
        assert.equal(latestAnswer['4'][8], "0x6130356363323666646639336231376235356634326331656164666463333232", "invalid observation at index 8");
        assert.equal(latestAnswer['4'][9], "0x6334326564656663373538373165346365323134366663646136376430336464", "invalid observation at index 9");
        assert.equal(latestAnswer['4'][10], "0x6130356363323666646639336231376235356634326331656164666463333232", "invalid observation at index 10");
        assert.equal(latestAnswer['4'][11], "0x6164736461646164640000000000000000000000000000000000000000000000", "invalid observation at index 11");
    });

    it('configuration test', async () => {
        const testInstance = await testContract.deployed();
        const portTokenInstance = await PortContract.deployed();
        await testInstance.requestNewRound();
        let requestNewRoundEvent = (await testInstance.getPastEvents('RoundRequested'))[0].returnValues;
        assert.equal(requestNewRoundEvent.requester, accounts[0], "invalid requester info");
        assert.equal(requestNewRoundEvent.roundId, 12, "current round id should be 11");
        let transmitter = accounts[3];
        let owedPayment = await testInstance.owedPayment(transmitter);
        assert.equal(owedPayment > 0, true, "invalid owedPayment for transmitter two");
        await testInstance.setBilling(1000, 500, 400, 500, 800);
        let billingInfo = await testInstance.getBilling();
        assert.equal(billingInfo.maximumGasPrice, 1000, "wrong maximumGasPrice");
        assert.equal(billingInfo.reasonableGasPrice, 500, "wrong reasonableGasPrice");
        assert.equal(billingInfo.microPortPerEth, 400, "wrong microPortPerEth");
        assert.equal(billingInfo.portGweiPerObservation, 500, "wrong portGweiPerObservation");
        assert.equal(billingInfo.portGweiPerTransmission, 800, "wrong portGweiPerTransmission");
        owedPayment = await testInstance.owedPayment(transmitter);
        assert.equal(owedPayment == 0, true, "invalid owedPayment for transmitter two");
        let recipient = accounts[9];
        let portBal = await testInstance.portAvailableForPayment();
        let beforeBal = await portTokenInstance.balanceOf(recipient);
        assert.equal(beforeBal, 0, "recipient bal should be 0");
        await testInstance.withdrawFunds(recipient, portBal);
        let afterBal = await portTokenInstance.balanceOf(recipient);
        assert.equal(afterBal - beforeBal, portBal, "recipient bal should be avaliable port");
        let newPayeeForTransmitter = accounts[8];
        await testInstance.transferPayeeship(transmitter, newPayeeForTransmitter,{from: accounts[4]});
        let payeeshipTransferRequested = (await testInstance.getPastEvents('PayeeshipTransferRequested'))[0].returnValues;
        assert.equal(payeeshipTransferRequested.transmitter, transmitter, "wrong transmitter");
        assert.equal(payeeshipTransferRequested.current, accounts[4], "wrong transmitter");
        assert.equal(payeeshipTransferRequested.proposed, newPayeeForTransmitter, "wrong transmitter");
        await testInstance.acceptPayeeship(transmitter, {from: newPayeeForTransmitter});
        let payeeshipTransferred = (await testInstance.getPastEvents('PayeeshipTransferred'))[0].returnValues;
        assert.equal(payeeshipTransferred.current, newPayeeForTransmitter, "faile to update");
    });
});


