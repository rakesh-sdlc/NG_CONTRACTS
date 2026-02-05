// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/Token.sol";


contract TokenTest is Test {

    error EnforcedPause();
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
        vm.startPrank(owner);
        token.setController(owner);
        token.mint(user1, 1000);
        vm.stopPrank();
    }

    // test initial supply is zero
    function testInitialSupply() public {
        uint256 supply = token.totalSupply();
        assertEq(supply, 1000);
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
    // function testSetController() public {
    //     vm.prank(owner);
    //     vm.expectEmit(true, true, true, true, address(token));
    //     emit MyToken.ControllerUpdated(address(0), user1);
    //     token.setController(user1);
    //     assertEq(token.controller(), user1);
    // }
    // test set controller should fail called by non-owner
    function testUserCantSetController() public {
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user2));
        token.setController(user2);
    }

    function testTransferFromUser() public {
        vm.prank(user1);
        token.transfer(user2, 100);
    }

    function testUserCantcallMint() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.mint(user1, 500);
    }

    function testOwnerCanCallMint() public {
        vm.prank(owner);
        token.mint(user1, 500);
        assertEq(token.balanceOf(user1), 1500);
    }

    function testBurnByUserShouldPass() public {
        vm.prank(user1);
        token.burn(200);
        assertEq(token.balanceOf(user1), 800);
    }

    // test burn from should fail called by non-controller
    function testBurnFromShouldFail() public {
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.burnFrom(user1, 100);
    }

    // test burn from should pass called by controller
    function testBurnFromShouldPass() public {
        vm.prank(owner);
        token.burnFrom(user1, 100);
        assertEq(token.balanceOf(user1), 900);
    }

    // test batch mint should pass by controller
    function testBatchMintShouldPass() public {
        address[] memory tos = new address[](2);
        tos[0] = user1;
        tos[1] = user2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 300;

        vm.prank(owner);
        token.batchMint(tos, amounts);

        assertEq(token.balanceOf(user1), 1200);
        assertEq(token.balanceOf(user2), 300);
    }

    // test batch mint should fail with length mismatch
    function testBatchMintShouldFailLengthMismatch() public {
        address[] memory tos = new address[](2);
        tos[0] = user1;
        tos[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        token.batchMint(tos, amounts);
    }

    // test batch mint should fail with empty array
    function testBatchMintShouldFailEmptyArray() public {
        address[] memory tos = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EmptyArray.selector));
        token.batchMint(tos, amounts);
    }

    // test batch mint should fail called by non-controller
    function testBatchMintShouldFailNotController() public {
        address[] memory tos = new address[](2);
        tos[0] = user1;
        tos[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 300;

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.batchMint(tos, amounts);
    }

    // test batch burn should pass by controller
    function testBatchBurnShouldPass() public {
        address[] memory froms = new address[](2);
        froms[0] = user1;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;

        vm.startPrank(owner);
        token.mint(user2, 300);
        token.batchBurn(froms, amounts);
        vm.stopPrank();
        assertEq(token.balanceOf(user1), 900);
        assertEq(token.balanceOf(user2), 100);
    }

    // test batch burn should fail with length mismatch
    function testBatchBurnShouldFailLengthMismatch() public {
        address[] memory froms = new address[](2);
        froms[0] = user1;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        token.batchBurn(froms, amounts);
    }

    // test batch burn should fail with empty array
    function testBatchBurnShouldFailEmptyArray() public {
        address[] memory froms = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EmptyArray.selector));
        token.batchBurn(froms, amounts);
    }

    // test batch burn should fail called by non-controller
    function testBatchBurnShouldFailNotController() public {
        address[] memory froms = new address[](2);
        froms[0] = user1;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100;
        amounts[1] = 200;
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.batchBurn(froms, amounts);
    }

    // test pause and unpause by owner
    function testPauseAndUnpause() public {
        vm.prank(owner);
        token.pause();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        token.transfer(user2, 100);
        vm.prank(owner);
        token.unpause();
        vm.prank(user1);
        token.transfer(user2, 100);
        assertEq(token.balanceOf(user2), 100);
    }

    // test pause should fail by non-owner
    function testPauseShouldFailByNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        token.pause();  
    }


    // test unpause should fail by non-owner
    function testUnpauseShouldFailByNonOwner() public {
        vm.prank(owner);
        token.pause();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        token.unpause();
    }

    // test transfer should fail when paused
    function testTransferShouldFailWhenPaused() public {
        vm.prank(owner);
        token.pause();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        token.transfer(user2, 100);
    }

    // test call decimal should return 6
    function testDecimals() public {
        uint8 decimals = token.decimals();
        assertEq(decimals, 6);
    }
}