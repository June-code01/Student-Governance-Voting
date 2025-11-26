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

;; Public functions
;; #[allow(unchecked_data)]
(define-public (register-voter (student-id (string-ascii 50)))
    (let ((existing-voter (map-get? voters { voter: tx-sender })))
        (if (is-some existing-voter)
            (err err-already-voted)
            (ok (begin
                (map-set voters
                    { voter: tx-sender }
                    { registered: true, student-id: student-id, vote-count: u0 }
                )
                (var-set total-voters (+ (var-get total-voters) u1))
            ))
        )
    )
)

;; #[allow(unchecked_data)]
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (duration uint))
    (let (
        (new-proposal-id (+ (var-get total-proposals) u1))
        (voter-info (unwrap! (map-get? voters { voter: tx-sender }) err-unauthorized))
    )
        (asserts! (get registered voter-info) err-unauthorized)
        (map-set proposals
            { proposal-id: new-proposal-id }
            {
                title: title,
                description: description,
                proposer: tx-sender,
                yes-votes: u0,
                no-votes: u0,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height duration),
                active: true,
                executed: false
            }
        )
        (var-set total-proposals new-proposal-id)
        (ok new-proposal-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (cast-vote (proposal-id uint) (vote-yes bool))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
        (voter-info (unwrap! (map-get? voters { voter: tx-sender }) err-unauthorized))
        (already-voted (has-voted proposal-id tx-sender))
    )
        (asserts! (not already-voted) err-already-voted)
        (asserts! (is-proposal-active proposal-id) err-not-active)
        (asserts! (get registered voter-info) err-unauthorized)
        (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: vote-yes, vote-time: stacks-block-height }
        )
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal {
                yes-votes: (if vote-yes (+ (get yes-votes proposal) u1) (get yes-votes proposal)),
                no-votes: (if vote-yes (get no-votes proposal) (+ (get no-votes proposal) u1))
            })
        )
        (map-set voters
            { voter: tx-sender }
            (merge voter-info { vote-count: (+ (get vote-count voter-info) u1) })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (close-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
        (asserts! (get active proposal) err-not-active)
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { active: false })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (execute-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get executed proposal)) err-not-active)
        (asserts! (> stacks-block-height (get end-block proposal)) err-not-active)
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { executed: true })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (update-voter-student-id (new-student-id (string-ascii 50)))
    (let (
        (voter-info (unwrap! (map-get? voters { voter: tx-sender }) err-not-found))
    )
        (asserts! (get registered voter-info) err-unauthorized)
        (map-set voters
            { voter: tx-sender }
            (merge voter-info { student-id: new-student-id })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (deactivate-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { active: false })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (reactivate-proposal (proposal-id uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= stacks-block-height (get end-block proposal)) err-not-active)
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { active: true })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (extend-proposal-duration (proposal-id uint) (additional-blocks uint))
    (let (
        (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) err-not-found))
    )
        (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
        (asserts! (get active proposal) err-not-active)
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal { end-block: (+ (get end-block proposal) additional-blocks) })
        )
        (ok true)
    )
)

;; Additional read-only helper functions
(define-read-only (get-proposal-status (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            active: (get active proposal),
            executed: (get executed proposal),
            is-voting-open: (is-proposal-active proposal-id),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-votes: (+ (get yes-votes proposal) (get no-votes proposal))
        })
        err-not-found
    )
)

(define-read-only (get-proposal-result (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            vote-difference: (if (> (get yes-votes proposal) (get no-votes proposal))
                (- (get yes-votes proposal) (get no-votes proposal))
                (- (get no-votes proposal) (get yes-votes proposal))
            )
        })
        err-not-found
    )
)

(define-read-only (get-voter-participation (voter principal))
    (match (map-get? voters { voter: voter })
        voter-info (ok {
            registered: (get registered voter-info),
            total-votes: (get vote-count voter-info),
            student-id: (get student-id voter-info)
        })
        err-not-found
    )
)

(define-read-only (calculate-proposal-percentage (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (let (
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        )
            (if (is-eq total-votes u0)
                (ok { yes-percentage: u0, no-percentage: u0 })
                (ok {
                    yes-percentage: (/ (* (get yes-votes proposal) u100) total-votes),
                    no-percentage: (/ (* (get no-votes proposal) u100) total-votes)
                })
            )
        )
        err-not-found
    )
)

(define-read-only (is-voter-registered (voter principal))
    (match (map-get? voters { voter: voter })
        voter-info (get registered voter-info)
        false
    )
)

(define-read-only (get-total-voters)
    (ok (var-get total-voters))
)

(define-read-only (get-proposal-time-remaining (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (if (> stacks-block-height (get end-block proposal))
            (ok u0)
            (ok (- (get end-block proposal) stacks-block-height))
        )
        err-not-found
    )
)

(define-read-only (is-proposal-passed (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok (> (get yes-votes proposal) (get no-votes proposal)))
        err-not-found
    )
)

(define-read-only (get-proposal-details (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            title: (get title proposal),
            description: (get description proposal),
            proposer: (get proposer proposal),
            start-block: (get start-block proposal),
            end-block: (get end-block proposal)
        })
        err-not-found
    )
)

(define-read-only (get-vote-counts (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-votes: (+ (get yes-votes proposal) (get no-votes proposal))
        })
        err-not-found
    )
)

(define-read-only (is-proposal-expired (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok (> stacks-block-height (get end-block proposal)))
        err-not-found
    )
)

(define-read-only (can-voter-vote (proposal-id uint) (voter principal))
    (let (
        (is-registered (is-voter-registered voter))
        (already-voted (has-voted proposal-id voter))
        (is-active (is-proposal-active proposal-id))
    )
        (ok (and is-registered (not already-voted) is-active))
    )
)

(define-read-only (get-proposal-proposer (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok (get proposer proposal))
        err-not-found
    )
)