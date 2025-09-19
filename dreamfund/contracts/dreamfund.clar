;; Dream Fund - Decentralized Crowdfunding Platform with Quadratic Funding
;; Features: Milestone-based releases, community voting, refund protection, matching pools

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-campaign-not-found (err u101))
(define-constant err-campaign-ended (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-already-contributed (err u104))
(define-constant err-milestone-not-found (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-campaign-active (err u107))
(define-constant err-invalid-amount (err u108))
(define-constant err-max-campaigns (err u109))
(define-constant err-refund-claimed (err u110))
(define-constant err-not-contributor (err u111))
(define-constant err-paused (err u112))

;; Protocol Parameters
(define-constant min-contribution u1000000) ;; 1 STX minimum
(define-constant max-contribution u100000000000) ;; 100,000 STX maximum
(define-constant platform-fee u300) ;; 3% platform fee
(define-constant creator-stake u10000000) ;; 10 STX stake required
(define-constant voting-period u1008) ;; ~7 days voting
(define-constant approval-threshold u6000) ;; 60% approval needed
(define-constant max-milestones u10)
(define-constant max-active-campaigns u100)
(define-constant matching-pool-multiplier u2) ;; 2x matching for quadratic funding
(define-constant refund-grace-period u4320) ;; ~30 days for refunds

;; Data Variables
(define-data-var campaign-counter uint u0)
(define-data-var total-raised uint u0)
(define-data-var total-distributed uint u0)
(define-data-var active-campaign-count uint u0)
(define-data-var matching-pool-balance uint u0)
(define-data-var platform-treasury uint u0)
(define-data-var platform-paused bool false)

;; Data Maps
(define-map campaigns
    uint ;; campaign-id
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        goal: uint,
        raised: uint,
        deadline: uint,
        milestone-count: uint,
        milestones-completed: uint,
        contributors-count: uint,
        is-active: bool,
        is-successful: bool,
        creator-stake: uint,
        category: (string-ascii 50),
        metadata-uri: (string-ascii 256)
    })

(define-map contributions
    { campaign-id: uint, contributor: principal }
    {
        amount: uint,
        contributed-at: uint,
        voting-power: uint,
        refund-claimed: bool,
        rewards-earned: uint
    })

(define-map milestones
    { campaign-id: uint, milestone-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 300),
        amount: uint,
        deadline: uint,
        votes-for: uint,
        votes-against: uint,
        voting-ends: uint,
        is-released: bool,
        evidence-uri: (string-ascii 256)
    })

(define-map milestone-votes
    { campaign-id: uint, milestone-id: uint, voter: principal }
    {
        vote: bool,
        voted-at: uint,
        weight: uint
    })

(define-map quadratic-funding
    uint ;; campaign-id
    {
        matching-amount: uint,
        total-sqrt-sum: uint,
        contributor-count: uint,
        matching-distributed: bool
    })

(define-map contributor-rewards
    principal
    {
        total-contributed: uint,
        campaigns-supported: uint,
        rewards-earned: uint,
        reputation-score: uint,
        member-since: uint
    })

(define-map campaign-updates
    { campaign-id: uint, update-id: uint }
    {
        update-text: (string-ascii 500),
        posted-at: uint,
        update-type: (string-ascii 20)
    })

(define-map categories
    (string-ascii 50)
    {
        total-campaigns: uint,
        total-raised: uint,
        success-rate: uint
    })

;; Private Functions
(define-private (sqrt-uint (x uint))
    (if (is-eq x u0)
        u0
        (let ((initial (/ (+ x u1) u2)))
            (let ((result (/ (+ initial (/ x initial)) u2)))
                result))))

(define-private (calculate-quadratic-match (contribution uint) (total-contributions uint))
    (let ((sqrt-contribution (sqrt-uint contribution)))
        (/ (* sqrt-contribution matching-pool-multiplier) u100)))

(define-private (calculate-voting-power (amount uint))
    (sqrt-uint (/ amount u1000000)))

(define-private (calculate-platform-fee (amount uint))
    (/ (* amount platform-fee) u10000))

(define-private (update-contributor-rewards (contributor principal) (amount uint))
    (match (map-get? contributor-rewards contributor)
        rewards (map-set contributor-rewards contributor
                       (merge rewards {
                           total-contributed: (+ (get total-contributed rewards) amount),
                           campaigns-supported: (+ (get campaigns-supported rewards) u1),
                           reputation-score: (+ (get reputation-score rewards) 
                                              (/ amount u10000000))
                       }))
        (map-set contributor-rewards contributor {
            total-contributed: amount,
            campaigns-supported: u1,
            rewards-earned: u0,
            reputation-score: (/ amount u10000000),
            member-since: burn-block-height
        })))

