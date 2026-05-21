// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Linken} from "../../src/legacy/Linken.sol";

contract DeployLinken is Script {
    function run() external {
        vm.startBroadcast();

        // El deployer (msg.sender) recibe el INITIAL_SUPPLY y es el owner.
        Linken token = new Linken(msg.sender);

        console.log("Linken (LKN) deployed at:", address(token));
        console.log("Owner / Treasury:         ", msg.sender);
        console.log("Initial supply:           ", token.totalSupply() / 1e18, "LKN");

        vm.stopBroadcast();
    }
}
