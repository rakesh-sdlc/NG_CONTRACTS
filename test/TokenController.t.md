// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MyToken} from "../src/Token.sol";
import {TokenController} from "../src/TokenController.sol";
import {Test} from "forge-std/Test.sol";

// Events
event AssetRegistered(bytes32 indexed assetId, string assetName, address token);
event AssetUnregistered(
    bytes32 indexed assetId,
    string assetName,
    address token
);
event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
);
event MintPerformed(
    bytes32 indexed assetId,
    address indexed to,
    uint256 amount,
    address indexed operator
);

// Errors
error OwnableUnauthorizedAccount(address account);
error AssetAlreadyRegistered(bytes32 assetId);
error AssetNotRegistered(bytes32 assetId);
error InvalidAssetName();
error ZeroAddress();
error EnforcedPause();
error LengthMismatch();
error ERC20InsufficientBalance(
    address from,
    uint256 fromBalance,
    uint256 value
);

contract TokenControllerTest is Test {
    MyToken private goldToken;
    MyToken private silverToken;
    TokenController private controller;
    address private owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public GLOBAL_WALLET = makeAddr("globalWallet");

    function setUp() public {
        vm.startPrank(owner);
        goldToken = new MyToken("GOLDTOKEN", "GOLD");
        silverToken = new MyToken("SILVERTOKEN", "SILVER");
        controller = new TokenController(GLOBAL_WALLET);
        goldToken.setController(address(controller));
        silverToken.setController(address(controller));
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR REGISTER ASSET FUNCTION *************************************************/

    // test register a asset and expect event
    function testRegisterAsset() public {
        vm.startPrank(owner);
        bytes32 expectedAssetId = keccak256(abi.encodePacked("GOLD"));
        vm.expectEmit(true, false, false, false);
        emit AssetRegistered(expectedAssetId, "GOLD", address(goldToken));
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
    }

    // test register asset can not be called by non-owner
    function testRegisterAssetNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        controller.registerAsset("GOLD", address(goldToken));
    }

    // test register asset with pausing the contract and expect revert
    function testRegisterAssetWhenPaused() public {
        vm.startPrank(owner);
        controller.pause();
        vm.expectRevert();
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
    }

    // test register asset 2 times expect revert
    function testRegisterAssetTwice() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetAlreadyRegistered.selector,
                keccak256(abi.encodePacked("GOLD"))
            )
        );
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
    }

    // test register asset with empty name expect revert
    function testRegisterAssetEmptyName() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(InvalidAssetName.selector));
        controller.registerAsset("", address(goldToken));
        vm.stopPrank();
    }

    // test register asset with zero address expect revert
    function testRegisterAssetZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        controller.registerAsset("GOLD", address(0));
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR UNREGISTER ASSET FUNCTION *************************************************/

    // test unregister a asset and expect event
    function testUnregisterAsset() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        bytes32 expectedAssetId = keccak256(abi.encodePacked("GOLD"));
        vm.expectEmit(true, false, false, false);
        emit AssetUnregistered(expectedAssetId, "GOLD", address(goldToken));
        controller.unregisterAsset("GOLD");
        vm.stopPrank();
    }

    // test unregister asset can not be called by non-owner
    function testUnregisterAssetNotOwner() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.unregisterAsset("GOLD");
    }

    // test unregister asset with pausing the contract and expect revert
    function testUnregisterAssetWhenPaused() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        controller.pause();
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        controller.unregisterAsset("GOLD");
        vm.stopPrank();
    }

    // test unregistered asset expect revert
    function testUnregisterUnregisteredAsset() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("GOLD"))
            )
        );
        controller.unregisterAsset("GOLD");
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR GET ASSET TOKEN FUNCTION *************************************************/

    // test get asset token
    function testGetAssetToken() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        address tokenAddress = controller.getAssetTokenAddress("GOLD");
        assertEq(tokenAddress, address(goldToken));
        vm.stopPrank();
    }

    // test get asset token for unregistered asset expect revert
    function testGetAssetTokenUnregisteredAsset() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("GOLD"))
            )
        );
        controller.getAssetTokenAddress("GOLD");
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR LIST ASSETS FUNCTION *************************************************/
    // test list assets
    function testListAssets() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        controller.registerAsset("SILVER", address(silverToken));
        bytes32[] memory assetIds = controller.listAssets();
        assertEq(assetIds.length, 2);
        assertEq(assetIds[0], keccak256(abi.encodePacked("GOLD")));
        assertEq(assetIds[1], keccak256(abi.encodePacked("SILVER")));
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR SET CUSTODY WALLET FUNCTION *************************************************/
    // test set custody wallet
    function testSetCustodyWallet() public {
        vm.startPrank(owner);
        address newWallet = makeAddr("newWallet");
        controller.setCustodyWallet(newWallet);
        assertEq(controller.custodyWallet(), newWallet);
        vm.stopPrank();
    }

    // test set custody wallet can not be called by non-owner
    function testSetCustodyWalletNotOwner() public {
        address newWallet = makeAddr("newWallet");
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.setCustodyWallet(newWallet);
    }

    // test set custody wallet to zero address expect revert
    function testSetCustodyWalletZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        controller.setCustodyWallet(address(0));
        vm.stopPrank();
    }

    // test set custody wallet when paused expect revert
    function testSetCustodyWalletWhenPaused() public {
        vm.startPrank(owner);
        controller.pause();
        address newWallet = makeAddr("newWallet");
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        controller.setCustodyWallet(newWallet);
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR TRANSFER OWNERSHIP TO CONTROLLER  *************************************************/

    // test transfer ownership of token to controller
    function testTransferOwnershipOfTokenToController() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        vm.expectEmit(true, true, false, false, address(goldToken));
        emit OwnershipTransferred(owner, address(controller));
        goldToken.transferOwnership(address(controller));
        assertEq(goldToken.owner(), address(controller));
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR GET ASSET ID *************************************************/
    // test get asset id
    function testGetAssetId() public {
        bytes32 assetId = controller.getAssetId("GOLD");
        assertEq(assetId, keccak256(abi.encodePacked("GOLD")));
    }

    // test asset id is available after registering asset
    function testAssetIdAfterRegisteringAsset() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        bytes32 assetId = controller.getAssetId("GOLD");
        assertEq(assetId, keccak256(abi.encodePacked("GOLD")));
        vm.stopPrank();
    }

    // test asset is already registered after registering asset
    function testAssetAlreadyRegisteredAfterRegisteringAsset() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        bool result = controller.checkAssetRegistered("GOLD");
        assertEq(result, true);
        vm.stopPrank();
    }

    // test asset is not registered for unregistered asset
    function testAssetNotRegisteredForUnregisteredAsset() public view {
        bool result = controller.checkAssetRegistered("PLATINUM");
        assertEq(result, false);
    }

    /*****************************************  TEST CASES FOR TOTAL SUPPLY OF ASSET TOKEN  *************************************************/
    // test total supply of asset after minting
    function testTotalSupplyOfAssetAfterMinting() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        uint256 totalSupply = goldToken.totalSupply();
        assertEq(totalSupply, 500);
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR TOKEN OF ASSET FUNCTION  *************************************************/
    // test token with address
    function testTokenOfAsset() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        address tokenAddress = controller.getAddressOfAssetToken("GOLD");
        assertEq(tokenAddress, address(goldToken));
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR PAUSE AND UNPAUSE TOKENCONTROLLER CONTRACT  *************************************************/

    // test pause and unpause TokenController contract
    function testPauseAndUnpauseTokenController() public {
        vm.startPrank(owner);
        controller.pause();
        assertEq(controller.paused(), true);
        controller.unpause();
        assertEq(controller.paused(), false);
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR MINTING ASSET TOKEN *************************************************/
    // test mint asset tokens to user and check balance
    function testMintAssetTokens() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        vm.expectEmit(true, true, true, true, address(controller));
        emit MintPerformed(
            keccak256(abi.encodePacked("GOLD")),
            user2,
            500,
            owner
        );
        controller.mint("GOLD", user2, 500);
        uint256 user2Balance = goldToken.balanceOf(user2);
        assertEq(user2Balance, 500);
        vm.stopPrank();
    }

    // test mint asset tokens can not be called by non-owner
    function testMintAssetTokensNotOwner() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.mint("GOLD", user2, 500);
    }

    // test mint asset with unregistered asset expect revert
    function testMintUnregisteredAssetTokens() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("GOLDD"))
            )
        );
        controller.mint("GOLDD", user2, 500);
    }

    // test mint asset when paused expect revert
    function testMintWhenPaused() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        controller.pause();
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        controller.mint("GOLD", user2, 500);
    }

    /*****************************************  TEST CASES FOR BATCH MINT SAME ASSET TOKENS  *************************************************/

    // test batchmint same asset tokens to multiple users and check balances
    function testBatchMintSameAssetTokens() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        controller.batchMintSameAsset("GOLD", recipients, amounts);
        uint256 userBalance = goldToken.balanceOf(user);
        uint256 user2Balance = goldToken.balanceOf(user2);
        assertEq(userBalance, 300);
        assertEq(user2Balance, 400);
        vm.stopPrank();
    }

    // test batchmint same asset tokens with mismatched arrays expect revert
    function testBatchMintSameAssetTokensMismatchedArrays() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        controller.batchMintSameAsset("GOLD", recipients, amounts);
        vm.stopPrank();
    }

    // test batchmint with unregistered asset expect revert
    function testBatchMintUnregisteredAssetTokens() public {
        vm.startPrank(owner);
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("GOLD"))
            )
        );
        controller.batchMintSameAsset("GOLD", recipients, amounts);
        vm.stopPrank();
    }

    // test batchmint can not be called by non-owner
    function testBatchMintCanNotCalledByNonOwner() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        vm.stopPrank();
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.batchMintSameAsset("GOLD", recipients, amounts);
    }

    // test batchmint when paused expect revert
    function testBatchMintWhenPaused() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.pause();
        address[] memory recipients = new address[](2);
        recipients[0] = user;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        controller.batchMintSameAsset("GOLD", recipients, amounts);
        vm.stopPrank();
    }

    /*****************************************  TEST CASES FOR BATCH MINT SAME ASSET TOKENS  *************************************************/

    // test batchmint multiple assets to multiple users and check balances
    // function testBatchMintMultipleAssetsToMultipleUsers() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user2;
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     uint256 userGoldBalance = goldToken.balanceOf(user);
    //     uint256 user2SilverBalance = silverToken.balanceOf(user2);
    //     assertEq(userGoldBalance, 300);
    //     assertEq(user2SilverBalance, 400);
    //     vm.stopPrank();
    // }

    // batch mint multiple assets to single user
    // function testBatchMintMultipleAssetsToSingleUser() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user;
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     uint256 userGoldBalance = goldToken.balanceOf(user);
    //     uint256 userSilverBalance = silverToken.balanceOf(user);
    //     assertEq(userGoldBalance, 300);
    //     assertEq(userSilverBalance, 400);
    //     vm.stopPrank();
    // }

    // batch mint multiple assets with one zero address expect revert
    // function testBatchMintMultipleAssetsWithOneZeroAddress() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = address(0);
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     vm.stopPrank();
    // }

    // batch mint multiple assets with mismatched arrays expect revert
    // function testBatchMintMultipleAssetsMismatchedArrays() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user2;
    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = 300;
    //     vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     vm.stopPrank();
    // }

    // batch mint multiple assets can not be called by non-owner
    // function testBatchMintMultipleAssetsCanNotCalledByNonOwner() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     vm.stopPrank();
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user2;
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     vm.prank(user);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
    //     );
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    // }

    // batch mint multiple assets when paused expect revert
    // function testBatchMintMultipleAssetsWhenPaused() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     controller.registerAsset("SILVER", address(silverToken));
    //     goldToken.transferOwnership(address(controller));
    //     silverToken.transferOwnership(address(controller));
    //     controller.pause();
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user2;
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     vm.stopPrank();
    // }

    // batch mint multiple assets with unregistered asset expect revert
    // function testBatchMintMultipleAssetsWithUnregisteredAsset() public {
    //     vm.startPrank(owner);
    //     controller.registerAsset("GOLD", address(goldToken));
    //     goldToken.transferOwnership(address(controller));
    //     string[] memory assets = new string[](2);
    //     assets[0] = "GOLD";y
    //     assets[1] = "SILVER";
    //     address[] memory recipients = new address[](2);
    //     recipients[0] = user;
    //     recipients[1] = user2;
    //     uint256[] memory amounts = new uint256[](2);
    //     amounts[0] = 300;
    //     amounts[1] = 400;
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             AssetNotRegistered.selector,
    //             keccak256(abi.encodePacked("SILVER"))
    //         )
    //     );
    //     controller.batchMintMultipleAssets(assets, recipients, amounts);
    //     vm.stopPrank();
    // }

    /*****************************************  TEST CASES FOR BURN ASSET TOKENS  *************************************************/
    // test burn asset tokens from controller
    function testBurnAssetTokensFromController() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        vm.stopPrank();
        vm.prank(owner);
        controller.burn("GOLD", user2, 200);
        uint256 user2Balance = goldToken.balanceOf(user2);
        assertEq(user2Balance, 300);
    }

    // test burn asset tokens exceed balance expect revert
    function testBurnAssetTokensExceedBalance() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector,
                user2,
                500,
                600
            )
        );
        controller.burn("GOLD", user2, 600);
    }

    // test burn asset tokens can not be called by non-owner
    function testBurnAssetTokensCanNotCalledByNonOwner() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.burn("GOLD", user2, 200);
    }

    // test burn unregistered asset expect revert
    function testBurnUnregisteredAssetTokens() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("SILVER"))
            )
        );
        controller.burn("SILVER", user2, 200);
    }

    // burn from zero address expect revert
    function testBurnFromZeroAddress() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ZeroAddress.selector));
        controller.burn("GOLD", address(0), 200);
    }

    // burn when paused expect revert
    function testBurnWhenPaused() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        controller.mint("GOLD", user2, 500);
        controller.pause();
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        controller.burn("GOLD", user2, 200);
    }

    /*****************************************  TEST CASES FOR BATCH BURN SAME ASSET TOKENS  *************************************************/

    // batch burn asset with mismatched arrays expect revert
    function testBatchBurnSameAssetTokensMismatchedArrays() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        address[] memory holders = new address[](2);
        holders[0] = user;
        holders[1] = user2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 300;
        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        controller.batchBurnSameAsset("GOLD", holders, amounts);
        vm.stopPrank();
    }

    // burn unregistered asset expect revert
    function testBatchBurnSameAssetUnregisteredAssetTokens() public {
        vm.startPrank(owner);
        address[] memory holders = new address[](2);
        holders[0] = user;
        holders[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetNotRegistered.selector,
                keccak256(abi.encodePacked("GOLD"))
            )
        );
        controller.batchBurnSameAsset("GOLD", holders, amounts);
        vm.stopPrank();
    }

    // burn asset tokens can not be called by non-owner
    function testBatchBurnSameAssetTokensCanNotCalledByNonOwner() public {
        vm.startPrank(owner);
        controller.registerAsset("GOLD", address(goldToken));
        goldToken.transferOwnership(address(controller));
        vm.stopPrank();
        address[] memory holders = new address[](2);
        holders[0] = user;
        holders[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 400;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user)
        );
        controller.batchBurnSameAsset("GOLD", holders, amounts);
    }
}