;; Read-only Functions
(define-read-only (get-campaign (campaign-id uint))
    (ok (map-get? campaigns campaign-id)))

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
    (ok (map-get? contributions { campaign-id: campaign-id, contributor: contributor })))

(define-read-only (get-milestone (campaign-id uint) (milestone-id uint))
    (ok (map-get? milestones { campaign-id: campaign-id, milestone-id: milestone-id })))

(define-read-only (get-quadratic-funding (campaign-id uint))
    (ok (map-get? quadratic-funding campaign-id)))

(define-read-only (get-contributor-stats (contributor principal))
    (ok (map-get? contributor-rewards contributor)))

(define-read-only (calculate-refund-amount (campaign-id uint) (contributor principal))
    (match (map-get? campaigns campaign-id)
        campaign (match (map-get? contributions { campaign-id: campaign-id, contributor: contributor })
                   contribution (if (and (not (get is-successful campaign))
                                       (> burn-block-height (get deadline campaign)))
                                   (ok (get amount contribution))
                                   (ok u0))
                   (ok u0))
        (err err-campaign-not-found)))

(define-read-only (get-platform-stats)
    (ok {
        total-campaigns: (var-get campaign-counter),
        total-raised: (var-get total-raised),
        total-distributed: (var-get total-distributed),
        active-campaigns: (var-get active-campaign-count),
        matching-pool: (var-get matching-pool-balance),
        treasury: (var-get platform-treasury)
    }))

;; Public Functions
(define-public (create-campaign (title (string-ascii 100))
                               (description (string-ascii 500))
                               (goal uint)
                               (deadline-blocks uint)
                               (category (string-ascii 50))
                               (metadata-uri (string-ascii 256)))
    (let ((campaign-id (+ (var-get campaign-counter) u1))
          (deadline (+ burn-block-height deadline-blocks)))
        
        ;; Validations
        (asserts! (not (var-get platform-paused)) err-paused)
        (asserts! (< (var-get active-campaign-count) max-active-campaigns) err-max-campaigns)
        (asserts! (> goal u0) err-invalid-amount)
        (asserts! (> deadline-blocks u1440) err-invalid-amount) ;; Min 10 days
        
        ;; Transfer creator stake
        (try! (stx-transfer? creator-stake tx-sender (as-contract tx-sender)))
        
        ;; Create campaign
        (map-set campaigns campaign-id {
            creator: tx-sender,
            title: title,
            description: description,
            goal: goal,
            raised: u0,
            deadline: deadline,
            milestone-count: u0,
            milestones-completed: u0,
            contributors-count: u0,
            is-active: true,
            is-successful: false,
            creator-stake: creator-stake,
            category: category,
            metadata-uri: metadata-uri
        })
        
        ;; Initialize quadratic funding
        (map-set quadratic-funding campaign-id {
            matching-amount: u0,
            total-sqrt-sum: u0,
            contributor-count: u0,
            matching-distributed: false
        })
        
        ;; Update category stats
        (match (map-get? categories category)
            cat (map-set categories category
                       (merge cat {
                           total-campaigns: (+ (get total-campaigns cat) u1)
                       }))
            (map-set categories category {
                total-campaigns: u1,
                total-raised: u0,
                success-rate: u0
            }))
        
        ;; Update counters
        (var-set campaign-counter campaign-id)
        (var-set active-campaign-count (+ (var-get active-campaign-count) u1))
        
        (ok campaign-id)))

