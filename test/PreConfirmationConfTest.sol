// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";


import {PreConfCommitmentStore} from "../contracts/PreConfirmations.sol";
import "../contracts/ProviderRegistry.sol";
import "../contracts/BidderRegistry.sol";

contract TestPreConfCommitmentStore is Test {

    struct TestCommitment {
        uint64 bid;
        uint64 blockNumber;
        string txnHash;
        uint64 decayStartTimestamp;
        uint64 decayEndTimestamp;
        bytes32 bidDigest;
        bytes32 commitmentDigest;
        bytes bidSignature;
        bytes commitmentSignature;
    }

    TestCommitment internal _testCommitmentAliceBob;
    PreConfCommitmentStore internal preConfCommitmentStore;
    uint16 internal feePercent;
    uint256 internal minStake;
    address internal provider;
    address internal feeRecipient;
    ProviderRegistry internal providerRegistry;
    uint256 testNumber;
    uint64 testNumber2;

    BidderRegistry internal bidderRegistry;

    function setUp() public {
        testNumber = 2;
        testNumber2 = 2;
        _testCommitmentAliceBob = TestCommitment(
            2,
            2,
            "0xkartik",
            10,
            20,
            0xa0327970258c49b922969af74d60299a648c50f69a2d98d6ab43f32f64ac2100,
            0x54c118e537dd7cf63b5388a5fc8322f0286a978265d0338b108a8ca9d155dccc,
            hex"876c1216c232828be9fabb14981c8788cebdf6ed66e563c4a2ccc82a577d052543207aeeb158a32d8977736797ae250c63ef69a82cd85b727da21e20d030fb311b",
            hex"ec0f11f77a9e96bb9c2345f031a5d12dca8d01de8a2e957cf635be14802f9ad01c6183688f0c2672639e90cc2dce0662d9bea3337306ca7d4b56dd80326aaa231b"
        );

        feePercent = 10;
        minStake = 1e18 wei;
        feeRecipient = vm.addr(9);
        providerRegistry = new ProviderRegistry(
            minStake,
            feeRecipient,
            feePercent,
            address(this)
        );

        bidderRegistry = new BidderRegistry(minStake, feeRecipient, feePercent, address(this));

        preConfCommitmentStore = new PreConfCommitmentStore(
            address(providerRegistry), // Provider Registry
            address(bidderRegistry), // User Registry
            feeRecipient, // Oracle
            address(this) // Owner
        );

        bidderRegistry.setPreconfirmationsContract(address(preConfCommitmentStore));
    }

    function test_Initialize() public {
        assertEq(preConfCommitmentStore.oracle(), feeRecipient);
        assertEq(
            address(preConfCommitmentStore.providerRegistry()),
            address(providerRegistry)
        );
        assertEq(
            address(preConfCommitmentStore.bidderRegistry()),
            address(bidderRegistry)
        );
    }

    function test_CreateCommitment() public {
        bytes32 bidHash = preConfCommitmentStore.getBidHash(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp
        );
        (address bidder, uint256 bidderPk) = makeAddrAndKey("alice");
        // Wallet memory kartik = vm.createWallet('test wallet');
        (uint8 v,bytes32 r, bytes32 s) = vm.sign(bidderPk, bidHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(bidder, 200000 ether);
        vm.prank(bidder);
        bidderRegistry.prepay{value: 1e18 wei}();
        console.logAddress(bidder);
        (bytes32 digest, address recoveredAddress, uint256 stake) =  preConfCommitmentStore.verifyBid(
            _testCommitmentAliceBob.bid, 
            _testCommitmentAliceBob.blockNumber, 
            _testCommitmentAliceBob.decayStartTimestamp, 
            _testCommitmentAliceBob.decayEndTimestamp, 
            _testCommitmentAliceBob.txnHash, 
            signature);
        
        assertEq(stake, 1e18 wei);
        assertEq(bidder, recoveredAddress);
        assertEq(digest, bidHash);

        preConfCommitmentStore.storeCommitment(
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            signature,
            _testCommitmentAliceBob.commitmentSignature
        );

    }

    function test_UpdateOracle() public {
        preConfCommitmentStore.updateOracle(feeRecipient);
        assertEq(preConfCommitmentStore.oracle(), feeRecipient);
    }

    function test_UpdateProviderRegistry() public {
        preConfCommitmentStore.updateProviderRegistry(feeRecipient);
        assertEq(
            address(preConfCommitmentStore.providerRegistry()),
            feeRecipient
        );
    }

    function test_UpdateBidderRegistry() public {
        preConfCommitmentStore.updateBidderRegistry(feeRecipient);
        assertEq(address(preConfCommitmentStore.bidderRegistry()), feeRecipient);
    }

    function test_GetBidHash() public {
        string memory txnhash = "0xkartik";

        bytes32 bidHash = preConfCommitmentStore.getBidHash(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp
        );
        assertEq(
            bidHash,
            _testCommitmentAliceBob.bidDigest
        );
    }

    function test_GetCommitmentDigest() public {
        (address bidder, uint256 bidderPk) = makeAddrAndKey("alice");


        bytes32 bidHash = preConfCommitmentStore.getBidHash(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp
        );

        (uint8 v,bytes32 r, bytes32 s) = vm.sign(bidderPk, bidHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        console.logString(_bytesToHexString(signature));

        bytes32 preConfHash = preConfCommitmentStore.getPreConfHash(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            bidHash,
            _bytesToHexString(signature)
        );
        assertEq(
            preConfHash,
            _testCommitmentAliceBob.commitmentDigest
        );
    }


    function _bytes32ToHexString(
        bytes32 _bytes32
    ) internal pure returns (string memory) {
        bytes memory HEXCHARS = "0123456789abcdef";
        bytes memory _string = new bytes(64);
        for (uint8 i = 0; i < 32; i++) {
            _string[i * 2] = HEXCHARS[uint8(_bytes32[i] >> 4)];
            _string[1 + i * 2] = HEXCHARS[uint8(_bytes32[i] & 0x0f)];
        }
        return string(_string);
    }

    function test_StoreCommitment() public {
        (address bidder, ) = makeAddrAndKey("alice");
        vm.deal(bidder, 5 ether);
        vm.prank(bidder);
        bidderRegistry.prepay{value: 2 ether}();
        
        // Step 1: Verify that the commitment has not been used before
        verifyCommitmentNotUsed(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            _testCommitmentAliceBob.bidSignature
        );

        // Step 2: Store the commitment
        bytes32 index = storeCommitment(
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            _testCommitmentAliceBob.bidSignature,
            _testCommitmentAliceBob.commitmentSignature
        );

        // Step 3: Verify the stored commitment
        verifyStoredCommitment(
            index,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bidSignature,
            _testCommitmentAliceBob.commitmentSignature
        );

        string memory commitmentTxnHash = preConfCommitmentStore.getTxnHashFromCommitment(index);
        assertEq(commitmentTxnHash, _testCommitmentAliceBob.txnHash);
    }

    function verifyCommitmentNotUsed(
        string memory txnHash,
        uint64 bid,
        uint64 blockNumber,
        uint64 decayStartTimestamp,
        uint64 decayEndTimestamp,
        bytes memory bidSignature
    ) public returns (bytes32) {
        bytes32 bidHash = preConfCommitmentStore.getBidHash(
            txnHash,
            bid,
            blockNumber,
            decayStartTimestamp,
            decayEndTimestamp
        );
        bytes32 preConfHash = preConfCommitmentStore.getPreConfHash(
            txnHash,
            bid,
            blockNumber,
            decayStartTimestamp,
            decayEndTimestamp,
            bidHash,
            _bytesToHexString(bidSignature)
        );

        (bool commitmentUsed, , , , , , , , , , , ) = preConfCommitmentStore
            .commitments(preConfHash);
        assertEq(commitmentUsed, false);

        return bidHash;
    }

    function storeCommitment(
        uint64 bid,
        uint64 blockNumber,
        string memory txnHash,
        uint64 decayStartTimestamp,
        uint64 decayEndTimestamp,
        bytes memory bidSignature,
        bytes memory commitmentSignature
    ) internal returns (bytes32) {
        bytes32 commitmentIndex = preConfCommitmentStore.storeCommitment(
            bid,
            blockNumber,
            txnHash,
            decayStartTimestamp,
            decayEndTimestamp,
            bidSignature,
            commitmentSignature
        );

        return commitmentIndex;
    }

    function verifyStoredCommitment(
        bytes32 index,
        uint64 bid,
        uint64 blockNumber,
        uint64 decayStartTimestamp,
        uint64 decayEndTimestamp,
        string memory txnHash,
        bytes memory bidSignature,
        bytes memory commitmentSignature
    ) public {


        (PreConfCommitmentStore.PreConfCommitment memory commitment) = preConfCommitmentStore
            .getCommitment(index);

        (, address commiterAddress) = preConfCommitmentStore.verifyPreConfCommitment(
            txnHash,
            bid,
            blockNumber,
            decayStartTimestamp,
            decayEndTimestamp,
            commitment.bidHash,
            bidSignature,
            commitmentSignature
        );

        bytes32[] memory commitments = preConfCommitmentStore.getCommitmentsByCommitter(commiterAddress);
        
        assert(commitments.length >= 1);

        assertEq(
            commitment.commitmentUsed,
            false,
            "Commitment should have been marked as used"
        );
        assertEq(commitment.bid, bid, "Stored bid should match input bid");
        assertEq(
            commitment.blockNumber,
            blockNumber,
            "Stored blockNumber should match input blockNumber"
        );
        assertEq(
            commitment.txnHash,
            txnHash,
            "Stored txnHash should match input txnHash"
        );
        assertEq(
            commitment.bidSignature,
            bidSignature,
            "Stored bidSignature should match input bidSignature"
        );
        assertEq(
            commitment.commitmentSignature,
            commitmentSignature,
            "Stored commitmentSignature should match input commitmentSignature"
        );
    }

    function test_GetCommitment() public {
        (address bidder, ) = makeAddrAndKey("alice");
        vm.deal(bidder, 5 ether);
        vm.prank(bidder);
        bidderRegistry.prepay{value: 2 ether}();
        // Step 1: Verify that the commitment has not been used before
        verifyCommitmentNotUsed(
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            _testCommitmentAliceBob.bidSignature
        );
        // Step 2: Store the commitment
        bytes32 commitmentIndex = storeCommitment(
            _testCommitmentAliceBob.bid,
            _testCommitmentAliceBob.blockNumber,
            _testCommitmentAliceBob.txnHash,
            _testCommitmentAliceBob.decayStartTimestamp,
            _testCommitmentAliceBob.decayEndTimestamp,
            _testCommitmentAliceBob.bidSignature,
            _testCommitmentAliceBob.commitmentSignature
        );
        PreConfCommitmentStore.PreConfCommitment
            memory storedCommitment = preConfCommitmentStore.getCommitment(
                commitmentIndex
            );
        
        assertEq(storedCommitment.bid, _testCommitmentAliceBob.bid);
        assertEq(storedCommitment.blockNumber, _testCommitmentAliceBob.blockNumber);
        assertEq(storedCommitment.txnHash, _testCommitmentAliceBob.txnHash);
        assertEq(storedCommitment.bidSignature, _testCommitmentAliceBob.bidSignature);
        assertEq(storedCommitment.commitmentSignature, _testCommitmentAliceBob.commitmentSignature);
        assertEq(storedCommitment.decayEndTimeStamp, _testCommitmentAliceBob.decayEndTimestamp);
        assertEq(storedCommitment.decayStartTimeStamp, _testCommitmentAliceBob.decayStartTimestamp);
    }

    // function test_InitiateSlash() public {
    //     // Assuming you have a stored commitment
    //     {
    //         address signer = 0x6d503Fd50142C7C469C7c6B64794B55bfa6883f3;
    //         vm.deal(signer, 5 ether);
    //         vm.prank(signer);
    //         bidderRegistry.prepay{value: 2 ether}();
    //         string memory txnHash = "0xkartik";
    //         bytes
    //             memory signature = "0xb170d082db1bf77fa0b589b9438444010dcb1e6dd326b661b02eb92abe4c066e243bb0d214b01667750ba2c53ff1ab445fd784b441dbc1f30280c379f002cc571c";
    //         uint64 bid = 2;
    //         uint64 blockNumber = 2;
    //         bytes memory bidSignature = bytes(
    //             hex"c10688ea554c1dae605619fa7f75103fb483ab6b5ad424e4e232f5da4449503a27ef6aed49b85bfd0e598650831c861a55a5eb197d9279d6a5667efaa46ab8831c"
    //         );
    //         address commiter = 0xE3E9cc6677B1b7f05C483168bf25B4D9604c6763;
    //         bytes
    //             memory commitmentSignature = hex"306eb646b8882c8cd918d4aff61cbf6814a152becbc84b52abb4aad963dbaa2465c0c27837b5f8c943cb1c523f54961c0c8775c48d9dbf7ae9883b14925794941c";

    //         // Step 1: Verify that the commitment has not been used before
    //         bytes32 bidHash = verifyCommitmentNotUsed(
    //             txnHash,
    //             bid,
    //             blockNumber,
    //             signature
    //         );

    //         bytes32 preConfHash = preConfCommitmentStore.getPreConfHash(
    //             txnHash,
    //             bid,
    //             blockNumber,
    //             bidHash,
    //             _bytesToHexString(bidSignature)
    //         );

    //         // Verify that the commitment has not been used before
    //         (bool commitmentUsed, , , , , , , , , ) = preConfCommitmentStore
    //             .commitments(preConfHash);
    //         assert(commitmentUsed == false);
    //         bytes32 index = preConfCommitmentStore.storeCommitment(
    //             bid,
    //             blockNumber,
    //             txnHash,
    //             bidSignature,
    //             commitmentSignature
    //         );
    //         providerRegistry.setPreconfirmationsContract(
    //             address(preConfCommitmentStore)
    //         );

    //         vm.deal(commiter, 5 ether);
    //         vm.prank(commiter);
    //         providerRegistry.registerAndStake{value: 4 ether}();
    //         vm.prank(feeRecipient);
    //         preConfCommitmentStore.initiateSlash(index);

    //         (commitmentUsed, , , , , , , , , ) = preConfCommitmentStore
    //             .commitments(index);
    //         // Verify that the commitment has been marked as used
    //         assert(commitmentUsed == true);
    //     }
    //     // commitmentHash value is internal to contract and not asserted
    // }

    function test_alice() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("bob");
        console.logAddress(alice);
        console.logUint(alicePk);
    }
    // function test_InitiateReward() public {
    //     // Assuming you have a stored commitment
    //     {
    //         address signer = 0x6d503Fd50142C7C469C7c6B64794B55bfa6883f3;
    //         vm.deal(signer, 5 ether);
    //         vm.prank(signer);
    //         bidderRegistry.prepay{value: 2 ether}();
    //         string memory txnHash = "0xkartik";
    //         bytes
    //             memory signature = "0xb170d082db1bf77fa0b589b9438444010dcb1e6dd326b661b02eb92abe4c066e243bb0d214b01667750ba2c53ff1ab445fd784b441dbc1f30280c379f002cc571c";
    //         uint64 bid = 2;
    //         uint64 blockNumber = 2;
    //         bytes memory bidSignature = bytes(
    //             hex"c10688ea554c1dae605619fa7f75103fb483ab6b5ad424e4e232f5da4449503a27ef6aed49b85bfd0e598650831c861a55a5eb197d9279d6a5667efaa46ab8831c"
    //         );
    //         address commiter = 0xE3E9cc6677B1b7f05C483168bf25B4D9604c6763;
    //         bytes
    //             memory commitmentSignature = hex"306eb646b8882c8cd918d4aff61cbf6814a152becbc84b52abb4aad963dbaa2465c0c27837b5f8c943cb1c523f54961c0c8775c48d9dbf7ae9883b14925794941c";

    //         // Step 1: Verify that the commitment has not been used before
    //         bytes32 bidHash = verifyCommitmentNotUsed(
    //             txnHash,
    //             bid,
    //             blockNumber,
    //             signature
    //         );

    //         bytes32 preConfHash = preConfCommitmentStore.getPreConfHash(
    //             txnHash,
    //             bid,
    //             blockNumber,
    //             bidHash,
    //             _bytesToHexString(bidSignature)
    //         );

    //         // Verify that the commitment has not been used before
    //         (bool commitmentUsed, , , , , , , , , ) = preConfCommitmentStore
    //             .commitments(preConfHash);
    //         assert(commitmentUsed == false);
    //         bytes32 index = preConfCommitmentStore.storeCommitment(
    //             bid,
    //             blockNumber,
    //             txnHash,
    //             bidSignature,
    //             commitmentSignature
    //         );

    //         vm.deal(commiter, 5 ether);
    //         vm.prank(commiter);
    //         providerRegistry.registerAndStake{value: 4 ether}();
    //         vm.prank(feeRecipient);
    //         preConfCommitmentStore.initateReward(index);

    //         (commitmentUsed, , , , , , , , , ) = preConfCommitmentStore
    //             .commitments(index);
    //         // Verify that the commitment has been marked as used
    //         assert(commitmentUsed == true);
    //         // commitmentHash value is internal to contract and not asserted
    //     }
    // }

    function _bytesToHexString(
        bytes memory _bytes
    ) public pure returns (string memory) {
        bytes memory HEXCHARS = "0123456789abcdef";
        bytes memory _string = new bytes(_bytes.length * 2);
        for (uint256 i = 0; i < _bytes.length; i++) {
            _string[i * 2] = HEXCHARS[uint8(_bytes[i] >> 4)];
            _string[1 + i * 2] = HEXCHARS[uint8(_bytes[i] & 0x0f)];
        }
        return string(_string);
    }
}
