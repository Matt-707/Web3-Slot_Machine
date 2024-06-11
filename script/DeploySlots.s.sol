// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Slots} from "../src/Slots.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeploySlots is Script {
    function run() external returns (Slots, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 subscriptionId,
            bytes32 keyHash,
            uint32 callbackGasLimit,
            address vrfCoordinatorAddress,
            //we need the address of the link token contract such that we can do stuff like fund a subscription programatically
            address link,
            //we need the private key of the deployer of the contract as well and this will vary depending on the network
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        /* if we have not created a subscription, funded it and also added this solts contract as 
        a consumer, we need to do so. This is particularly manditory when on a local chain on 
        which the interface is not present and therefore we need to figure out a way to create 
        the subscription programatically and get it to function on our local chain....cool.*/

        if (subscriptionId == 0) {
            //we create the subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (uint256 new_subId, ) = createSubscription.createSubscription(
                vrfCoordinatorAddress,
                deployerKey
            );
            subscriptionId = new_subId;

            //we also fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                subscriptionId,
                vrfCoordinatorAddress,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Slots slots = new Slots{value: 0.5 ether}(
            subscriptionId,
            keyHash,
            callbackGasLimit,
            vrfCoordinatorAddress
        );
        vm.stopBroadcast();

        //there is already a broadcast call in the add cunsumer function itself so we do not need another one
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            subscriptionId,
            vrfCoordinatorAddress,
            deployerKey,
            address(slots)
        );

        return (slots, helperConfig);
    }
}
