// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title TokenContractController
 * @author Rakesh Kumar Barik
 * @notice This contract implements a simple ERC20 token controller for managing multiple ERC20 tokens.
 */

import {MyToken} from "../src/Token.sol";
import {TokenController} from "../src/TokenControllerAdvanced.sol";
import {Test} from "forge-std/Test.sol";

contract TokenControllerAdvancedTest is Test {
    TokenController private tokenController;
    MyToken private goldToken;
    MyToken private silverToken;
    address private owner = makeAddr("owner");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private GOLD_CUSTODY_WALLET = makeAddr("gold_custody");
    address private SILVER_CUSTODY_WALLET = makeAddr("silver_custody");

    function setUp() public {
        vm.startPrank(owner);
        tokenController = new TokenController();
        goldToken = new MyToken("GOLDTOKEN", "GOLD");
        silverToken = new MyToken("SILVERTOKEN", "SILVER");
        tokenController.registerAsset(
            "GOLD",
            address(goldToken),
            GOLD_CUSTODY_WALLET
        );
        tokenController.registerAsset(
            "SILVER",
            address(silverToken),
            SILVER_CUSTODY_WALLET
        );

        goldToken.setController(address(tokenController));
        silverToken.setController(address(tokenController));
        vm.stopPrank();
    }
}
