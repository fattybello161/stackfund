;; stackfund-plus.clar
;; Enhanced crowdfunding contract for the Stacks blockchain
;; Includes donations, refunds, rewards, campaign editing, cancellation, and fee system

;; ---------------------------------
;; ERRORS
;; ---------------------------------
(define-constant ERR_NOT_CREATOR u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_GOAL_NOT_REACHED u102)
(define-constant ERR_ALREADY_WITHDRAWN u103)
(define-constant ERR_NOT_FUNDED u104)
(define-constant ERR_REFUND_NOT_AVAILABLE u105)
(define-constant ERR_CAMPAIGN_NOT_FOUND u106)
(define-constant ERR_CAMPAIGN_ACTIVE u107)
(define-constant ERR_INVALID_CATEGORY u108)
(define-constant ERR_NOT_OWNER u109)

;; ---------------------------------
;; GLOBAL STATE
;; ---------------------------------
(define-data-var next-campaign-id uint u0)
(define-data-var platform-owner principal tx-sender)
(define-data-var platform-fee-rate uint u3) ;; 3% platform fee

;; ---------------------------------
;; DATA MAPS
;; ---------------------------------
(define-map campaigns
  uint
  (tuple
    (creator principal)
    (title (string-ascii 64))
    (description (string-ascii 256))
    (goal uint)
    (deadline uint)
    (funds-raised uint)
    (withdrawn bool)
    (successful bool)
    (category (string-ascii 32))
    (top-donor (optional principal))
    (top-donation uint)
  )
)

(define-map contributions
  (tuple (campaign-id uint) (donor principal))
  uint
)

;; ---------------------------------
;; EVENTS (Not directly supported in Clarity, using comments for now)
;; ---------------------------------
;; campaign-created (id uint) (creator principal)
;; contributed (campaign-id uint) (donor principal) (amount uint)
;; withdrawn (campaign-id uint) (creator principal)
;; refunded (campaign-id uint) (donor principal) (amount uint)
;; canceled (campaign-id uint) (creator principal)
;; updated (campaign-id uint) (new-goal uint) (new-deadline uint)

;; ---------------------------------
;; PRIVATE HELPERS
;; ---------------------------------

(define-private (only-owner)
  (if (is-eq tx-sender (var-get platform-owner))
      (ok true)
      (err ERR_NOT_OWNER))
)