(define-public (contribute (campaign-id uint) (amount uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (existing (map-get? contributions { campaign-id: campaign-id, contributor: tx-sender }))
          (qf-data (unwrap! (map-get? quadratic-funding campaign-id) err-campaign-not-found)))
        
        ;; Validations
        (asserts! (not (var-get platform-paused)) err-paused)
        (asserts! (get is-active campaign) err-campaign-ended)
        (asserts! (< burn-block-height (get deadline campaign)) err-campaign-ended)
        (asserts! (>= amount min-contribution) err-invalid-amount)
        (asserts! (<= amount max-contribution) err-invalid-amount)
        (asserts! (is-none existing) err-already-contributed)
        
        ;; Transfer contribution
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Calculate voting power
        (let ((voting-power (calculate-voting-power amount))
              (sqrt-amount (sqrt-uint amount))
              (quadratic-match (calculate-quadratic-match amount (get raised campaign))))
            
            ;; Record contribution
            (map-set contributions 
                    { campaign-id: campaign-id, contributor: tx-sender }
                    {
                        amount: amount,
                        contributed-at: burn-block-height,
                        voting-power: voting-power,
                        refund-claimed: false,
                        rewards-earned: u0
                    })
            
            ;; Update campaign
            (map-set campaigns campaign-id
                    (merge campaign {
                        raised: (+ (get raised campaign) amount),
                        contributors-count: (+ (get contributors-count campaign) u1),
                        is-successful: (>= (+ (get raised campaign) amount) (get goal campaign))
                    }))
            
            ;; Update quadratic funding
            (map-set quadratic-funding campaign-id
                    (merge qf-data {
                        total-sqrt-sum: (+ (get total-sqrt-sum qf-data) sqrt-amount),
                        contributor-count: (+ (get contributor-count qf-data) u1),
                        matching-amount: (+ (get matching-amount qf-data) quadratic-match)
                    }))
            
            ;; Update contributor rewards
            (update-contributor-rewards tx-sender amount)
            
            ;; Update global stats
            (var-set total-raised (+ (var-get total-raised) amount))
            
            ;; Check if goal reached
            (if (>= (+ (get raised campaign) amount) (get goal campaign))
                (begin
                    ;; Return creator stake
                    (try! (as-contract (stx-transfer? (get creator-stake campaign) 
                                                     tx-sender 
                                                     (get creator campaign))))
                    (var-set active-campaign-count (- (var-get active-campaign-count) u1)))
                false)
            
            (ok amount))))

(define-public (add-milestone (campaign-id uint)
                             (title (string-ascii 100))
                             (description (string-ascii 300))
                             (amount uint)
                             (deadline uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (milestone-id (+ (get milestone-count campaign) u1)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get creator campaign)) err-unauthorized)
        (asserts! (< milestone-id max-milestones) err-max-campaigns)
        (asserts! (get is-active campaign) err-campaign-ended)
        
        ;; Create milestone
        (map-set milestones 
                { campaign-id: campaign-id, milestone-id: milestone-id }
                {
                    title: title,
                    description: description,
                    amount: amount,
                    deadline: deadline,
                    votes-for: u0,
                    votes-against: u0,
                    voting-ends: u0,
                    is-released: false,
                    evidence-uri: ""
                })
        
        ;; Update campaign
        (map-set campaigns campaign-id
                (merge campaign {
                    milestone-count: milestone-id
                }))
        
        (ok milestone-id)))

(define-public (submit-milestone-evidence (campaign-id uint) 
                                         (milestone-id uint)
                                         (evidence-uri (string-ascii 256)))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (milestone (unwrap! (map-get? milestones 
                                      { campaign-id: campaign-id, milestone-id: milestone-id })
                            err-milestone-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get creator campaign)) err-unauthorized)
        (asserts! (not (get is-released milestone)) err-already-voted)
        
        ;; Update milestone with evidence and start voting
        (map-set milestones 
                { campaign-id: campaign-id, milestone-id: milestone-id }
                (merge milestone {
                    evidence-uri: evidence-uri,
                    voting-ends: (+ burn-block-height voting-period)
                }))
        
        (ok true)))

(define-public (vote-milestone (campaign-id uint) (milestone-id uint) (approve bool))
    (let ((contribution (unwrap! (map-get? contributions 
                                         { campaign-id: campaign-id, contributor: tx-sender })
                                err-not-contributor))
          (milestone (unwrap! (map-get? milestones 
                                      { campaign-id: campaign-id, milestone-id: milestone-id })
                            err-milestone-not-found))
          (existing-vote (map-get? milestone-votes 
                                  { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender })))
        
        ;; Validations
        (asserts! (is-none existing-vote) err-already-voted)
        (asserts! (< burn-block-height (get voting-ends milestone)) err-campaign-ended)
        (asserts! (> (get voting-ends milestone) u0) err-milestone-not-found)
        
        ;; Record vote
        (map-set milestone-votes 
                { campaign-id: campaign-id, milestone-id: milestone-id, voter: tx-sender }
                {
                    vote: approve,
                    voted-at: burn-block-height,
                    weight: (get voting-power contribution)
                })
        
        ;; Update milestone votes
        (map-set milestones 
                { campaign-id: campaign-id, milestone-id: milestone-id }
                (merge milestone {
                    votes-for: (if approve 
                                 (+ (get votes-for milestone) (get voting-power contribution))
                                 (get votes-for milestone)),
                    votes-against: (if approve
                                     (get votes-against milestone)
                                     (+ (get votes-against milestone) (get voting-power contribution)))
                }))
        
        (ok true)))

