// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Test.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol"; // For safety checks
// import "../src/TokenControllerV1.sol"; 
// import "../src/TokenControllerV2.sol"; 
// import {Upgrades, Options} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

// // Mock token remains the same
// contract MockAssetToken {
//     mapping(address => uint256) public balances;
//     function mint(address to, uint256 amount) external { balances[to] += amount; }
//     function burnFrom(address from, uint256 amount) external { balances[from] -= amount; }
//     function batchMint(address[] calldata tos, uint256[] calldata amounts) external {
//         for (uint256 i = 0; i < tos.length; i++) { balances[tos[i]] += amounts[i]; }
//     }
//     function batchBurn(address[] calldata, uint256[] calldata) external {}
//     function balanceOf(address account) external view returns (uint256) { return balances[account]; }
// }

// contract TokenControllerUpgradeTest is Test {
//     TokenController public controller;
//     ERC1967Proxy public proxy;
    
//     MockAssetToken public goldToken;
//     address public custodyWallet;
//     address public user1;
    
//     function setUp() public {
//         custodyWallet = makeAddr("custodyWallet");
//         user1 = makeAddr("user1");
//         goldToken = new MockAssetToken();
        
//         // 1. Deploy V1 Implementation
//         TokenController implementationV1 = new TokenController();
        
//         // 2. Deploy Proxy and point it to V1, calling initialize()
//         proxy = new ERC1967Proxy(
//             address(implementationV1),
//             abi.encodeWithSelector(TokenController.initialize.selector)
//         );
        
//         // 3. Wrap the proxy address in the V1 interface
//         controller = TokenController(address(proxy));
//     }
    
//     function test_InitialDeployment() public view {
//         assertEq(controller.owner(), address(this));
//     }
    
//     function test_UpgradeToV2() public {
//         // 1. Setup V1 state (Add an asset while on V1)
//         controller.registerAsset("GOLD", address(goldToken), custodyWallet);
        
//         // 2. Deploy V2 Logic
//         TokenControllerV2 implementationV2 = new TokenControllerV2();
        
//         // 3. Perform the upgrade (V1 has the upgradeToAndCall function)
//         controller.upgradeToAndCall(address(implementationV2), "");
        
//         // 4. Re-cast the proxy address to the V2 contract type
//         TokenControllerV2 controllerV2 = TokenControllerV2(address(proxy));
        
//         // 5. Initialize V2 specific variables
//         controllerV2.initializeV2();
        
//         // 6. Verify data from V1 survived the upgrade
//         address tokenAddr = controllerV2.getAssetTokenAddress("GOLD");
//         assertEq(tokenAddr, address(goldToken));
//         assertEq(controllerV2.getVersion(), 2);
        
//         // 7. Test V2 feature
//         controllerV2.setAssetFee("GOLD", 100);
//         assertEq(controllerV2.getAssetFee("GOLD"), 100);
//     }

// //    function test_UpgradeSafety() public {
// //     // We pass the name of the V1 contract and an empty Options struct
// //     Upgrades.validateUpgrade("TokenControllerV1.sol", Upgrades.Options({
// //         referenceContract: "TokenControllerV2.sol"
// //     }));
   
// // }
// }
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/TokenControllerV1.sol"; 
import "../src/TokenControllerV2.sol"; 

contract TokenControllerUpgradeTest is Test {
    TokenController public controller;
    ERC1967Proxy public proxy;
    
    // mock tokens

    function setUp() public {
        // 1. Deploy V1
        TokenController implementationV1 = new TokenController();
        
        // 2. Deploy Proxy pointing to V1
        proxy = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeWithSelector(TokenController.initialize.selector)
        );
        
        controller = TokenController(address(proxy));
    }

    function test_FullUpgradeFlow() public {
        // Register something in V1
        controller.registerAsset("GOLD", address(0x123), address(0x456));

        // Upgrade to V2
        TokenControllerV2 v2Logic = new TokenControllerV2();
        controller.upgradeToAndCall(address(v2Logic), "");

        // Cast to V2 and init
        TokenControllerV2 v2 = TokenControllerV2(address(proxy));
        v2.initializeV2();

        // Verify V1 data is still there
        assertEq(v2.getAssetTokenAddress("GOLD"), address(0x123));
        
        // Verify V2 new functionality
        v2.setAssetFee("GOLD", 500);
        assertEq(v2.getAssetFee("GOLD"), 500);
    }
}