// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "./shared/BaseTest.t.sol";

contract CrowdfundingTest is BaseTest {
    function test_Create_Campaign() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        (
            string memory name,
            address owner,
            uint256 goal,
            uint256 pledged,
            uint256 deadline,
            bool claimed
        ) = crowdfunding.campaigns(0);

        assertEq(name, "Test Project");
        assertEq(owner, creator);
        assertEq(goal, GOAL);
        assertEq(pledged, 0);
        assertEq(deadline, block.timestamp + DURATION);
        assertFalse(claimed);
    }

    function test_Pledge_Success() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 5 ether}(0);

        (, , , uint256 pledged, , ) = crowdfunding.campaigns(0);

        assertEq(pledged, 5 ether);
        assertEq(crowdfunding.pledges(0, backer1), 5 ether);
    }

    function test_RevertIf_PledgeAfterDeadline() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.warp(block.timestamp + DURATION + 1 days);

        vm.prank(backer1);
        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.CampaignEnded.selector, 0));
        crowdfunding.pledge{value: 5 ether}(0);
    }

    function test_Claim_Success() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 12 ether}(0);

        vm.warp(block.timestamp + DURATION + 1 seconds);

        uint256 balanceCreatorBefore = creator.balance;

        crowdfunding.claim(0);

        uint256 expectedFee = (12 ether * 2) / 100;
        uint256 expectedCreatorShare = 12 ether - expectedFee;

        assertEq(creator.balance, balanceCreatorBefore + expectedCreatorShare);
        assertEq(crowdfunding.accumulatedFees(), expectedFee);
    }

    function test_RevertIf_ClaimBeforeDeadline() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 12 ether}(0);

        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.CampaignNotEnded.selector, 0));
        crowdfunding.claim(0);
    }

    function test_RevertIf_RecoverFundsFromSuccessfulCampaignDuringGracePeriod() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 10 ether}(0);

        vm.warp(block.timestamp + DURATION + 15 days);

        vm.prank(backer1);
        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.CampaignSuccessful.selector, 0));
        crowdfunding.recoverFunds(0);
    }

    function test_RecoverFunds_SuccessAfterGracePeriod() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 10 ether}(0);

        vm.warp(block.timestamp + DURATION + 31 days);

        uint256 balanceBackerBefore = backer1.balance;

        vm.prank(backer1);
        crowdfunding.recoverFunds(0);

        assertEq(backer1.balance, balanceBackerBefore + 10 ether);
    }
}