(define-public (release-milestone (campaign-id uint) (milestone-id uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (milestone (unwrap! (map-get? milestones 
                                      { campaign-id: campaign-id, milestone-id: milestone-id })
                            err-milestone-not-found)))
        
        ;; Validations
        (asserts! (> burn-block-height (get voting-ends milestone)) err-campaign-active)
        (asserts! (not (get is-released milestone)) err-already-voted)
        (asserts! (get is-successful campaign) err-campaign-ended)
        
        ;; Check if approved
        (let ((total-votes (+ (get votes-for milestone) (get votes-against milestone)))
              (approval-rate (if (> total-votes u0)
                                (/ (* (get votes-for milestone) u10000) total-votes)
                                u0)))
            
            (asserts! (>= approval-rate approval-threshold) err-insufficient-funds)
            
            ;; Calculate release amount
            (let ((fee (calculate-platform-fee (get amount milestone)))
                  (release-amount (- (get amount milestone) fee)))
                
                ;; Transfer to creator
                (try! (as-contract (stx-transfer? release-amount tx-sender (get creator campaign))))
                
                ;; Update milestone
                (map-set milestones 
                        { campaign-id: campaign-id, milestone-id: milestone-id }
                        (merge milestone {
                            is-released: true
                        }))
                
                ;; Update campaign
                (map-set campaigns campaign-id
                        (merge campaign {
                            milestones-completed: (+ (get milestones-completed campaign) u1)
                        }))
                
                ;; Update stats
                (var-set total-distributed (+ (var-get total-distributed) release-amount))
                (var-set platform-treasury (+ (var-get platform-treasury) fee))
                
                (ok release-amount)))))

(define-public (claim-refund (campaign-id uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (contribution (unwrap! (map-get? contributions 
                                         { campaign-id: campaign-id, contributor: tx-sender })
                                err-not-contributor)))
        
        ;; Validations
        (asserts! (not (get is-successful campaign)) err-campaign-active)
        (asserts! (> burn-block-height (+ (get deadline campaign) refund-grace-period)) err-campaign-active)
        (asserts! (not (get refund-claimed contribution)) err-refund-claimed)
        
        ;; Process refund
        (try! (as-contract (stx-transfer? (get amount contribution) tx-sender tx-sender)))
        
        ;; Update contribution
        (map-set contributions 
                { campaign-id: campaign-id, contributor: tx-sender }
                (merge contribution {
                    refund-claimed: true
                }))
        
        (ok (get amount contribution))))

(define-public (add-to-matching-pool (amount uint))
    (begin
        ;; Transfer to matching pool
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update matching pool balance
        (var-set matching-pool-balance (+ (var-get matching-pool-balance) amount))
        
        (ok amount)))

(define-public (distribute-matching-funds (campaign-id uint))
    (let ((campaign (unwrap! (map-get? campaigns campaign-id) err-campaign-not-found))
          (qf-data (unwrap! (map-get? quadratic-funding campaign-id) err-campaign-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (get is-successful campaign) err-campaign-ended)
        (asserts! (not (get matching-distributed qf-data)) err-already-contributed)
        
        (let ((matching-amount (get matching-amount qf-data)))
            
            ;; Transfer matching funds
            (and (> matching-amount u0)
                 (try! (as-contract (stx-transfer? matching-amount tx-sender (get creator campaign)))))
            
            ;; Update quadratic funding
            (map-set quadratic-funding campaign-id
                    (merge qf-data {
                        matching-distributed: true
                    }))
            
            ;; Update matching pool
            (var-set matching-pool-balance (- (var-get matching-pool-balance) matching-amount))
            
            (ok matching-amount))))

;; Admin Functions
(define-public (pause-platform)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set platform-paused true)
        (ok true)))

(define-public (unpause-platform)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set platform-paused false)
        (ok true)))

(define-public (withdraw-treasury (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (<= amount (var-get platform-treasury)) err-insufficient-funds)
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set platform-treasury (- (var-get platform-treasury) amount))
        (ok amount)))