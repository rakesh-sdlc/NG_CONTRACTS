// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TokenControllerV1.sol";

/*
 * @title TokenControllerV2
 * @notice Version 2 with fee management features
 */
contract TokenControllerV2 is TokenController {
    
    // -------------------------
    // NEW STATE VARIABLES (at the END!)
    // -------------------------
    mapping(bytes32 => uint256) public assetFees;
    uint256 public version;
    
    // -------------------------
    // NEW EVENTS
    // -------------------------
    event AssetFeeSet(bytes32 indexed assetId, uint256 fee);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // -------------------------
    // V2 INITIALIZATION
    // -------------------------
    
    function initializeV2() external onlyOwner {
        require(version == 0, "Already initialized V2");
        version = 2;
    }
    
    // -------------------------
    // NEW FUNCTIONS
    // -------------------------
    
    function setAssetFee(
        string calldata assetName,
        uint256 fee
    ) external onlyOwner whenNotPaused {
        // Verify asset exists
        this.getAssetTokenAddress(assetName);
        
        bytes32 id = keccak256(abi.encodePacked(assetName));
        assetFees[id] = fee;
        
        emit AssetFeeSet(id, fee);
    }
    
    function getAssetFee(string calldata assetName) external view returns (uint256) {
        bytes32 id = keccak256(abi.encodePacked(assetName));
        return assetFees[id];
    }
    
    function getVersion() external view returns (uint256) {
        return version == 0 ? 1 : version;
    }
}