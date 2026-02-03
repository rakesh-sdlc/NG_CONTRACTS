// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/Token.sol";


contract TokenTest is Test {


    error ZeroAddress();
    error NotController();
    error LengthMismatch();
    error EmptyArray();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);


    MyToken token;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    function setUp() public {
        vm.prank(owner);
        token = new MyToken("MyToken", "MTK");
    }

    // test initial supply is zero
    function testInitialSupply() public {
        uint256 supply = token.totalSupply();
        assertEq(supply, 0);
    }

    // test mint should fail called by not controller
    function testMintShouldFail() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.mint(user1, 1000);
    }

    // test mint should pass by controller 
    function testMintWithController() public {
        vm.startPrank(owner);
        token.setController(user1);
        vm.stopPrank();
        vm.prank(user1);
        token.mint(user2, 1000);
        assertEq(token.balanceOf(user2), 1000);
    }

    // test set controller should pass called by owner
    function testSetController() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true, address(token));
        emit MyToken.ControllerUpdated(address(0), user1);
        token.setController(user1);
        assertEq(token.controller(), user1);
    }
    // test set controller should fail called by non-owner
    function testUserCantSetController() public {
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user2));
        token.setController(user2);
    }

    function testTransfer() public {

    }
}