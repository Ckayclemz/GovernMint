# GovernMint Smart Contract

## Overview

GovernMint is a decentralized governance smart contract built on the Stacks blockchain that enables community-driven fund management and decision-making. The contract allows participants to pool their STX tokens and collectively manage the allocation of these funds through a weighted voting system based on contribution size.

## Key Features

- **Token Pooling**: Participants can contribute STX tokens to a common pool
- **Weighted Voting**: Voting power is proportional to a participant's contribution
- **Milestone-Based Releases**: Funds are released based on predefined milestones
- **Validator System**: Trusted validators can create and complete milestones
- **Lockup Periods**: Enforces a minimum participation period before voting rights are granted

## Contract Structure

### Constants

- `CONTRACT_OWNER`: The deployer of the contract
- `LOCKUP_DURATION`: Blocks required before participants can vote (approximately 10 days)
- `VOTE_THRESHOLD`: Percentage of votes required for fund release (75%)
- `MINIMUM_STAKE`: Minimum STX amount to participate (1 STX = 1,000,000 μSTX)

### Token

- `governance-token`: Fungible token that represents participation in the governance system

### Data Storage

- `participants`: Map of participant data including contribution amount and voting power
- `milestones`: Map of milestone definitions with descriptions and completion status
- `validators`: Map of approved validators who can create and complete milestones

### Error Codes

- `ERROR_NOT_AUTHORIZED (1)`: Caller doesn't have permission for the operation
- `ERROR_BAD_INPUT (2)`: Invalid input parameters provided
- `ERROR_MILESTONE_NOT_FOUND (3)`: Referenced milestone doesn't exist
- `ERROR_LOCKUP_NOT_SATISFIED (4)`: Minimum lockup period not yet reached
- `ERROR_ALREADY_VOTED (5)`: Participant has already cast their vote
- `ERROR_NOT_PARTICIPANT (6)`: Caller is not a registered participant
- `ERROR_INVALID_VOTES_REQUIRED (7)`: Invalid vote threshold provided
- `ERROR_INVALID_MILESTONE_ID (8)`: Invalid milestone ID provided
- `ERROR_INVALID_DESCRIPTION (9)`: Invalid milestone description provided

## Public Functions

### `contribute()`

Allows a user to join the governance system by contributing STX tokens.

- Transfers STX from the caller to the contract
- Sets the caller's voting power proportional to their contribution
- Updates the total pool balance
- Returns `(ok true)` on success

### `withdraw(amount)`

Allows a participant to withdraw STX from the pool if sufficient votes have been reached.

- Requires the caller to be a participant
- Requires sufficient funds to be available (based on voting)
- Transfers the requested amount back to the caller
- Returns `(ok true)` on success

### `vote-for-release()`

Lets a participant vote for releasing funds from the pool.

- Requires the caller to be a participant who hasn't voted yet
- Requires the lockup period to have passed
- Updates the total votes count
- Returns `(ok true)` on success

### `create-milestone(description, votes-required)`

Allows a validator to create a new milestone.

- Requires the caller to be a registered validator
- Validates the description and votes-required parameters
- Creates a new milestone with the provided description
- Returns the milestone ID on success

### `complete-milestone(milestone-id)`

Marks a milestone as completed if sufficient votes have been reached.

- Requires the caller to be a registered validator
- Validates the milestone ID
- Updates the milestone status to completed
- Returns `(ok true)` on success

## Read-Only Functions

### `get-participant-info(address)`

Returns information about a specific participant.

### `get-milestone-info(milestone-id)`

Returns information about a specific milestone.

### `get-pool-balance()`

Returns the total amount of STX in the pool.

### `get-total-votes()`

Returns the total number of votes cast.

### `funds-available()`

Checks if sufficient votes have been reached to allow withdrawals.

## Usage Example

```clarity
;; Deploy the contract

;; As a user, contribute to the pool
(contract-call? .governmint contribute)

;; As a validator, create a milestone
(contract-call? .governmint create-milestone "Launch marketing campaign" u1000000)

;; As a participant, vote for fund release (after lockup period)
(contract-call? .governmint vote-for-release)

;; As a validator, complete a milestone
(contract-call? .governmint complete-milestone u1)

;; As a participant, withdraw funds
(contract-call? .governmint withdraw u500000)
```

## Security Considerations

- All user-provided inputs are validated before use
- Proper authorization checks for privileged operations
- Lockup period prevents quick voting and withdrawal
- Validator system provides additional security layer
