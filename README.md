# Dream Fund - Decentralized Crowdfunding Platform

A sophisticated decentralized crowdfunding platform built on Stacks blockchain that implements quadratic funding, milestone-based fund releases, and community governance features.

## 🌟 Overview

Dream Fund revolutionizes crowdfunding by combining traditional crowdfunding mechanisms with blockchain-based transparency, quadratic funding mathematics, and decentralized governance. The platform ensures accountability through milestone-based fund releases and protects contributors with refund mechanisms.

## ✨ Key Features

### Core Functionality
- **Milestone-Based Funding**: Funds are released in stages based on achieved milestones
- **Quadratic Funding**: Mathematical funding mechanism that amplifies the impact of small contributions
- **Community Voting**: Contributors vote on milestone completion using voting power proportional to their contribution
- **Refund Protection**: Automatic refunds for failed campaigns after grace period
- **Creator Staking**: Creators must stake 10 STX to create campaigns, returned upon success
- **Category Organization**: Campaigns organized by categories with tracking metrics

### Advanced Features
- **Reputation System**: Tracks contributor history and reputation scores
- **Matching Pool**: Additional funds distributed using quadratic funding formula
- **Platform Treasury**: 3% platform fee on successful milestone releases
- **Campaign Updates**: Creators can post updates throughout the campaign
- **Contributor Rewards**: Rewards system for active platform participants

## 📋 Technical Specifications

### Constants & Parameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Minimum Contribution | 1 STX | Lowest allowed contribution amount |
| Maximum Contribution | 100,000 STX | Highest allowed contribution per person |
| Platform Fee | 3% | Fee taken from milestone releases |
| Creator Stake | 10 STX | Required stake to create campaign |
| Voting Period | ~7 days (1008 blocks) | Duration for milestone voting |
| Approval Threshold | 60% | Required approval rate for milestone release |
| Max Milestones | 10 | Maximum milestones per campaign |
| Max Active Campaigns | 100 | Platform-wide active campaign limit |
| Refund Grace Period | ~30 days (4320 blocks) | Time after deadline before refunds available |

## 🚀 Getting Started

### Creating a Campaign

```clarity
(contract-call? .dream-fund create-campaign 
    "Revolutionary DeFi Protocol"
    "Building the next generation of decentralized finance"
    u50000000000  ;; 50,000 STX goal
    u20160        ;; ~14 days deadline
    "Technology"
    "https://metadata.example.com/campaign1")
```

### Contributing to a Campaign

```clarity
(contract-call? .dream-fund contribute 
    u1            ;; campaign-id
    u5000000000)  ;; 5,000 STX contribution
```

### Adding Milestones

```clarity
(contract-call? .dream-fund add-milestone
    u1  ;; campaign-id
    "Smart Contract Development"
    "Complete core smart contract functionality"
    u15000000000  ;; 15,000 STX milestone amount
    u10080)       ;; 7 days deadline
```

## 💻 Core Functions

### Campaign Management

#### `create-campaign`
Creates a new crowdfunding campaign with specified parameters.
- **Parameters**: title, description, goal, deadline, category, metadata-uri
- **Returns**: Campaign ID
- **Requirements**: Creator stake of 10 STX, platform not paused

#### `contribute`
Allows users to contribute STX to active campaigns.
- **Parameters**: campaign-id, amount
- **Returns**: Contribution amount
- **Requirements**: Campaign active, within deadline, meets min/max limits

#### `add-milestone`
Campaign creators add milestones for staged fund releases.
- **Parameters**: campaign-id, title, description, amount, deadline
- **Returns**: Milestone ID
- **Requirements**: Must be campaign creator, campaign active

### Milestone Governance

#### `submit-milestone-evidence`
Creator submits evidence of milestone completion to initiate voting.
- **Parameters**: campaign-id, milestone-id, evidence-uri
- **Returns**: Success boolean
- **Requirements**: Must be creator, milestone not already released

#### `vote-milestone`
Contributors vote on milestone completion approval.
- **Parameters**: campaign-id, milestone-id, approve (boolean)
- **Returns**: Success boolean
- **Requirements**: Must be contributor, within voting period

#### `release-milestone`
Releases funds for approved milestones after voting period.
- **Parameters**: campaign-id, milestone-id
- **Returns**: Released amount
- **Requirements**: Voting ended, 60% approval threshold met

### Fund Management

#### `claim-refund`
Contributors claim refunds from failed campaigns.
- **Parameters**: campaign-id
- **Returns**: Refund amount
- **Requirements**: Campaign failed, grace period passed

#### `add-to-matching-pool`
Add funds to the quadratic funding matching pool.
- **Parameters**: amount
- **Returns**: Added amount

