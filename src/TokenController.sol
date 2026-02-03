// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title TokenContractController
 * @author Rakesh Kumar Barik
 * @notice This contract implements a simple ERC20 token controller for managing multiple ERC20 tokens.
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IAssetToken {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function batchMint(address[] calldata tos, uint256[] calldata amounts) external;
    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external;
}

contract TokenController is Ownable, Pausable, ReentrancyGuard {
    // -------------------------
    // Asset struct & storage
    // -------------------------
    struct Asset {
        address token; // ERC20 token address
        address custodyWallet; // vault / MPC / staking wallet
        bool exists; // simplifies checks
    }

    mapping(bytes32 => Asset) private assets;
    bytes32[] private assetIds; // optional enumeration

    // -------------------------
    // Events
    // -------------------------
    event AssetRegistered(bytes32 indexed assetId, string assetName, address token, address custodyWallet);
    event AssetUnregistered(bytes32 indexed assetId, string assetName, address token);
    event CustodyWalletUpdated(bytes32 indexed assetId, address oldWallet, address newWallet);

    event MintPerformed(bytes32 indexed assetId, address indexed to, uint256 amount, address indexed operator);
    event BurnPerformed(bytes32 indexed assetId, address indexed from, uint256 amount, address indexed operator);

    event BatchMintPerformed(bytes32 indexed assetId, uint256 totalAmount, address indexed operator);
    event BatchBurnPerformed(bytes32 indexed assetId, uint256 totalAmount, address indexed operator);

    // -------------------------
    // Errors
    // -------------------------
    error AssetAlreadyRegistered(bytes32 assetId);
    error AssetNotRegistered(bytes32 assetId);
    error ZeroAddress();
    error InvalidAssetName();
    error LengthMismatch();
    error EmptyArray();

    // -------------------------
    // Constructor
    // -------------------------

    constructor() Ownable(msg.sender) {}

    // -------------------------
    // Pause / Unpause
    // -------------------------

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // -------------------------
    // INTERNAL HELPERS
    // -------------------------

    function _getAsset(string calldata name) internal view returns (bytes32 id, Asset memory A) {
        id = keccak256(abi.encodePacked(name));
        A = assets[id];
        if (!A.exists) revert AssetNotRegistered(id);
    }

    // -------------------------
    // ADMIN: Register / Unregister
    // -------------------------

    function registerAsset(string calldata assetName, address token, address custodyWallet)
        external
        onlyOwner
        whenNotPaused
    {
        if (bytes(assetName).length == 0) revert InvalidAssetName();
        if (token == address(0) || custodyWallet == address(0)) {
            revert ZeroAddress();
        }

        bytes32 id = keccak256(abi.encodePacked(assetName));
        if (assets[id].exists) revert AssetAlreadyRegistered(id);

        assets[id] = Asset({token: token, custodyWallet: custodyWallet, exists: true});

        assetIds.push(id);

        emit AssetRegistered(id, assetName, token, custodyWallet);
    }

    function unregisterAsset(string calldata assetName) external onlyOwner whenNotPaused {
        bytes32 id = keccak256(abi.encodePacked(assetName));
        Asset memory A = assets[id];
        if (!A.exists) revert AssetNotRegistered(id);

        // remove from mapping
        delete assets[id];

        // remove from array (swap & pop)
        uint256 len = assetIds.length;
        for (uint256 i = 0; i < len; ++i) {
            if (assetIds[i] == id) {
                assetIds[i] = assetIds[len - 1];
                assetIds.pop();
                break;
            }
        }

        emit AssetUnregistered(id, assetName, A.token);
    }

    // -------------------------
    // ADMIN: Custody Wallet Update
    // -------------------------

    function changeCustodyWallet(string calldata assetName, address newWallet) external onlyOwner whenNotPaused {
        if (newWallet == address(0)) revert ZeroAddress();

        (bytes32 id, Asset memory A) = _getAsset(assetName);

        address old = A.custodyWallet;
        assets[id].custodyWallet = newWallet;

        emit CustodyWalletUpdated(id, old, newWallet);
    }

    // -------------------------
    // GETTERS
    // -------------------------

    function getAssetTokenAddress(string calldata assetName) external view returns (address) {
        (, Asset memory A) = _getAsset(assetName);
        return A.token;
    }

    function listAllAssets() public view returns (bytes32[] memory) {
        return assetIds;
    }

    function getAsset(bytes32 id) external view returns (address token, address custodyWallet, bool exists) {
        Asset memory a = assets[id];
        return (a.token, a.custodyWallet, a.exists);
    }

    function getAssetId(uint256 index) external view returns (bytes32) {
        return assetIds[index];
    }

    function getAssetCount() external view returns (uint256) {
        return assetIds.length;
    }

    // -------------------------
    // SINGLE MINT / BURN
    // -------------------------

    /// Mint to arbitrary address (not custody wallet)
    function mint(string calldata assetName, address to, uint256 amount) external onlyOwner whenNotPaused {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).mint(to, amount);
        emit MintPerformed(id, to, amount, msg.sender);
    }

    /// Mint only to custody wallet
    function mintToCustodyWallet(string calldata assetName, uint256 amount) external onlyOwner whenNotPaused {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).mint(A.custodyWallet, amount);
        emit MintPerformed(id, A.custodyWallet, amount, msg.sender);
    }

    function burn(string calldata assetName, address from, uint256 amount)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).burnFrom(from, amount);
        emit BurnPerformed(id, from, amount, msg.sender);
    }

    /// Burn tokens from custody wallet
    function burnFromCustodyWallet(string calldata assetName, uint256 amount)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).burnFrom(A.custodyWallet, amount);

        emit BurnPerformed(id, A.custodyWallet, amount, msg.sender);
    }

    // -------------------------
    // BATCH MINT / BATCH BURN
    // -------------------------

    function batchMint(string calldata assetName, address[] calldata tos, uint256[] calldata amounts)
        external
        onlyOwner
        whenNotPaused
    {
        uint256 len = tos.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        (bytes32 id, Asset memory A) = _getAsset(assetName);

        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            unchecked {
                total += amounts[i];
            }
        }

        IAssetToken(A.token).batchMint(tos, amounts);

        emit BatchMintPerformed(id, total, msg.sender);
    }

    function batchBurn(string calldata assetName, address[] calldata froms, uint256[] calldata amounts)
        external
        onlyOwner
        whenNotPaused
    {
        uint256 len = froms.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        (bytes32 id, Asset memory A) = _getAsset(assetName);

        uint256[] calldata _amounts = amounts;
        uint256 total;
        for (uint256 i; i < len;) {
            unchecked {
                total += _amounts[i];
                ++i;
            }
        }

        IAssetToken(A.token).batchBurn(froms, amounts);

        emit BatchBurnPerformed(id, total, msg.sender);
    }
}
