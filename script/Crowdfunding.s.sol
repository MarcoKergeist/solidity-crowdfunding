// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import "forge-std/Script.sol";
import "../src/Crowdfunding.sol";

contract DeployCrowdfunding is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        new Crowdfunding();

        vm.stopBroadcast();
    }
}