(define-private (fee-amount (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u100)
)

;; ---------------------------------
;; CORE FUNCTIONS
;; ---------------------------------

;; 1 Create campaign
(define-public (create-campaign
  (title (string-ascii 64))
  (desc (string-ascii 256))
  (goal uint)
  (duration uint)
  (category (string-ascii 32))
)
  (if (and (> goal u0) (> duration u0))
      (let ((id (+ (var-get next-campaign-id) u1)))
        (begin
          (map-set campaigns id
            (tuple
              (creator tx-sender)
              (title title)
              (description desc)
              (goal goal)
              (deadline (+ burn-block-height duration))
              (funds-raised u0)
              (withdrawn false)
              (successful false)
              (category category)
              (top-donor none)
              (top-donation u0)
            ))
          (var-set next-campaign-id id)
          (ok (tuple (campaign-id id) (goal goal)))))
      (err ERR_INVALID_AMOUNT))
)

;; 2 Contribute to campaign
(define-public (contribute (campaign-id uint))
  (let ((campaign (map-get? campaigns campaign-id)))
    (match campaign
      c
        (if (<= burn-block-height (get deadline c))
            (begin
              (map-set campaigns campaign-id
                (tuple
                  (creator (get creator c))
                  (title (get title c))
                  (description (get description c))
                  (goal (get goal c))
                  (deadline (get deadline c))
                  (funds-raised (+ (get funds-raised c) (stx-get-balance (as-contract tx-sender))))
                  (withdrawn (get withdrawn c))
                  (successful (get successful c))
                  (category (get category c))
                  (top-donor (get top-donor c))
                  (top-donation (get top-donation c))))
              (map-set contributions (tuple (campaign-id campaign-id) (donor tx-sender))
                (+ (default-to u0 (map-get? contributions (tuple (campaign-id campaign-id) (donor tx-sender)))) (stx-get-balance (as-contract tx-sender))))
              (ok true))
            (err ERR_REFUND_NOT_AVAILABLE))
        (err ERR_CAMPAIGN_NOT_FOUND)))
)

;; 3 Withdraw funds + apply 3% fee
(define-public (withdraw-funds (campaign-id uint))
  (let ((campaign (map-get? campaigns campaign-id)))
    (match campaign
      c
        (if (is-eq tx-sender (get creator c))
            (if (and (>= (get funds-raised c) (get goal c)) (not (get withdrawn c)))
                (let (
                      (total (get funds-raised c))
                      (fee (fee-amount total))
                      (creator-amount (- total fee))
                    )
                  (begin
                    ;; pay fee to platform
                    (try! (stx-transfer? fee tx-sender (var-get platform-owner)))
                    ;; pay remaining to creator
                    (try! (stx-transfer? creator-amount tx-sender tx-sender))
                    (map-set campaigns campaign-id
                      (tuple
                        (creator (get creator c))
                        (title (get title c))
                        (description (get description c))
                        (goal (get goal c))
                        (deadline (get deadline c))
                        (funds-raised (get funds-raised c))
                        (withdrawn true)
                        (successful true)
                        (category (get category c))
                        (top-donor (get top-donor c))
                        (top-donation (get top-donation c))))
                    (ok (tuple (withdrawn creator-amount) (fee fee)))))
                (err ERR_GOAL_NOT_REACHED))
            (err ERR_NOT_CREATOR))
      (err ERR_CAMPAIGN_NOT_FOUND)))
)

;; 4 Refund donors if failed
(define-public (refund (campaign-id uint))
  (let ((campaign (map-get? campaigns campaign-id)))
    (match campaign
      c
        (if (and (> burn-block-height (get deadline c))
                 (< (get funds-raised c) (get goal c)))
            (let ((contrib (default-to u0 (map-get? contributions (tuple (campaign-id campaign-id) (donor tx-sender))))))
              (if (> contrib u0)
                  (begin
                    (try! (stx-transfer? contrib tx-sender tx-sender))
                    (map-set contributions (tuple (campaign-id campaign-id) (donor tx-sender)) u0)
                    (ok (tuple (refunded contrib))))
                  (err ERR_NOT_FUNDED)))
            (err ERR_REFUND_NOT_AVAILABLE))
      (err ERR_CAMPAIGN_NOT_FOUND)))
)

;; 5 Cancel campaign (creator only, before deadline)
(define-public (cancel-campaign (campaign-id uint))
  (let ((campaign (map-get? campaigns campaign-id)))
    (match campaign
      c
        (if (is-eq tx-sender (get creator c))
            (if (<= burn-block-height (get deadline c))
                (begin
                  (map-set campaigns campaign-id
                    (tuple
                      (creator (get creator c))
                      (title (get title c))
                      (description (get description c))
                      (goal (get goal c))
                      (deadline (get deadline c))
                      (funds-raised (get funds-raised c))
                      (withdrawn true)
                      (successful false)
                      (category (get category c))
                      (top-donor (get top-donor c))
                      (top-donation (get top-donation c))))
                  (ok "Campaign canceled"))
                (err ERR_CAMPAIGN_ACTIVE))
            (err ERR_NOT_CREATOR))
      (err ERR_CAMPAIGN_NOT_FOUND)))
)

;; 6 Update campaign details (before deadline)
(define-public (update-campaign (campaign-id uint) (new-goal uint) (extra-duration uint))
  (let ((campaign (map-get? campaigns campaign-id)))
    (match campaign
      c
        (if (is-eq tx-sender (get creator c))
            (if (<= burn-block-height (get deadline c))
                (begin
                  (map-set campaigns campaign-id
                    (tuple
                      (creator (get creator c))
                      (title (get title c))
                      (description (get description c))
                      (goal new-goal)
                      (deadline (+ (get deadline c) extra-duration))
                      (funds-raised (get funds-raised c))
                      (withdrawn (get withdrawn c))
                      (successful (get successful c))
                      (category (get category c))
                      (top-donor (get top-donor c))
                      (top-donation (get top-donation c))))
                  (ok (tuple (new-goal new-goal) (new-deadline (+ (get deadline c) extra-duration)))))
                (err ERR_CAMPAIGN_ACTIVE))
            (err ERR_NOT_CREATOR))
      (err ERR_CAMPAIGN_NOT_FOUND)))
)

;; ---------------------------------
;; READ-ONLY FUNCTIONS
;; ---------------------------------

(define-read-only (get-campaign (id uint))
  (map-get? campaigns id)
)

(define-read-only (get-donation (id uint) (donor principal))
  (default-to u0 (map-get? contributions (tuple (campaign-id id) (donor donor))))
)

(define-read-only (get-top-donor (id uint))
  (let ((c (map-get? campaigns id)))
    (match c
      cam (get top-donor cam)
      none))
)

(define-read-only (get-total-campaigns)
  (var-get next-campaign-id)
)
