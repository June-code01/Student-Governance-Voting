;; Student Governance Voting - Blockchain-based democratic decision making

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-voted (err u102))
(define-constant err-not-active (err u103))
(define-constant err-unauthorized (err u104))

;; Data Variables
(define-data-var total-proposals uint u0)
(define-data-var total-voters uint u0)

;; Data Maps
(define-map proposals
    { proposal-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        proposer: principal,
        yes-votes: uint,
        no-votes: uint,
        start-block: uint,
        end-block: uint,
        active: bool,
        executed: bool
    }
)

(define-map voters
    { voter: principal }
    {
        registered: bool,
        student-id: (string-ascii 50),
        vote-count: uint
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    {
        vote: bool,
        vote-time: uint
    }
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-voter (voter principal))
    (map-get? voters { voter: voter })
)

(define-read-only (has-voted (proposal-id uint) (voter principal))
    (is-some (map-get? votes { proposal-id: proposal-id, voter: voter }))
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-total-proposals)
    (ok (var-get total-proposals))
)

(define-read-only (is-proposal-active (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (and 
            (get active proposal)
            (>= stacks-block-height (get start-block proposal))
            (<= stacks-block-height (get end-block proposal))
        )
        false
    )
)