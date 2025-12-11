// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MyToken} from "../src/Token.sol";
import {Test} from "forge-std/Test.sol";

contract TokenTest is Test {
    MyToken private token;
    address private owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    error NotController();
    error EnforcedPause();
    error ZeroAddress();
    error OwnableUnauthorizedAccount(address account);
    error LengthMismatch();
    error EmptyArray();

    function setUp() public {
        vm.startPrank(owner);
        token = new MyToken("MyToken", "MTK");
        token.setController(owner);
        token.mint(user, 1000);
        vm.stopPrank();
    }
    /*****************************************  TEST CASES TO SET NEW CONTROLLER  *************************************************/

    // test setting controller by owner
    function testSetController() public {
        address newController = makeAddr("newController");
        vm.prank(owner);
        token.setController(newController);
        assertEq(token.controller(), newController);
    }

    // test setting controller by non owner should fail
    function testSetControllerByNonOwner() public {
        address newController = makeAddr("newController");
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        token.setController(newController);
    }

    // test setting controller to zero address should fail
    function testSetControllerToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        token.setController(address(0));
    }

    /*****************************************  TEST CASES FOR MINTING TOKEN  *************************************************/
    // Mint token as controller to user
    function testMint() public {
        vm.prank(owner);
        token.mint(user, 1000);
        assertEq(token.balanceOf(user), 2000);
    }

    // test minting by non controller should fail
    function testMintByNonController() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.mint(user, 1000);
    }

    /*****************************************  TEST CASES FOR BURNING TOKEN  *************************************************/

    // test burn tokens by owner of token
    function testBurn() public {
        vm.prank(user);
        token.burn(400);
        assertEq(token.balanceOf(user), 600);
    }

    // test burnFrom by controller
    function testBurnFromByController() public {
        vm.prank(owner);
        token.burnFrom(user, 300);
        assertEq(token.balanceOf(user), 700);
    }

    // test burnFrom by non controller should fail
    function testBurnFromByNonController() public {
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.burnFrom(user, 300);
    }

    /*****************************************  TEST CASES FOR BATCH MINT TOKEN  *************************************************/
    // test batch minting by controller
    function testBatchMintFromToken() public {
        address[] memory tos = new address[](2);
        tos[0] = user;
        tos[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500;
        amounts[1] = 800;
        vm.prank(owner);
        token.batchMint(tos, amounts);
        assertEq(token.balanceOf(user), 1500);
        assertEq(token.balanceOf(user2), 800);
    }

    // test batch minting by non controller should fail
    function testBatchMintFromNonController() public {
        address[] memory tos = new address[](2);
        tos[0] = user;
        tos[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500;
        amounts[1] = 800;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.batchMint(tos, amounts);
    }

    // test batch minting with length mismatch should fail
    function testBatchMintLengthMismatch() public {
        address[] memory tos = new address[](2);
        tos[0] = user;
        tos[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 500;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        token.batchMint(tos, amounts);
    }

    // test batch minting with empty array should fail
    function testBatchMintEmptyArray() public {
        address[] memory tos = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EmptyArray.selector));
        token.batchMint(tos, amounts);
    }

    /*****************************************  TEST CASES FOR BATCH BURN TOKEN  *************************************************/

    // test batch burning by controller
    function testBatchBurnFromToken() public {
        address[] memory froms = new address[](2);
        froms[0] = user;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 300;
        // Mint some tokens to user2 first
        vm.prank(owner);
        token.mint(user2, 500);
        vm.prank(owner);
        token.batchBurn(froms, amounts);
        assertEq(token.balanceOf(user), 800);
        assertEq(token.balanceOf(user2), 200);
    }

    // test batch burning by non controller should fail
    function testBatchBurnFromNonController() public {
        address[] memory froms = new address[](2);
        froms[0] = user;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 300;
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.batchBurn(froms, amounts);
    }

    // test batch burning with length mismatch should fail
    function testBatchBurnLengthMismatch() public {
        address[] memory froms = new address[](2);
        froms[0] = user;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200;
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        token.batchBurn(froms, amounts);
    }

    // test batch burning after pausing the contract should fail
    function testBatchBurnWhenPaused() public {
        address[] memory froms = new address[](2);
        froms[0] = user;
        froms[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 200;
        amounts[1] = 300;
        vm.prank(owner);
        token.pause();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        token.batchBurn(froms, amounts);
    }


    /*****************************************  TEST CASES FOR TRANSFER TOKEN  *************************************************/

    // test for transfer the tokens
    function testTransfer() public {
        vm.prank(user);
        token.transfer(address(0x1234), 200);
        assertEq(token.balanceOf(user), 800);
        assertEq(token.balanceOf(address(0x1234)), 200);
    }

    /*****************************************  TEST CASES FOR PAUSING THE CONTRACT  *************************************************/

    // test for unpausing the contract only owner can unpause and pause
    function testUnpauseAndTryMinting() public {
        vm.prank(owner);
        token.pause();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        token.mint(user, 500);
        vm.prank(owner);
        token.unpause();
        vm.prank(owner);
        token.mint(user, 500);
        assertEq(token.balanceOf(user), 1500);
    }

    // test that only owner can pause the contract
    function testOnlyOwnerCanPause() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        token.pause();
    }

    // test user cannot mint
    function testUserCannotMint() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotController.selector));
        token.mint(user, 500);
    }
}