#### `distribute-matching-funds`
Distributes quadratic matching funds to successful campaigns.
- **Parameters**: campaign-id
- **Returns**: Distributed amount
- **Requirements**: Admin only, campaign successful

## 📊 Data Structures

### Campaign Structure
```clarity
{
    creator: principal,
    title: string-ascii 100,
    description: string-ascii 500,
    goal: uint,
    raised: uint,
    deadline: uint,
    milestone-count: uint,
    milestones-completed: uint,
    contributors-count: uint,
    is-active: bool,
    is-successful: bool,
    creator-stake: uint,
    category: string-ascii 50,
    metadata-uri: string-ascii 256
}
```

### Contribution Structure
```clarity
{
    amount: uint,
    contributed-at: uint,
    voting-power: uint,
    refund-claimed: bool,
    rewards-earned: uint
}
```

### Milestone Structure
```clarity
{
    title: string-ascii 100,
    description: string-ascii 300,
    amount: uint,
    deadline: uint,
    votes-for: uint,
    votes-against: uint,
    voting-ends: uint,
    is-released: bool,
    evidence-uri: string-ascii 256
}
```

## 🔐 Security Features

### Protection Mechanisms
- **Creator Staking**: Ensures creator commitment with 10 STX stake
- **Refund Protection**: Automatic refunds for contributors if campaigns fail
- **Voting Governance**: Community validates milestone completion
- **Contribution Limits**: Min/max limits prevent gaming and excessive risk
- **Platform Pause**: Emergency pause functionality for critical issues

### Access Control
- Campaign creators control milestone submissions
- Only contributors can vote on milestones
- Admin functions restricted to contract owner
- Refunds only available to actual contributors

## 📈 Quadratic Funding

The platform implements quadratic funding to democratize funding distribution:

1. **Square Root Calculation**: Each contribution's square root is calculated
2. **Matching Calculation**: Matching amount = (√contribution × multiplier) / 100
3. **Power Distribution**: Small contributions receive proportionally more matching
4. **Democratic Impact**: Broad support valued over large individual contributions

## 🎯 Use Cases

### Ideal For
- **Open Source Projects**: Community-funded development with milestone accountability
- **Creative Works**: Artists and creators with staged deliverables
- **Research Initiatives**: Academic or scientific projects with clear milestones
- **Community Projects**: Local initiatives requiring transparent funding
- **Product Development**: Hardware or software products with development stages

### Benefits
- **For Creators**: Reduced platform fees, milestone flexibility, community engagement
- **For Contributors**: Voting rights, refund protection, transparent progress
- **For Communities**: Democratic funding, quadratic matching, category organization

## 🔧 Admin Functions

### Platform Management
- `pause-platform`: Emergency pause all platform operations
- `unpause-platform`: Resume platform operations
- `withdraw-treasury`: Withdraw accumulated platform fees

## 📊 Platform Statistics

Track platform metrics through `get-platform-stats`:
- Total campaigns created
- Total funds raised
- Total funds distributed
- Active campaign count
- Matching pool balance
- Treasury balance

## 🚦 Campaign Lifecycle

1. **Creation**: Creator stakes 10 STX and defines campaign parameters
2. **Funding**: Contributors fund campaign until deadline
3. **Success Check**: Campaign marked successful if goal reached
4. **Milestone Submission**: Creator submits evidence for milestones
5. **Community Voting**: Contributors vote on milestone completion
6. **Fund Release**: Approved milestones trigger fund releases
7. **Completion/Refund**: Successful completion or refund process

## ⚠️ Important Considerations

### For Campaign Creators
- Stake requirement is non-refundable if campaign fails
- Milestones must be clearly defined and achievable
- Evidence submission required for each milestone
- Platform fee applied to all milestone releases

### For Contributors
- Contributions are final once campaign succeeds
- Voting power proportional to contribution amount
- Refunds only available for failed campaigns after grace period
- Cannot contribute multiple times to same campaign

## 🛠️ Development & Testing

### Testing Checklist
- [ ] Campaign creation with various parameters
- [ ] Contribution flow and limits
- [ ] Milestone voting mechanisms
- [ ] Refund processes
- [ ] Quadratic funding calculations
- [ ] Platform pause functionality
- [ ] Treasury management

### Integration Requirements
- Stacks blockchain node access
- STX wallet integration
- Metadata storage solution (IPFS/Arweave recommended)
- Frontend interface for user interactions

## 📜 License

This smart contract is provided as-is for educational and development purposes. Ensure proper auditing and testing before mainnet deployment.

## 🤝 Contributing

Contributions are welcome! Please ensure:
- Comprehensive testing of new features
- Documentation updates for changes
- Security consideration for fund handling
- Backwards compatibility maintenance

## 📞 Support

For questions, issues, or suggestions:
- Review contract documentation
- Check existing test cases
- Consult Stacks/Clarity documentation
- Engage with the community

---
