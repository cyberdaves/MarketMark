;; MarketMark - Commodity Prediction Market Platform
;; A decentralized prediction market for forecasting commodity price thresholds

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-market-closed (err u103))
(define-constant err-market-not-resolved (err u104))
(define-constant err-invalid-prediction (err u105))
(define-constant err-insufficient-stake (err u106))
(define-constant err-already-claimed (err u107))
(define-constant err-market-active (err u108))

;; Data Variables
(define-data-var market-counter uint u0)
(define-data-var min-stake uint u1000000) ;; 1 STX minimum

;; Market status types
(define-constant status-active u1)
(define-constant status-closed u2)
(define-constant status-resolved u3)

;; Prediction types
(define-constant predict-above u1)
(define-constant predict-below u2)

;; Data Maps
(define-map markets
  uint
  {
    commodity: (string-ascii 20),
    threshold-price: uint,
    resolution-block: uint,
    status: uint,
    total-above: uint,
    total-below: uint,
    final-price: (optional uint),
    actual-above-threshold: (optional bool),
    creator: principal
  }
)

(define-map predictions
  {market-id: uint, predictor: principal}
  {
    prediction: uint,
    stake: uint,
    claimed: bool
  }
)

(define-map user-market-count
  principal
  uint
)

;; Read-only functions
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

(define-read-only (get-prediction (market-id uint) (predictor principal))
  (map-get? predictions {market-id: market-id, predictor: predictor})
)

(define-read-only (get-market-count)
  (var-get market-counter)
)

(define-read-only (get-min-stake)
  (var-get min-stake)
)

(define-read-only (calculate-potential-reward (market-id uint) (predictor principal))
  (let
    (
      (market (unwrap! (get-market market-id) (err err-not-found)))
      (prediction (unwrap! (get-prediction market-id predictor) (err err-not-found)))
      (user-stake (get stake prediction))
      (user-prediction (get prediction prediction))
      (total-pool (+ (get total-above market) (get total-below market)))
      (winning-pool (if (is-eq user-prediction predict-above)
                       (get total-above market)
                       (get total-below market)))
    )
    (ok (/ (* user-stake total-pool) winning-pool))
  )
)

;; Public functions
(define-public (create-market 
  (commodity (string-ascii 20))
  (threshold-price uint)
  (duration-blocks uint))
  (let
    (
      (market-id (+ (var-get market-counter) u1))
      (resolution-block (+ stacks-block-height duration-blocks))
    )
    (asserts! (> duration-blocks u0) err-invalid-prediction)
    (asserts! (> threshold-price u0) err-invalid-prediction)
    
    (map-set markets market-id
      {
        commodity: commodity,
        threshold-price: threshold-price,
        resolution-block: resolution-block,
        status: status-active,
        total-above: u0,
        total-below: u0,
        final-price: none,
        actual-above-threshold: none,
        creator: tx-sender
      }
    )
    
    (var-set market-counter market-id)
    (ok market-id)
  )
)

(define-public (make-prediction (market-id uint) (prediction uint) (stake-amount uint))
  (let
    (
      (market (unwrap! (get-market market-id) err-not-found))
      (existing-prediction (get-prediction market-id tx-sender))
    )
    (asserts! (is-eq (get status market) status-active) err-market-closed)
    (asserts! (< stacks-block-height (get resolution-block market)) err-market-closed)
    (asserts! (or (is-eq prediction predict-above) (is-eq prediction predict-below)) err-invalid-prediction)
    (asserts! (>= stake-amount (var-get min-stake)) err-insufficient-stake)
    (asserts! (is-none existing-prediction) err-already-exists)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Update market totals
    (if (is-eq prediction predict-above)
      (map-set markets market-id
        (merge market {total-above: (+ (get total-above market) stake-amount)}))
      (map-set markets market-id
        (merge market {total-below: (+ (get total-below market) stake-amount)}))
    )
    
    ;; Record prediction
    (map-set predictions
      {market-id: market-id, predictor: tx-sender}
      {
        prediction: prediction,
        stake: stake-amount,
        claimed: false
      }
    )
    
    ;; Update user market count
    (map-set user-market-count tx-sender
      (+ (default-to u0 (map-get? user-market-count tx-sender)) u1))
    
    (ok true)
  )
)

(define-public (resolve-market (market-id uint) (final-price uint))
  (let
    (
      (market (unwrap! (get-market market-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status market) status-active) err-market-closed)
    (asserts! (>= stacks-block-height (get resolution-block market)) err-market-active)
    
    (let
      (
        (above-threshold (>= final-price (get threshold-price market)))
      )
      (map-set markets market-id
        (merge market {
          status: status-resolved,
          final-price: (some final-price),
          actual-above-threshold: (some above-threshold)
        })
      )
      (ok above-threshold)
    )
  )
)

(define-public (claim-reward (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) err-not-found))
      (prediction (unwrap! (get-prediction market-id tx-sender) err-not-found))
      (user-stake (get stake prediction))
      (user-prediction (get prediction prediction))
    )
    (asserts! (is-eq (get status market) status-resolved) err-market-not-resolved)
    (asserts! (not (get claimed prediction)) err-already-claimed)
    
    (let
      (
        (actual-result (unwrap! (get actual-above-threshold market) err-market-not-resolved))
        (won (if actual-result
               (is-eq user-prediction predict-above)
               (is-eq user-prediction predict-below)))
      )
      (if won
        (let
          (
            (total-pool (+ (get total-above market) (get total-below market)))
            (winning-pool (if actual-result (get total-above market) (get total-below market)))
            (reward (/ (* user-stake total-pool) winning-pool))
          )
          ;; Mark as claimed
          (map-set predictions
            {market-id: market-id, predictor: tx-sender}
            (merge prediction {claimed: true}))
          
          ;; Transfer reward
          (as-contract (stx-transfer? reward tx-sender tx-sender))
        )
        ;; Lost prediction - mark as claimed but no reward
        (begin
          (map-set predictions
            {market-id: market-id, predictor: tx-sender}
            (merge prediction {claimed: true}))
          (ok true)
        )
      )
    )
  )
)

(define-public (close-market (market-id uint))
  (let
    (
      (market (unwrap! (get-market market-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status market) status-active) err-market-closed)
    
    (map-set markets market-id
      (merge market {status: status-closed}))
    (ok true)
  )
)

(define-public (update-min-stake (new-min uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-stake new-min)
    (ok true)
  )
)