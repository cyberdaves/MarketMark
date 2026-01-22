# MarketMark - Commodity Prediction Market

A decentralized prediction market platform built on the Stacks blockchain for forecasting commodity price thresholds. Users can create markets and stake STX tokens on whether commodities like gold, oil, or other assets will be above or below a specified price threshold at a future date.

## Overview

MarketMark allows users to:
- Create prediction markets for any commodity with custom price thresholds
- Stake STX tokens on price predictions (above or below threshold)
- Earn proportional rewards from the total pool if their prediction is correct
- Participate in decentralized price forecasting

## Features

### Market Creation
- Define commodity type (gold, oil, wheat, etc.)
- Set price threshold for predictions
- Specify resolution timeframe in blocks
- Automatic market lifecycle management

### Predictions
- Binary outcomes: price above or below threshold
- Minimum stake requirement (default: 1 STX)
- One prediction per user per market
- Stakes held securely in contract

### Resolution & Rewards
- Owner-resolved markets using actual price data
- Winning side shares the entire pool proportionally
- Automatic reward calculation based on stake size
- Claim rewards after market resolution

## Contract Functions

### Read-Only Functions

#### `get-market (market-id uint)`
Returns all information about a specific market.

```clarity
(get-market u1)
```

#### `get-prediction (market-id uint) (predictor principal)`
Returns a user's prediction details for a specific market.

```clarity
(get-prediction u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

#### `get-market-count`
Returns the total number of markets created.

```clarity
(get-market-count)
```

#### `get-min-stake`
Returns the minimum stake required to make a prediction.

```clarity
(get-min-stake)
```

#### `calculate-potential-reward (market-id uint) (predictor principal)`
Calculates potential reward for a user if their prediction wins.

```clarity
(calculate-potential-reward u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Public Functions

#### `create-market`
Creates a new prediction market.

```clarity
(contract-call? .marketmark create-market 
  "GOLD" 
  u200000  ;; threshold price (e.g., $2000.00 in cents)
  u144     ;; duration in blocks (~24 hours)
)
```

**Parameters:**
- `commodity` (string-ascii 20): Name of the commodity
- `threshold-price` (uint): Price threshold for predictions
- `duration-blocks` (uint): Number of blocks until resolution

**Returns:** Market ID

#### `make-prediction`
Stake tokens on a price prediction.

```clarity
(contract-call? .marketmark make-prediction 
  u1        ;; market-id
  u1        ;; prediction (u1 = above, u2 = below)
  u5000000  ;; stake amount in microSTX (5 STX)
)
```

**Parameters:**
- `market-id` (uint): ID of the market
- `prediction` (uint): u1 for above threshold, u2 for below threshold
- `stake-amount` (uint): Amount of STX to stake (in microSTX)

#### `resolve-market`
Resolves a market with the actual final price (owner only).

```clarity
(contract-call? .marketmark resolve-market 
  u1       ;; market-id
  u205000  ;; final price (e.g., $2050.00)
)
```

**Parameters:**
- `market-id` (uint): ID of the market to resolve
- `final-price` (uint): Actual final price of the commodity

**Returns:** Boolean indicating if price was above threshold

#### `claim-reward`
Claims reward after market resolution (if prediction was correct).

```clarity
(contract-call? .marketmark claim-reward u1)
```

**Parameters:**
- `market-id` (uint): ID of the resolved market

#### `close-market`
Manually closes a market (owner only).

```clarity
(contract-call? .marketmark close-market u1)
```

#### `update-min-stake`
Updates the minimum stake requirement (owner only).

```clarity
(contract-call? .marketmark update-min-stake u2000000)
```

## Market Lifecycle

1. **Active**: Market is created and accepting predictions
2. **Closed**: Market manually closed or duration expired
3. **Resolved**: Final price submitted, winners can claim rewards

## Reward Calculation

Rewards are distributed proportionally based on stake size:

```
User Reward = (User Stake × Total Pool) ÷ Winning Pool
```

**Example:**
- Total pool: 100 STX (60 above, 40 below)
- Final price: Above threshold
- User staked 10 STX on "above"
- User reward: (10 × 100) ÷ 60 = 16.67 STX

## Constants

### Status Types
- `status-active` (u1): Market accepting predictions
- `status-closed` (u2): Market closed
- `status-resolved` (u3): Market resolved with final price

### Prediction Types
- `predict-above` (u1): Predict price will be above threshold
- `predict-below` (u2): Predict price will be below threshold

### Error Codes
- `err-owner-only` (u100): Function restricted to contract owner
- `err-not-found` (u101): Market or prediction not found
- `err-already-exists` (u102): Prediction already made
- `err-market-closed` (u103): Market is closed
- `err-market-not-resolved` (u104): Market not yet resolved
- `err-invalid-prediction` (u105): Invalid prediction parameters
- `err-insufficient-stake` (u106): Stake below minimum
- `err-already-claimed` (u107): Reward already claimed
- `err-market-active` (u108): Market still active

## Usage Example

### Creating and Participating in a Market

```clarity
;; 1. Create a market for gold price prediction
(contract-call? .marketmark create-market 
  "GOLD" 
  u200000  ;; $2000.00 threshold
  u144     ;; ~24 hours
)
;; Returns: (ok u1)

;; 2. User A predicts price will be ABOVE threshold
(contract-call? .marketmark make-prediction 
  u1 
  u1        ;; above
  u10000000 ;; 10 STX
)

;; 3. User B predicts price will be BELOW threshold
(contract-call? .marketmark make-prediction 
  u1 
  u2        ;; below
  u5000000  ;; 5 STX
)

;; 4. Check potential reward
(contract-call? .marketmark calculate-potential-reward u1 'ST1...)

;; 5. After duration expires, owner resolves
(contract-call? .marketmark resolve-market u1 u210000)
;; Final price: $2100.00 (above threshold)

;; 6. Winner (User A) claims reward
(contract-call? .marketmark claim-reward u1)
;; User A receives: (10 × 15) ÷ 10 = 15 STX
```

## Security Considerations

- Only contract owner can resolve markets
- Stakes are locked in contract until resolution
- One prediction per user per market prevents gaming
- Rewards can only be claimed once
- Markets must reach resolution block before being resolved

## Development

### Prerequisites
- Clarinet CLI
- Stacks wallet for testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --network mainnet
```

## Price Format

Prices should be represented in the smallest unit that makes sense for your use case:
- For USD prices: use cents (e.g., $2000.00 = u200000)
- For precise commodities: use appropriate decimal places

## Limitations

- Binary outcomes only (above/below threshold)
- Single price point resolution
- Requires trusted oracle (contract owner) for price data
- No partial withdrawals before resolution

## Future Enhancements

- Decentralized oracle integration (e.g., Redstone, Chainlink)
- Multi-outcome markets
- Automated market makers (AMM)
- Time-weighted rewards
- Market creation fees
- Liquidity provider incentives

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.

## Disclaimer

This is experimental software. Use at your own risk. Always verify market details before staking tokens. Prediction markets may be subject to local regulations.