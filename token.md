# 🪙 MyToken – ERC20 with Controller-Based Mint/Burn

## Overview

**MyToken** is an ERC-20 compliant token designed for **custodial and controller-based minting and burning**.
It supports **pausing**, **batch operations**, and **EIP-2612 permits**, making it suitable for **RWA, platform-minted assets, and controlled supply tokens**.

The token separates **ownership** from **mint/burn authority** via a dedicated **controller address** (e.g., a TokenController contract).

---

## Key Features

* ✅ ERC-20 standard compliance
* ✅ Controller-based minting & burning
* ✅ Batch mint & batch burn
* ✅ Emergency pause / unpause
* ✅ EIP-2612 (`permit`) support
* ✅ Owner-controlled administration
* ❌ No user minting
* ❌ No inflation without controller approval

## Roles & Permissions

| Role           | Address                   | Capabilities                         |
| -------------- | ------------------------- | ------------------------------------ |
| **Owner**      | Deployer (or transferred) | Set controller, pause/unpause        |
| **Controller** | Controller contract       | Mint, batchMint, burnFrom, batchBurn |
| **User**       | Token holder              | Transfer, burn own tokens            |

---

## Architecture

```
Owner (Admin)
   │
   ├─ setController()
   ├─ pause() / unpause()
   │
Controller Contract
   │
   ├─ mint()
   ├─ batchMint()
   ├─ burnFrom()
   ├─ batchBurn()
   │
Users
   ├─ transfer()
   ├─ burn()
```

---

## Contract Details

* **Token Standard:** ERC-20
* **Permit Standard:** EIP-2612
* **Compiler:** Solidity `^0.8.24`
* **Libraries:** OpenZeppelin Contracts

---

## Constructor

```solidity
constructor(string memory name, string memory symbol)
```

Initializes:

* Token name
* Token symbol
* Owner = deployer
* Permit domain = token name

---

## State Variables

### `controller`

```solidity
address public controller;
```

The **only address allowed to mint or burn on behalf of users**.
Typically set to a **TokenController** or **custodial contract**.

---

## Modifiers

### `onlyController`

Restricts function access to the configured controller.

```solidity
modifier onlyController()
```

---

## Administrative Functions (Owner Only)

### `setController`

```solidity
function setController(address _controller) external onlyOwner
```

Sets the controller address.

* Reverts if `_controller == address(0)`
* Emits `ControllerUpdated`

---

### `pause`

```solidity
function pause() external onlyOwner
```

Pauses **all token transfers, minting, and burning**.

---

### `unpause`

```solidity
function unpause() external onlyOwner
```

Resumes normal operations.

---

## Minting Functions (Controller Only)

### `mint`

```solidity
function mint(address to, uint256 amount) external onlyController
```

Mints tokens to a single address.

---

### `batchMint`

```solidity
function batchMint(
    address[] calldata tos,
    uint256[] calldata amounts
) external onlyController
```

Mints tokens to multiple addresses in one transaction.

**Requirements**

* `tos.length == amounts.length`
* `tos.length > 0`
* No zero addresses

---

## Burning Functions

### `burn` (User)

```solidity
function burn(uint256 amount) public
```

Allows users to burn their **own tokens**.

---

### `burnFrom` (Controller)

```solidity
function burnFrom(address from, uint256 amount) external onlyController
```

Burns tokens from a user address **without approval**.

Used for:

* Redemptions
* Compliance actions
* Custodial settlements

---

### `batchBurn` (Controller)

```solidity
function batchBurn(
    address[] calldata froms,
    uint256[] calldata amounts
) external onlyController
```

Burns tokens from multiple addresses in one transaction.

**Requirements**

* `froms.length == amounts.length`
* `froms.length > 0`
* No zero addresses

---

## Pause Behavior

When paused:

* ❌ Transfers blocked
* ❌ Minting blocked
* ❌ Burning blocked
* ❌ Batch operations blocked

Enforced via `ERC20Pausable`.

---

## Permit (EIP-2612)

This token supports **gasless approvals** via `permit()`.

```solidity
permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
)
```

Useful for:

* Gasless UX
* Relayers
* Meta-transactions

---

## Events

### `ControllerUpdated`

```solidity
event ControllerUpdated(
    address indexed oldController,
    address indexed newController
);
```

Emitted when controller address changes.

---

## Errors

| Error              | Description              |
| ------------------ | ------------------------ |
| `ZeroAddress()`    | Zero address provided    |
| `NotController()`  | Caller is not controller |
| `LengthMismatch()` | Array length mismatch    |
| `EmptyArray()`     | Empty batch array        |

---

## Security Considerations

* ⚠️ **Controller is highly privileged**
* 🔐 Protect controller with:

  * MPC wallet
  * Timelock
  * Upgradeable controller contract
* 🚨 Pausing halts all operations
* 🧪 Batch operations should be gas-tested

---

## Intended Use Cases

* RWA tokens (gold, commodities, invoices)
* Custodial platforms
* Platform-issued credits
* Regulated token issuance
* Bridge-controlled minting

---

## Integration Notes

* Always set controller **after deployment**
* Do **not** expose controller private key
* Prefer a contract-based controller
* Use Tenderly / Foundry for simulation before minting

---

## License

MIT
