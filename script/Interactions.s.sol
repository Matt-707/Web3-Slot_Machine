// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

///////////////////////////
///CREATE SUBSCRIPTION///////
///////////////////////////

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            ,
            address vrfCoordinatorAddress,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorAddress, deployerKey);
    }

    function createSubscription(
        address vrfCoordinatorAddress,
        uint256 deployerKey
    ) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subId;
        try
            VRFCoordinatorV2_5Mock(vrfCoordinatorAddress).createSubscription()
        returns (uint256 _subId) {
            subId = _subId;
            console.log("SubscriptionCreated with subId: ", subId);
        } catch (bytes memory error) {
            console.log("Error getting subscription: ", string(error));
        }
        /*uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress)
            .createSubscription();*/
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorAddress);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

///////////////////////////
///FUND SUBSCRIPTION///////
///////////////////////////

contract FundSubscription is Script {
    uint256 FUND_AMOUNT = 100000000000000000000;

    function fundSubscription(
        uint256 subId,
        address vrfCoordinatorAddress,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorAddress);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2_5Mock(vrfCoordinatorAddress).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinatorAddress,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 subId,
            ,
            ,
            address vrfCoordinatorAddress,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        //create a subscription incase it does not exist yet for some reason

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (
                uint256 updatedSubId,
                address updatedVRFCoordinatorAddress
            ) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorAddress = updatedVRFCoordinatorAddress;
            console.log(
                "New SubId Created! ",
                subId,
                "VRF Address: ",
                vrfCoordinatorAddress
            );
        }

        fundSubscription(subId, vrfCoordinatorAddress, link, deployerKey);
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

///////////////////////////
///ADD CONSUMER////////////
///////////////////////////

contract AddConsumer is Script {
    function addConsumer(
        uint256 subId,
        address vrfCoordinatorAddress,
        uint256 deployerKey,
        address mostRecentlyDeployed
    ) public {
        console.log("Adding consumer contract: ", mostRecentlyDeployed);
        console.log("Using vrfCoordinator: ", vrfCoordinatorAddress);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2_5Mock(vrfCoordinatorAddress).addConsumer(
            subId,
            mostRecentlyDeployed
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 subId,
            ,
            ,
            address vrfCoordinatorAddress,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(
            subId,
            vrfCoordinatorAddress,
            deployerKey,
            mostRecentlyDeployed
        );
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Slots",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
