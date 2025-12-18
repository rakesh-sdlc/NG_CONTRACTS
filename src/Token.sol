// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title TokenContract
 * @author Rakesh Kumar Barik
 * @notice This contract implements a simple ERC20 token with minting, burning, pausing, and unpausing functionalities.
 */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyToken is ERC20, Ownable, ERC20Pausable, ERC20Permit {
    address public controller;

    // -----------------------------
    // Modifiers
    // -----------------------------
    modifier onlyController() {
        if (msg.sender != controller) {
            revert NotController();
        }
        _;
    }

    // -----------------------------
    // Events
    // -----------------------------
    event ControllerUpdated(address indexed oldController, address indexed newController);

    // -----------------------------
    // Errors
    // -----------------------------
    error ZeroAddress();
    error NotController();
    error LengthMismatch();
    error EmptyArray();

    // -----------------------------
    // Constructor
    // -----------------------------

    constructor(string memory name, string memory symbol) Ownable(msg.sender) ERC20(name, symbol) ERC20Permit(name) {}

    // -----------------------------
    // Functions
    // -----------------------------

    function setController(address _controller) external onlyOwner {
        if (_controller == address(0)) {
            revert ZeroAddress();
        }
        address old = controller;
        controller = _controller;
        emit ControllerUpdated(old, _controller);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyController {
        _mint(to, amount);
    }

    function batchMint(address[] calldata tos, uint256[] calldata amounts) external onlyController {
        uint256 len = tos.length;
        if (len != amounts.length) revert LengthMismatch();
        if (len == 0) revert EmptyArray();

        for (uint256 i = 0; i < len; ++i) {
            address to = tos[i];
            if (to == address(0)) revert ZeroAddress();

            _mint(to, amounts[i]);
        }
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyController {
        _burn(from, amount);
    }

    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external onlyController {
        uint256 len = froms.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < len; ++i) {
            address from = froms[i];
            if (from == address(0)) revert ZeroAddress();

            _burn(from, amounts[i]);
        }
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
