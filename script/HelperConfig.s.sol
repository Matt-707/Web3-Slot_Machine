// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 keyHash; // keyHash
        //uint256 interval, not really needed since we do not do perform upkeep
        uint32 callbackGasLimit;
        address vrfCoordinatorAddress;
        //we need the address of the link token contract such that we can do stuff like fund a subscription programatically
        address link;
        //we need the private key of the deployer of the contract as well and this will vary depending on the network
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            activeNetworkConfig = getSepoliaEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaEthConfig)
    {
        sepoliaEthConfig = NetworkConfig({
            subscriptionId: 34822240334097551737639675815305553540437760888101600684406637117121216929003,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 150000,
            vrfCoordinatorAddress: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("PRIVATE_KEY_ACC1")
        });
        //the variable was declared in the returns stattement so I so not have to manually return it down here
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //we check to see if the vrfcoordinator is already deployed and stuff on our anvil chain
        if (activeNetworkConfig.vrfCoordinatorAddress != address(0)) {
            return activeNetworkConfig;
        } else {
            /*if not then we have to go through the struggle of deploying it on our own AND WE HAVE TO DEPLOY THE LINK TOKEN CONTRACT
        ON OUR FAKE ANVIL BLOCKCHAIN WHICH IS A BIT OF A HUSTLE*/

            //deployment of a mock vrf coordinator on the anvil chain

            uint96 BASE_FEE = 100000000000000000;
            uint96 GAS_PRICE_LINK = 1000000000;
            int256 WEI_PER_UINT_LINK = 4432440000000000;

            vm.startBroadcast(DEFAULT_ANVIL_PRIVATE_KEY);
            VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
                    BASE_FEE,
                    GAS_PRICE_LINK,
                    WEI_PER_UINT_LINK
                );
            LinkToken linkToken = new LinkToken();

            vm.stopBroadcast();

            //this is the private key of the default(first) anvil account

            //finally this the the anvil eth configuration that we return
            NetworkConfig memory anvilEthConfig = NetworkConfig({
                subscriptionId: 0,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 300000,
                vrfCoordinatorAddress: address(vrfCoordinatorMock),
                link: address(linkToken),
                deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
            });
            return anvilEthConfig;
        }
    }
}
