// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "./shared/BaseTest.t.sol";

contract CrowdfundingFuzzTest is BaseTest {
    function testFuzz_Pledge(uint256 randomAmount) public {
        uint256 amount = bound(randomAmount, 0.01 ether, 20 ether);

        vm.prank(creator);
        crowdfunding.createCampaign("New Campaign", 1 ether, 1 days);

        vm.prank(backer1);
        crowdfunding.pledge{value: amount}(0);

        (,,,, uint256 pledged,,) = crowdfunding.campaigns(0);

        assertEq(pledged, amount);
        assertEq(crowdfunding.pledges(0, backer1), amount);
    }

    function testFuzz_SetFeePercentage(uint8 randomFee) public {
        if (randomFee > crowdfunding.MAX_FEE()) {
            vm.expectRevert(abi.encodeWithSelector(Crowdfunding.FeeOutOfBounds.selector, randomFee));
            crowdfunding.setFeePercentage(randomFee);
        } else {
            crowdfunding.setFeePercentage(randomFee);
            assertEq(crowdfunding.feePercentage(), randomFee);
        }
    }

    function testFuzz_CreateCampaign(uint256 goal, uint256 duration) public {
        vm.assume(goal >= 0.01 ether && goal <= 1000000 ether);
        vm.assume(duration >= 4 hours && duration <= 365 days);

        vm.prank(creator);
        crowdfunding.createCampaign("New Campaign", goal, duration);

        (,,, uint256 savedGoal,, uint256 deadline,) = crowdfunding.campaigns(0);

        assertEq(savedGoal, goal);
        assertEq(deadline, block.timestamp + duration);
    }

    function testFuzz_CampaignDurationLimits(uint256 duration) public {
        vm.assume(duration > 0);
        vm.prank(creator);

        if (duration < 4 hours) {
            vm.expectRevert(abi.encodeWithSelector(DurationOutOfBounds.selector, duration));
            crowdfunding.createCampaign("Short Project", 1 ether, duration);
        } else if (duration > 365 days) {
            vm.expectRevert(abi.encodeWithSelector(DurationOutOfBounds.selector, duration));
            crowdfunding.createCampaign("Long Project", 1 ether, duration);
        } else {
            crowdfunding.createCampaign("Valid Project", 1 ether, duration);
        }
    }

    function testFuzz_GetPaginatedCampaigns(uint8 totalCampaigns, uint8 page, uint8 perPage) public {
        vm.assume(page > 0);
        vm.assume(perPage > 0 && perPage <= 50);
        vm.assume(totalCampaigns <= 1000);

        _helperCreateCampaigns(totalCampaigns);

        Crowdfunding.Campaign[] memory results = crowdfunding.getPaginatedCampaigns(page, perPage);

        uint256 expectedFirstIndex = (uint256(page) - 1) * perPage;

        if (expectedFirstIndex >= totalCampaigns) {
            assertEq(results.length, 0);
        } else {
            uint256 expectedHowMany =
                expectedFirstIndex + perPage > totalCampaigns ? totalCampaigns - expectedFirstIndex : perPage;

            assertEq(results.length, expectedHowMany);
        }
    }
}
