// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Slots is VRFConsumerBaseV2Plus {
    /**errors */
    error Slots__NotEnoughEthToPlay();
    error Slots__CalculatingResultPleaseWait();
    error Slots__ExitFailed();
    error Slots__YouAreAlreadyPlaying();
    error Slots__YouMustEnterFirst();
    error Slots__YouAreNotThePlayer();
    error Slots__YouAreNotTheOwner();
    error Slots__NotEnoughBalanceToWithdraw();
    error Slots__WithdrawFailed();
    error Slots__PleaseDeployMeWithEnoughEther();
    /**enums */
    enum SlotsState {
        OPEN,
        CALCULATING
    }

    enum SlotActivity {
        ACTIVE,
        INACTIVE
    }

    /**events */

    /**immutables */
    //address private immutable i_owner;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    address private immutable i_vrfCoordinatorAddress;

    //cant make this immutable for some reason
    mapping(uint256 => uint256) private i_3XsumsToPayoutValue;

    /**constants */
    uint256 private constant MINIMUM_PLAY_AMOUNT = 0.005 ether;
    uint16 private constant REQUEST_CONFRIMATIONS = 3;
    uint32 private constant NUM_WORDS = 3;
    uint256 private constant SPIN_COST = 0.0002 ether;

    /**storage variables */
    uint256 private s_currentPlayBalance;
    uint256[3] private s_slotCombination;
    SlotsState s_slotsState;
    SlotActivity s_slotActivity;
    address public s_currentPlayerAddress;

    constructor(
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        address vrfCoordinatorAddress
    ) payable VRFConsumerBaseV2Plus(vrfCoordinatorAddress) {
        if (msg.value < 0.2 ether) {
            revert Slots__PleaseDeployMeWithEnoughEther();
        }
        // settign the immutable variables to the values passed into the consturctor that are network dependent
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_vrfCoordinatorAddress = vrfCoordinatorAddress;
        //setting states of the slot machine
        s_slotsState = SlotsState.OPEN;
        s_slotActivity = SlotActivity.INACTIVE;
        //setting the payout values for the 3x result for the start so as not to be changed
        i_3XsumsToPayoutValue[0] = 100;
        i_3XsumsToPayoutValue[3] = 75;
        i_3XsumsToPayoutValue[6] = 50;
        i_3XsumsToPayoutValue[9] = 35;
        i_3XsumsToPayoutValue[12] = 30;
        i_3XsumsToPayoutValue[15] = 25;
        i_3XsumsToPayoutValue[18] = 20;
        i_3XsumsToPayoutValue[21] = 15;
        i_3XsumsToPayoutValue[24] = 10;
        i_3XsumsToPayoutValue[27] = 5;
        //setting the initial deposit amount then performing it:
    }

    function enterSlots() public payable {
        if (s_slotActivity == SlotActivity.ACTIVE) {
            revert Slots__YouAreAlreadyPlaying();
        }
        if (msg.value < MINIMUM_PLAY_AMOUNT) {
            revert Slots__NotEnoughEthToPlay();
        }
        s_currentPlayerAddress = msg.sender;
        s_currentPlayBalance += msg.value;
        s_slotActivity = SlotActivity.ACTIVE;
    }

    function increaseDeposit() public payable onlyPlayer {
        if (s_slotActivity == SlotActivity.INACTIVE) {
            revert Slots__YouMustEnterFirst();
        }
        s_currentPlayBalance += msg.value;
    }

    function spin() public onlyPlayer {
        //removed the request id being returned
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFRIMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        //we remove the spin cost from the current play balance(s_currentPlayBalance)
        s_currentPlayBalance -= SPIN_COST;
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] calldata _randomWords
    ) internal override onlyOwnerOrCoordinator {
        //uint256 ROWS = 3;
        for (uint256 i = 0; i < 3; i++) {
            uint256 rowResult;
            rowResult = (_randomWords[i]) % 10;
            s_slotCombination[i] = rowResult;
        }
        getRecentSlotCombo();
        checkPlayerBalance();
        uint256 payoutRate = getPayoutRate(s_slotCombination);
        uint256 payoutAmount = payoutRate * SPIN_COST;
        s_currentPlayBalance += payoutAmount;
    }

    //we are going to split the 2 functions of getting the randomness and the slot payout logic

    function getPayoutRate(
        uint256[3] storage slotCombination
    ) private view returns (uint256) {
        //for the triple value results
        if (
            s_slotCombination[0] == s_slotCombination[1] &&
            s_slotCombination[0] == s_slotCombination[2]
        ) {
            uint256 sum = (slotCombination[0]) * 3;
            uint256 payout = i_3XsumsToPayoutValue[sum];
            return payout;
        } else {
            //for the double value results
            if (
                s_slotCombination[0] == s_slotCombination[1] ||
                s_slotCombination[0] == s_slotCombination[2] ||
                s_slotCombination[1] == s_slotCombination[2]
            ) {
                uint256 payout = 2;
                return payout;
            } else {
                return 0;
            }
        }
    }

    function exit() public onlyPlayer {
        address leaver = msg.sender;
        if (s_slotsState == SlotsState.CALCULATING) {
            revert Slots__CalculatingResultPleaseWait();
        }
        (bool success, ) = leaver.call{value: s_currentPlayBalance}("");
        if (!success) {
            revert Slots__ExitFailed();
        }
        s_slotActivity = SlotActivity.INACTIVE;
        s_currentPlayerAddress = address(0);
        s_currentPlayBalance = 0;
    }

    ///////////////////////////////
    ///ONLY OWNER FUNCTIONS////////
    ///////////////////////////////

    function withdraw() public onlyOwner {
        if (address(this).balance < 0.05 ether) {
            revert Slots__NotEnoughBalanceToWithdraw();
        }
        (bool success, ) = (msg.sender).call{value: address(this).balance}("");
        if (!success) {
            revert Slots__WithdrawFailed();
        }
    }

    /////////////////////////
    /////modifiers///////////
    /////////////////////////

    modifier onlyPlayer() {
        if (msg.sender != s_currentPlayerAddress) {
            revert Slots__YouAreNotThePlayer();
        }
        _;
    }

    /**getter functions */
    function checkPlayerBalance() public view returns (uint256) {
        return s_currentPlayBalance;
    }

    function getRecentSlotCombo() public view returns (uint256[3] memory) {
        return s_slotCombination;
    }

    //function get3xPayoutScheme() external view returns (uint256[10] memory) {}

    function getContractBalance() private view onlyOwner returns (uint256) {
        uint256 balance = address(this).balance;
        return balance;
    }
}
