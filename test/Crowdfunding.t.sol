// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "./shared/BaseTest.t.sol";

contract CrowdfundingTest is BaseTest {
    function test_Create_Campaign() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        (uint256 id, string memory name, address owner, uint256 goal, uint256 pledged, uint256 deadline, bool claimed) =
            crowdfunding.campaigns(0);

        assertEq(id, campaignId);
        assertEq(name, "Test Project");
        assertEq(owner, creator);
        assertEq(goal, GOAL);
        assertEq(pledged, 0);
        assertEq(deadline, block.timestamp + DURATION);
        assertFalse(claimed);
    }

    function test_CreateRevertIf_GoalIsTooLow() public {
        uint256 invalidGoal = 1 wei;

        vm.expectRevert(abi.encodeWithSelector(GoalTooLow.selector, invalidGoal));

        vm.prank(creator);
        crowdfunding.createCampaign("Spam Campaign", invalidGoal, block.timestamp + 1 days);
    }

    function test_RenameCampaign_Success() public {
        vm.startPrank(creator);
        uint256 campaignId = crowdfunding.createCampaign("Initial Name", 1 ether, block.timestamp + 1 days);

        vm.expectEmit(true, false, false, true);
        emit CampaignRenamed(campaignId, "New Name");

        crowdfunding.renameCampaign(campaignId, "New Name");
        vm.stopPrank();

        (, string memory currentName,,,,,) = crowdfunding.campaigns(campaignId);
        assertEq(currentName, "New Name");
    }

    function test_RevertIf_RenameNonExistentCampaign() public {
        vm.expectRevert(abi.encodeWithSelector(CampaignNotFound.selector, 999));

        vm.prank(creator);
        crowdfunding.renameCampaign(999, "New Name");
    }

    function test_RevertIf_RenameNotCampaignOwner() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign("Real Project Name", 1 ether, block.timestamp + 1 days);

        vm.expectRevert(abi.encodeWithSelector(MustBeCampaignOwner.selector, campaignId, backer1));

        vm.prank(backer1);
        crowdfunding.renameCampaign(campaignId, "Hacked Project Name");
    }

    function test_Pledge_Success() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 5 ether}(0);

        (,,,, uint256 pledged,,) = crowdfunding.campaigns(0);

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

        vm.prank(creator);
        crowdfunding.claim(0);

        uint256 expectedFee = (12 ether * 2) / 100;
        uint256 expectedCreatorShare = 12 ether - expectedFee;

        assertEq(creator.balance, balanceCreatorBefore + expectedCreatorShare);
        assertEq(crowdfunding.accumulatedFees(), expectedFee);
    }

    function test_RevertIf_ClaimNotCampaignOwner() public {
        vm.prank(creator);
        uint256 campaignId = crowdfunding.createCampaign("New Project", 2 ether, block.timestamp + 1 days);

        vm.expectRevert(abi.encodeWithSelector(MustBeCampaignOwner.selector, campaignId, backer1));

        vm.prank(backer1);
        crowdfunding.claim(campaignId);
    }

    function test_RevertIf_ClaimBeforeDeadline() public {
        vm.prank(creator);
        crowdfunding.createCampaign("Test Project", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: 12 ether}(0);

        vm.expectRevert(abi.encodeWithSelector(Crowdfunding.CampaignNotEnded.selector, 0));
        vm.prank(creator);
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

    function test_RevertIf_PageOrPerPageIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidPagination.selector, 0, 10));
        crowdfunding.getPaginatedCampaigns(0, 10);

        vm.expectRevert(abi.encodeWithSelector(InvalidPagination.selector, 1, 0));
        crowdfunding.getPaginatedCampaigns(1, 0);
    }

    function test_GetPaginatedCampaigns_EmptyContract() public view {
        Crowdfunding.Campaign[] memory results = crowdfunding.getPaginatedCampaigns(1, 10);
        assertEq(results.length, 0);
    }

    function test_GetPaginatedCampaigns_FirstPageFull() public {
        _helperCreateCampaigns(5);

        Crowdfunding.Campaign[] memory results = crowdfunding.getPaginatedCampaigns(1, 5);
        assertEq(results.length, 5);
    }

    function test_GetPaginatedCampaigns_LastPagePartial() public {
        _helperCreateCampaigns(12);

        Crowdfunding.Campaign[] memory results = crowdfunding.getPaginatedCampaigns(3, 5);
        assertEq(results.length, 2);
    }

    function test_GetPaginatedCampaigns_OutOfBounds() public {
        _helperCreateCampaigns(5);

        Crowdfunding.Campaign[] memory results = crowdfunding.getPaginatedCampaigns(2, 5);
        assertEq(results.length, 0);
    }
}
