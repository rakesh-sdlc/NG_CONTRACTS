// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title TokenController
 * @author Rakesh Kumar Barik
 * @notice Upgradeable ERC20 token controller for managing multiple ERC20 tokens
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAssetToken {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function batchMint(address[] calldata tos, uint256[] calldata amounts) external;
    function batchBurn(address[] calldata froms, uint256[] calldata amounts) external;
}

contract TokenController is 
    Initializable,
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // -------------------------
    // STATE VARIABLES
    // -------------------------
    struct Asset {
        address token;
        address custodyWallet;
        bool exists;
    }

    mapping(bytes32 => Asset) private assets;
    bytes32[] private assetIds;
    // -------------------------
    // EVENTS
    // -------------------------
    event AssetRegistered(bytes32 indexed assetId, string assetName, address token, address custodyWallet);
    event AssetUnregistered(bytes32 indexed assetId, string assetName);
    event CustodyWalletUpdated(bytes32 indexed assetId, address oldWallet, address newWallet);
    event MintPerformed(bytes32 indexed assetId, address indexed to, uint256 amount, address indexed operator);
    event BurnPerformed(bytes32 indexed assetId, address indexed from, uint256 amount, address indexed operator);
    event BatchMintPerformed(bytes32 indexed assetId, uint256 totalAmount, address indexed operator);
    event BatchBurnPerformed(bytes32 indexed assetId, uint256 totalAmount, address indexed operator);

    // -------------------------
    // ERRORS
    // -------------------------
    error AssetAlreadyRegistered(bytes32 assetId);
    error AssetNotRegistered(bytes32 assetId);
    error ZeroAddress();
    error InvalidAssetName();
    error LengthMismatch();

    // -------------------------
    // CONSTRUCTOR & INITIALIZER
    // -------------------------
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init(); 
        __UUPSUpgradeable_init();
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
    // ADMIN: REGISTER / UNREGISTER
    // -------------------------
    
    function registerAsset(
        string calldata assetName,
        address token,
        address custodyWallet
    ) external onlyOwner whenNotPaused {
        if (bytes(assetName).length == 0) revert InvalidAssetName();
        if (token == address(0) || custodyWallet == address(0)) revert ZeroAddress();

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

        delete assets[id];

        uint256 len = assetIds.length;
        for (uint256 i = 0; i < len; ++i) {
            if (assetIds[i] == id) {
                assetIds[i] = assetIds[len - 1];
                assetIds.pop();
                break;
            }
        }

        emit AssetUnregistered(id, assetName);
    }

    function changeCustodyWallet(
        string calldata assetName,
        address newWallet
    ) external onlyOwner whenNotPaused {
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

    function listAllAssets() external view returns (bytes32[] memory) {
        return assetIds;
    }

    // -------------------------
    // MINT / BURN
    // -------------------------
    
    function mint(
        string calldata assetName,
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();

        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).mint(to, amount);

        emit MintPerformed(id, to, amount, msg.sender);
    }

    function mintToCustodyWallet(
        string calldata assetName,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).mint(A.custodyWallet, amount);

        emit MintPerformed(id, A.custodyWallet, amount, msg.sender);
    }

    function burn(
        string calldata assetName,
        address from,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        if (from == address(0)) revert ZeroAddress();

        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).burnFrom(from, amount);

        emit BurnPerformed(id, from, amount, msg.sender);
    }

    function burnFromCustodyWallet(
        string calldata assetName,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        (bytes32 id, Asset memory A) = _getAsset(assetName);
        IAssetToken(A.token).burnFrom(A.custodyWallet, amount);

        emit BurnPerformed(id, A.custodyWallet, amount, msg.sender);
    }

    // -------------------------
    // BATCH OPERATIONS
    // -------------------------
    
    function batchMint(
        string calldata assetName,
        address[] calldata tos,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 len = tos.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        (bytes32 id, Asset memory A) = _getAsset(assetName);

        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            unchecked { total += amounts[i]; }
        }

        IAssetToken(A.token).batchMint(tos, amounts);
        emit BatchMintPerformed(id, total, msg.sender);
    }

    function batchBurn(
        string calldata assetName,
        address[] calldata froms,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 len = froms.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        (bytes32 id, Asset memory A) = _getAsset(assetName);

        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            unchecked { total += amounts[i]; }
        }

        IAssetToken(A.token).batchBurn(froms, amounts);
        emit BatchBurnPerformed(id, total, msg.sender);
    }

    // -------------------------
    // PAUSE/UNPAUSE
    // -------------------------
    
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // -------------------------
    // UPGRADE AUTHORIZATION
    // -------------------------
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    uint256[50] private __gap;

}