# 🧩 TokenController – Multi-Asset ERC20 Mint/Burn Controller
Overview

**TokenController** is an administrative smart contract designed to manage minting and burning of multiple ERC-20 tokens in a controlled and auditable manner.

It acts as a central authority (controller) for multiple asset tokens, enabling:

Controlled minting & burning

Custody wallet mint/burn

Batch operations

Emergency pause

Reentrancy protection

## Key Features

✅ Supports multiple ERC20 assets

✅ Centralized mint & burn authority

✅ Custody wallet support (vault / MPC / treasury)

✅ Batch mint & batch burn

✅ Emergency pause

✅ Reentrancy protection

❌ No user-level permissions

❌ No on-chain pricing or oracle logic

High-Level Architecture
Owner (Admin / MPC / Timelock)
        │
        ├─ registerAsset()
        ├─ mint / burn
        ├─ batchMint / batchBurn
        ├─ changeCustodyWallet()
        │
TokenController
        │
        ├─ mint()
        ├─ burnFrom()
        │
ERC20 Asset Tokens
        │
        └─ User balances

Roles & Permissions
Role	Who	Permissions
Owner	Admin / MPC / DAO	Register assets, mint, burn, pause
Controller	This contract	Calls mint/burn on token contracts
User	Token holders	No direct access