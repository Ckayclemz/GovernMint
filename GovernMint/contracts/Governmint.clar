;; GovernMint Smart Contract

;; description: A decentralized governance contract that allows participants to pool STX tokens,
;;             set milestone-based release conditions, and make collective decisions through weighted voting.
;;             Includes validator verification and approval mechanisms for fund distribution.

;; traits
;; No traits defined yet

;; token definitions
(define-fungible-token governance-token)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant LOCKUP_DURATION u1440)  ;; approximately 10 days at 10 min/block
(define-constant VOTE_THRESHOLD u75)  ;; 75% majority required
(define-constant MINIMUM_STAKE u1000000)  ;; 1 STX = 1000000 uSTX
(define-constant ERROR_NOT_AUTHORIZED (err u1))
(define-constant ERROR_BAD_INPUT (err u2))
(define-constant ERROR_MILESTONE_NOT_FOUND (err u3))
(define-constant ERROR_LOCKUP_NOT_SATISFIED (err u4))
(define-constant ERROR_ALREADY_VOTED (err u5))
(define-constant ERROR_NOT_PARTICIPANT (err u6))
(define-constant ERROR_INVALID_VOTES_REQUIRED (err u7))
(define-constant ERROR_INVALID_MILESTONE_ID (err u8))
(define-constant ERROR_INVALID_DESCRIPTION (err u9))
(define-constant MAX_DESCRIPTION_LENGTH u256)
(define-constant MIN_DESCRIPTION_LENGTH u1)

;; data vars
(define-data-var pool-balance uint u0)
(define-data-var participant-count uint u0)
(define-data-var total-votes uint u0)
(define-data-var milestone-counter uint u0)

;; data maps
(define-map participants 
    {address: principal}  
    {amount: uint,            
     join-block: uint,         
     voting-power: uint,      
     has-voted: bool})       

(define-map milestones
    {milestone-id: uint}     
    {description: (string-ascii 256),  
     votes-required: uint,             
     completed: bool,                  
     completion-block: (optional uint)})

(define-map validators
    {validator: principal}
    {active: bool})

;; public functions
(define-public (contribute)
    (let ((deposit-amount (stx-get-balance tx-sender)))
        (if (>= deposit-amount MINIMUM_STAKE)
            (begin
                (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
                (map-set participants 
                    {address: tx-sender}
                    {amount: deposit-amount,
                     join-block: stacks-block-height,
                     voting-power: (calculate-voting-power deposit-amount),
                     has-voted: false})
                (var-set pool-balance (+ (var-get pool-balance) deposit-amount))
                (var-set participant-count (+ (var-get participant-count) u1))
                (ok true))
            ERROR_BAD_INPUT)))

(define-public (withdraw (amount uint))
    (let ((user-info (unwrap! (map-get? participants {address: tx-sender}) 
                                   ERROR_NOT_PARTICIPANT)))
        (if (and
            (funds-available)
            (<= amount (get amount user-info)))
            (begin
                (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
                (ok true))
            ERROR_NOT_AUTHORIZED)))

(define-public (vote-for-release)
    (let ((user-info (unwrap! (map-get? participants {address: tx-sender}) 
                                   ERROR_NOT_PARTICIPANT)))
        (if (and
            (not (get has-voted user-info))
            (lockup-period-passed (get join-block user-info)))
            (begin
                (map-set participants
                    {address: tx-sender}
                    (merge user-info {has-voted: true}))
                (var-set total-votes 
                    (+ (var-get total-votes) 
                       (get voting-power user-info)))
                (ok true))
            ERROR_ALREADY_VOTED)))

(define-public (create-milestone (description (string-ascii 256)) 
                            (votes-required uint))
    (let ((next-milestone-id (+ (var-get milestone-counter) u1))
          (desc-length (len description)))
        (if (is-validator tx-sender)
            (begin
                ;; Validate votes-required is reasonable
                (if (> votes-required u0)
                    ;; Validate description length is reasonable
                    (if (and (>= desc-length MIN_DESCRIPTION_LENGTH)
                             (<= desc-length MAX_DESCRIPTION_LENGTH))
                        (begin
                            ;; Create a validated description rather than using input directly
                            (let ((validated-description description))
                                (map-set milestones
                                    {milestone-id: next-milestone-id}
                                    {description: validated-description,
                                     votes-required: votes-required,
                                     completed: false,
                                     completion-block: none})
                                (var-set milestone-counter next-milestone-id)
                                (ok next-milestone-id))
                            )
                        ERROR_INVALID_DESCRIPTION)
                    ERROR_INVALID_VOTES_REQUIRED))
            ERROR_NOT_AUTHORIZED)))

(define-public (complete-milestone (milestone-id uint))
    ;; Validate milestone-id exists before using it
    (if (and 
         (> milestone-id u0) 
         (<= milestone-id (var-get milestone-counter)))
        (let ((milestone-data (unwrap! (map-get? milestones {milestone-id: milestone-id})
                                 ERROR_MILESTONE_NOT_FOUND)))
            (if (and
                (is-validator tx-sender)
                (>= (var-get total-votes) (get votes-required milestone-data)))
                (begin
                    (map-set milestones
                        {milestone-id: milestone-id}
                        (merge milestone-data 
                              {completed: true,
                               completion-block: (some stacks-block-height)}))
                    (ok true))
                ERROR_NOT_AUTHORIZED))
        ERROR_INVALID_MILESTONE_ID))

;; read only functions
(define-read-only (get-participant-info (address principal))
    (map-get? participants {address: address}))

(define-read-only (get-milestone-info (milestone-id uint))
    (map-get? milestones {milestone-id: milestone-id}))

(define-read-only (get-pool-balance)
    (var-get pool-balance))

(define-read-only (get-total-votes)
    (var-get total-votes))

(define-read-only (funds-available)
    (>= (var-get total-votes)
        (* (var-get participant-count) VOTE_THRESHOLD)))

;; private functions
(define-private (is-validator (account principal))
    (default-to 
        false
        (get active (map-get? validators {validator: account}))))

(define-private (calculate-voting-power (amount uint))
    (/ (* amount u100) MINIMUM_STAKE))

(define-private (lockup-period-passed (join-block uint))
    (>= stacks-block-height (+ join-block LOCKUP_DURATION)))

(define-private (get-milestone-count)
    (var-get milestone-counter))