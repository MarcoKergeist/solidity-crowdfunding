// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Test.sol";
import "../../src/Crowdfunding.sol";

abstract contract BaseTest is Test {
    Crowdfunding internal crowdfunding;

    address internal creator = address(0x1);
    address internal backer1 = address(0x2);
    address internal backer2 = address(0x3);

    uint256 internal constant GOAL = 10 ether;
    uint256 internal constant DURATION = 7 days;

    error InvalidPagination(uint256 page, uint256 perPage);

    function setUp() public virtual {
        crowdfunding = new Crowdfunding();

        vm.label(creator, "Creator Wallet");
        vm.label(backer1, "Backer 1");
        vm.label(backer2, "Backer 2");
        vm.label(address(crowdfunding), "Crowdfunding Contract");

        vm.deal(backer1, 20 ether);
        vm.deal(backer2, 20 ether);
    }

    function _helperCreateCampaigns(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            crowdfunding.createCampaign("Test Campaign", 1 ether, block.timestamp + 1 days);
        }
    }
}
