// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "./shared/BaseTest.t.sol";

contract CrowdfundingFuzzTest is BaseTest {
    function testFuzz_Pledge(uint256 randomAmount) public {
        uint256 amount = bound(randomAmount, 1 wei, 20 ether);

        vm.prank(creator);
        crowdfunding.createCampaign("Proyecto Fuzz", GOAL, DURATION);

        vm.prank(backer1);
        crowdfunding.pledge{value: amount}(0);

        (,,, uint256 pledged,,) = crowdfunding.campaigns(0);

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

    function testFuzz_CreateCampaign(uint256 randomGoal, uint256 randomDuration) public {
        uint256 duration = bound(randomDuration, 1 hours, 365 days);
        uint256 goal = bound(randomGoal, 1 wei, 1000000 ether);

        vm.prank(creator);
        crowdfunding.createCampaign("Proyecto Flexible", goal, duration);

        (,, uint256 savedGoal,, uint256 deadline,) = crowdfunding.campaigns(0);

        assertEq(savedGoal, goal);
        assertEq(deadline, block.timestamp + duration);
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
            uint256 expectedHowMany = expectedFirstIndex + perPage > totalCampaigns
                ? totalCampaigns - expectedFirstIndex
                : perPage;

            assertEq(results.length, expectedHowMany);
        }
    }
}
