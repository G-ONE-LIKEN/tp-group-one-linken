// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ProjectFactory} from "../src/ProjectFactory.sol";

contract DeployFactory is Script {
    function run() external {
        vm.startBroadcast();

        ProjectFactory factory = new ProjectFactory(msg.sender);

        console.log("ProjectFactory deployed at:", address(factory));
        console.log("Platform owner:            ", msg.sender);

        vm.stopBroadcast();
    }
}
