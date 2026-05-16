// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Crowdfunding is Ownable {

    uint256 private _campaignCount = 0;

    struct Campaign {
        string name;
        address owner;
        uint256 goal;
        uint256 pledged;
        uint256 deadline;
        bool claimed;
    }
    
    constructor() Ownable(msg.sender) {
        //
    }

    // Data
    uint8 public feePercentage = 2;
    uint256 public accumulatedFees;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public pledges;

    // Errors
    error FeeOutOfBounds(uint8 fee);
    error CampaignNotFound(uint256 campaignId);
    error CampaignEnded(uint256 campaignId);
    error CampaignNotEnded(uint256 campaignId);
    error CampaignSuccessful(uint256 campaignId);
    error CampaignNotSuccessful(uint256 campaignId);
    error FundsAlreadyClaimed(uint256 campaignId);
    error ZeroContribution();
    error NoFundsToRecover();
    error TransferFailed();

    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed owner,
        string name,
        uint256 goal,
        uint256 deadline
    );
    event CampaignPledged(
        uint256 indexed campaignId,
        address indexed backer,
        uint256 amount
    );
    event FundsClaimed(
        uint256 indexed campaignId,
        address indexed owner,
        uint256 amount
    );
    event FundsRecovered(
        uint256 indexed campaignId,
        address indexed backer,
        uint256 amount
    );

    function setFeePercentage(uint8 _feePercentage) external onlyOwner {
        if (_feePercentage > 5) {
            revert FeeOutOfBounds(_feePercentage);
        }

        feePercentage = _feePercentage;
    }

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");

        if (! success) {
            revert TransferFailed();
        }
    }

    function createCampaign(
        string memory _name,
        uint256 _goal,
        uint256 _duration
    ) external {
        uint256 campaignId = _campaignCount++;

        campaigns[campaignId] = Campaign({
            name: _name,
            owner: msg.sender,
            goal: _goal,
            pledged: 0,
            deadline: block.timestamp + _duration,
            claimed: false
        });

        emit CampaignCreated(
            campaignId,
            msg.sender,
            _name,
            _goal,
            block.timestamp + _duration
        );
    }

    function pledge(uint256 _campaignId) external payable {
        if (msg.value == 0) {
            revert ZeroContribution();
        }

        if (campaigns[_campaignId].owner == address(0)) {
            revert CampaignNotFound(_campaignId);
        }

        if (block.timestamp > campaigns[_campaignId].deadline) {
            revert CampaignEnded(_campaignId);
        }

        campaigns[_campaignId].pledged += msg.value;
        pledges[_campaignId][msg.sender] += msg.value;

        emit CampaignPledged(
            _campaignId,
            msg.sender,
            msg.value
        );
    }

    function claim(uint256 _campaignId) external {
        if (campaigns[_campaignId].owner == address(0)) {
            revert CampaignNotFound(_campaignId);
        }

        if (block.timestamp <= campaigns[_campaignId].deadline) {
            revert CampaignNotEnded(_campaignId);
        }

        if (campaigns[_campaignId].pledged < campaigns[_campaignId].goal) {
            revert CampaignNotSuccessful(_campaignId);
        }

        if (campaigns[_campaignId].claimed) {
            revert FundsAlreadyClaimed(_campaignId);
        }

        campaigns[_campaignId].claimed = true;

        uint256 fee = (campaigns[_campaignId].pledged * feePercentage) / 100;
        accumulatedFees += fee;

        (bool success, ) = payable(campaigns[_campaignId].owner)
            .call{value: campaigns[_campaignId].pledged - fee}("");

        if (! success) {
            revert TransferFailed();
        }

        emit FundsClaimed(
            _campaignId,
            campaigns[_campaignId].owner,
            campaigns[_campaignId].pledged - fee
        );
    }

    function recoverFunds(uint256 _campaignId) external {
        if (campaigns[_campaignId].owner == address(0)) {
            revert CampaignNotFound(_campaignId);
        }

        if (block.timestamp <= campaigns[_campaignId].deadline) {
            revert CampaignNotEnded(_campaignId);
        }

        if (campaigns[_campaignId].claimed) {
            revert FundsAlreadyClaimed(_campaignId);
        }

        if (
            campaigns[_campaignId].pledged >= campaigns[_campaignId].goal
            && block.timestamp <= campaigns[_campaignId].deadline + 30 days
        ) {
            revert CampaignSuccessful(_campaignId);
        }

        uint256 amount = pledges[_campaignId][msg.sender];

        if (amount == 0) {
            revert NoFundsToRecover();
        }

        pledges[_campaignId][msg.sender] = 0;
        campaigns[_campaignId].pledged -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");

        if (! success) {
            revert TransferFailed();
        }

        emit FundsRecovered(
            _campaignId,
            msg.sender,
            amount
        );
    }
}
