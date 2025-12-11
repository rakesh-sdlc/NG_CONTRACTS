// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * @title TokenContractController
 * @author Rakesh Kumar Barik
 * @notice This contract implements a simple ERC20 token controller for managing multiple ERC20 tokens.
 */

/// @notice Production-ready TokenController for Phase-1 custodial model
/// - Controls minting/burning for multiple ERC20 tokens (Gold, Silver, Diamond...)
/// - Owner (admin) manages asset registry, custody wallet, pausing and emergency recovery
/// - This contract DOES NOT assume token implementation details beyond `mint(address,uint256)` and `burn(address,uint256)`
/// - For safety, tokens should restrict mint/burn to a role (e.g. TOKEN_CONTROLLER_ROLE) and that role must be granted to this controller.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAssetToken {
    // expected token interface for Phase-1 asset tokens
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function batchMint(
        address[] calldata tos,
        uint256[] calldata amounts
    ) external;
    function batchBurn(
        address[] calldata froms,
        uint256[] calldata amounts
    ) external;
}

contract TokenController is Ownable, ReentrancyGuard, Pausable {
    /// @notice asset id (bytes32) => token contract address
    mapping(bytes32 => address) private _assetToken;

    /// @notice list of all registered asset ids (for enumeration)
    bytes32[] private _assetList;
    mapping(bytes32 => uint256) private _assetIndex; // 1-based index; 0 = not present

    /// @notice custody wallet receives minted tokens (platform's safe/MPC)
    address public custodyWallet;

    /// Events
    event AssetRegistered(
        bytes32 indexed assetId,
        string assetName,
        address token
    );
    event AssetUnregistered(
        bytes32 indexed assetId,
        string assetName,
        address token
    );
    event CustodyWalletUpdated(
        address indexed oldWallet,
        address indexed newWallet
    );
    event MintPerformed(
        bytes32 indexed assetId,
        address indexed to,
        uint256 amount,
        address indexed operator
    );
    event BurnPerformed(
        bytes32 indexed assetId,
        address indexed from,
        uint256 amount,
        address indexed operator
    );
    event BatchMintPerformed(
        bytes32 indexed assetId,
        address indexed operator,
        uint256 totalAmount
    );
    event BatchBurnPerformed(
        bytes32 indexed assetId,
        address indexed operator,
        uint256 totalAmount
    );
    event EmergencyERC20Recovered(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// Errors (cheaper than strings)
    error AssetNotRegistered(bytes32 assetId);
    error AssetAlreadyRegistered(bytes32 assetId);
    error ZeroAddress();
    error InvalidAssetName();
    error LengthMismatch();
    error InvalidArrayLength();
    error NotAllowed();

    constructor(address initialCustodyWallet) Ownable(msg.sender) {
        if (initialCustodyWallet == address(0)) revert ZeroAddress();
        custodyWallet = initialCustodyWallet;
    }

    // -----------------------------
    // Registration / admin
    // -----------------------------

    /// @notice Register an asset (e.g. "GOLD") and point to its token contract.
    /// @dev assetName is for indexing / events. assetId = keccak256(abi.encodePacked(assetName))
    function registerAsset(
        string calldata assetName,
        address token
    ) external onlyOwner whenNotPaused {
        if (bytes(assetName).length == 0) revert InvalidAssetName();
        if (token == address(0)) revert ZeroAddress();
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        if (_assetIndex[assetId] != 0) revert AssetAlreadyRegistered(assetId);

        _assetToken[assetId] = token;
        _assetList.push(assetId);
        _assetIndex[assetId] = _assetList.length; // 1-based

        emit AssetRegistered(assetId, assetName, token);
    }

    /// @notice Unregister an asset. Use with caution.
    function unregisterAsset(
        string calldata assetName
    ) external onlyOwner whenNotPaused {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        uint256 idx = _assetIndex[assetId];
        if (idx == 0) revert AssetNotRegistered(assetId);

        address token = _assetToken[assetId];

        // remove mapping & array (swap & pop)
        uint256 lastIndex = _assetList.length;
        bytes32 lastAsset = _assetList[lastIndex - 1];

        if (idx != lastIndex) {
            _assetList[idx - 1] = lastAsset;
            _assetIndex[lastAsset] = idx;
        }

        _assetList.pop();
        delete _assetIndex[assetId];
        delete _assetToken[assetId];

        emit AssetUnregistered(assetId, assetName, token);
    }

    function getAssetTokenAddress(
        string calldata assetName
    ) external view returns (address) {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address token = _assetToken[assetId];
        if (token == address(0)) revert AssetNotRegistered(assetId);
        return token;
    }

    function listAssets() external view returns (bytes32[] memory) {
        return _assetList;
    }

    // -----------------------------
    // Custody & safety
    // -----------------------------

    function setCustodyWallet(
        address newCustody
    ) external onlyOwner whenNotPaused {
        if (newCustody == address(0)) revert ZeroAddress();
        address old = custodyWallet;
        custodyWallet = newCustody;
        emit CustodyWalletUpdated(old, newCustody);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // -----------------------------
    // Mint / Burn single
    // -----------------------------

    /// @notice Mint tokens of specified asset to the custody wallet OR a target address.
    /// @dev Operator (msg.sender) should be the controller owner or an authorized backend account.
    ///      The token contract should restrict mint permission to this controller (recommended).
    function mint(
        string calldata assetName,
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address token = _assetToken[assetId];
        if (token == address(0)) revert AssetNotRegistered(assetId);
        if (to == address(0)) revert ZeroAddress();

        // call token.mint(to, amount)
        IAssetToken(token).mint(to, amount);

        emit MintPerformed(assetId, to, amount, msg.sender);
    }

    /// @notice Burn tokens of a specified asset from a given address.
    /// @dev The token's burn() implementation must be compatible (e.g. only callable by controller).
    function burn(
        string calldata assetName,
        address from,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address token = _assetToken[assetId];
        if (token == address(0)) revert AssetNotRegistered(assetId);
        if (from == address(0)) revert ZeroAddress();

        IAssetToken(token).burnFrom(from, amount);

        emit BurnPerformed(assetId, from, amount, msg.sender);
    }

    // -----------------------------
    // Batch operations
    // -----------------------------

    /// @notice Batch mint: same asset to many recipients
    function batchMintSameAsset(
        string calldata assetName,
        address[] calldata tos,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 len = tos.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address token = _assetToken[assetId];
        if (token == address(0)) revert AssetNotRegistered(assetId);

        // Calculate total amount (optional but useful)
        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            unchecked {
                total += amounts[i];
            }
        }

        // **Call the token’s batch mint (1 external call!)**
        IAssetToken(token).batchMint(tos, amounts);

        emit BatchMintPerformed(assetId, msg.sender, total);
    }

    /// @notice Batch burn many (same asset)
    function batchBurnSameAsset(
        string calldata assetName,
        address[] calldata froms,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 len = froms.length;
        if (len == 0 || len != amounts.length) revert LengthMismatch();

        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address token = _assetToken[assetId];
        if (token == address(0)) revert AssetNotRegistered(assetId);

        uint256 total;
        for (uint256 i = 0; i < len; ++i) {
            unchecked {
                total += amounts[i];
            }
        }

        IAssetToken(token).batchBurn(froms, amounts);

        emit BatchBurnPerformed(assetId, msg.sender, total);
    }

    // -----------------------------
    // Helpers / view
    // -----------------------------

    function getAddressOfAssetToken(
        string calldata assetName
    ) public view returns (address) {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        return _assetToken[assetId];
    }

    function getAssetId(
        string calldata assetName
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(assetName));
    }

    function checkAssetRegistered(
        string calldata assetName
    ) external view returns (bool) {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        return _assetIndex[assetId] != 0;
    }

    function totalSupplyOfAsset(
        string calldata assetName
    ) external view returns (uint256) {
        bytes32 assetId = keccak256(abi.encodePacked(assetName));
        address t = _assetToken[assetId];
        if (t == address(0)) revert AssetNotRegistered(assetId);
        return IERC20(t).totalSupply();
    }

    // -----------------------------
    // Emergency / recovery
    // -----------------------------

    /// @notice Recover ERC20 tokens accidentally sent to this controller (not the asset tokens)
    // function recoverERC20(
    //     address tokenAddress,
    //     address to,
    //     uint256 amount
    // ) external onlyOwner nonReentrant {
    //     if (to == address(0)) revert ZeroAddress();
    //     IERC20(tokenAddress).transfer(to, amount);
    //     emit EmergencyERC20Recovered(tokenAddress, to, amount);
    // }

    /// @notice Batch burn multiple assets (parallel arrays)
    // function batchBurnMultipleAssets(
    //     string[] calldata assets,
    //     address[] calldata froms,
    //     uint256[] calldata amounts
    // ) external onlyOwner whenNotPaused nonReentrant {
    //     uint256 len = assets.length;
    //     if (len == 0 || froms.length != len || amounts.length != len)
    //         revert LengthMismatch();

    //     for (uint256 i = 0; i < len; ++i) {
    //         bytes32 assetId = keccak256(abi.encodePacked(assets[i]));
    //         address token = _assetToken[assetId];
    //         if (token == address(0)) revert AssetNotRegistered(assetId);
    //         address from = froms[i];
    //         uint256 amt = amounts[i];
    //         if (from == address(0)) revert ZeroAddress();
    //         IAssetToken(token).burn(from, amt);
    //         emit BurnPerformed(assetId, from, amt, msg.sender);
    //     }
    // }

    // @notice Batch mint multiple assets to multiple recipients.
    // @dev assets.length == tos.length == amounts.length
    // function batchMintMultipleAssets(
    //     string[] calldata assets,
    //     address[] calldata tos,
    //     uint256[] calldata amounts
    // ) external onlyOwner whenNotPaused nonReentrant {
    //     uint256 len = assets.length;
    //     if (len == 0 || tos.length != len || amounts.length != len)
    //         revert LengthMismatch();

    //     uint256 total = 0;
    //     for (uint256 i = 0; i < len; ++i) {
    //         bytes32 assetId = keccak256(abi.encodePacked(assets[i]));
    //         address token = _assetToken[assetId];
    //         if (token == address(0)) revert AssetNotRegistered(assetId);
    //         address to = tos[i];
    //         uint256 amt = amounts[i];
    //         if (to == address(0)) revert ZeroAddress();
    //         IAssetToken(token).mint(to, amt);
    //         total += amt;
    //         emit MintPerformed(assetId, to, amt, msg.sender);
    //     }

    //     // Emit a summary event (optional)
    //     // Note: individual MintPerformed events were emitted above.
    // }
}
