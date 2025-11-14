# StackFund - Enhanced Crowdfunding Contract for Stacks

A robust, production-ready crowdfunding smart contract built on the Stacks blockchain. StackFund enables creators to launch campaigns, receive contributions, and manage funds with built-in platform fees, refund mechanisms, and campaign management features.

## Features

### Core Functionality
- **Create Campaigns**: Launch crowdfunding campaigns with customizable goals, deadlines, and categories
- **Contribute**: Donors can contribute STX to active campaigns
- **Withdraw Funds**: Campaign creators can withdraw funds once the goal is reached
- **Refunds**: Failed campaigns automatically refund contributors after the deadline
- **Cancel Campaigns**: Creators can cancel campaigns before the deadline
- **Update Campaigns**: Modify campaign goals and extend deadlines before expiration

### Advanced Features
- **Platform Fee System**: Automatic 3% fee deducted from successful withdrawals
- **Top Donor Tracking**: Identifies and tracks the largest contributor to each campaign
- **Campaign Categories**: Organize campaigns by category (e.g., "Tech", "Arts", "Social")
- **Contribution History**: Complete tracking of all donations per donor per campaign
- **State Management**: Campaigns track status (active, successful, withdrawn, canceled)

## Contract Architecture

### Data Structures

#### Campaigns Map
```clarity
campaigns (id → {
  creator: principal,
  title: string (64 chars),
  description: string (256 chars),
  goal: uint (STX amount in microSTX),
  deadline: uint (block height),
  funds-raised: uint,
  withdrawn: bool,
  successful: bool,
  category: string (32 chars),
  top-donor: optional principal,
  top-donation: uint
})
```
---

### `contribute`
Contribute STX to an active campaign.

**Parameters:**
- `campaign-id` (uint): Target campaign ID

**Returns:** `(ok true)` or error

**Requirements:**
- Campaign must exist and be active (before deadline)
- Must transfer STX in the transaction

**Example:**
```clarity
(stx-transfer? u1000000 tx-sender .stackfund)
(contract-call? .stackfund contribute u1)
```

---

### `withdraw-funds`
Withdraw funds from a successful campaign (creator only).

**Parameters:**
- `campaign-id` (uint): Campaign to withdraw from

**Returns:** `(ok (tuple (withdrawn uint) (fee uint)))` or error

**Requirements:**
- Caller must be the campaign creator
- Campaign goal must be reached
- Funds must not already be withdrawn
- Platform fee (3%) automatically deducted
;; Returns: (ok (tuple (refunded 1000000)))
```
```

---

### `get-total-campaigns`
Get the total number of campaigns created.

```clarity
(contract-call? .stackfund get-total-campaigns)
```

---

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_NOT_CREATOR` | Caller is not the campaign creator |
| 101 | `ERR_INVALID_AMOUNT` | Goal or duration must be greater than 0 |
| 102 | `ERR_GOAL_NOT_REACHED` | Campaign goal was not met |
| 103 | `ERR_ALREADY_WITHDRAWN` | Funds have already been withdrawn |
| 104 | `ERR_NOT_FUNDED` | Caller has no contributions to refund |
| 105 | `ERR_REFUND_NOT_AVAILABLE` | Refund window not available |
| 106 | `ERR_CAMPAIGN_NOT_FOUND` | Campaign ID does not exist |
| 107 | `ERR_CAMPAIGN_ACTIVE` | Campaign is still active |
| 108 | `ERR_INVALID_CATEGORY` | Invalid campaign category |
| 109 | `ERR_NOT_OWNER` | Caller is not the platform owner |

---

---

## Installation & Deployment

### Prerequisites
- Clarinet 1.0+
- Stacks testnet or mainnet account
- STX for deployment and testing

### Deploy to Testnet
```bash
clarinet contract deploy --network testnet
```

### Deploy to Mainnet
```bash
clarinet contract deploy --network mainnet
```

---

## Testing

Run the included unit tests:

```bash
clarinet test
```



**Version**: 1.0.0  
**Last Updated**: November 14, 2025  
**Clarity Version**: 3.0+
