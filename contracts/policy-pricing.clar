;; Policy Pricing Contract
;; Calculates cyber insurance policy premiums based on risk assessments

(define-constant ERR_INVALID_RISK_SCORE (err u400))
(define-constant ERR_INVALID_COVERAGE (err u401))
(define-constant ERR_POLICY_NOT_FOUND (err u402))

;; Base premium rates per risk category (in basis points)
(define-constant LOW_RISK_RATE u50)      ;; 0.5%
(define-constant MEDIUM_RISK_RATE u150)  ;; 1.5%
(define-constant HIGH_RISK_RATE u300)    ;; 3.0%
(define-constant CRITICAL_RISK_RATE u500) ;; 5.0%

(define-map policy-quotes
  { quote-id: uint }
  {
    entity: principal,
    coverage-amount: uint,
    risk-score: uint,
    risk-category: (string-ascii 20),
    base-premium: uint,
    adjusted-premium: uint,
    deductible: uint,
    policy-term: uint,
    quote-date: uint,
    quote-validity: uint
  }
)

(define-data-var next-quote-id uint u1)

;; Public functions
(define-public (generate-policy-quote
  (entity principal)
  (coverage-amount uint)
  (risk-score uint)
  (risk-category (string-ascii 20))
  (policy-term uint))
  (let (
    (quote-id (var-get next-quote-id))
    (base-premium (calculate-base-premium coverage-amount risk-category))
    (adjusted-premium (apply-risk-adjustments base-premium risk-score))
    (deductible (calculate-deductible coverage-amount risk-category))
  )
  (begin
    (asserts! (> coverage-amount u0) ERR_INVALID_COVERAGE)
    (asserts! (<= risk-score u100) ERR_INVALID_RISK_SCORE)

    (map-set policy-quotes
      { quote-id: quote-id }
      {
        entity: entity,
        coverage-amount: coverage-amount,
        risk-score: risk-score,
        risk-category: risk-category,
        base-premium: base-premium,
        adjusted-premium: adjusted-premium,
        deductible: deductible,
        policy-term: policy-term,
        quote-date: block-height,
        quote-validity: u72 ;; ~12 hours in blocks
      }
    )
    (var-set next-quote-id (+ quote-id u1))
    (ok quote-id)
  ))
)

;; Read-only functions
(define-read-only (get-policy-quote (quote-id uint))
  (map-get? policy-quotes { quote-id: quote-id })
)

(define-read-only (calculate-base-premium (coverage-amount uint) (risk-category (string-ascii 20)))
  (let (
    (rate (if (is-eq risk-category "low")
      LOW_RISK_RATE
      (if (is-eq risk-category "medium")
        MEDIUM_RISK_RATE
        (if (is-eq risk-category "high")
          HIGH_RISK_RATE
          CRITICAL_RISK_RATE
        )
      )
    ))
  )
  (/ (* coverage-amount rate) u10000))
)

(define-read-only (apply-risk-adjustments (base-premium uint) (risk-score uint))
  (let (
    (adjustment-factor (if (<= risk-score u20)
      u80  ;; 20% discount for very low risk
      (if (<= risk-score u40)
        u90  ;; 10% discount for low risk
        (if (<= risk-score u60)
          u100 ;; No adjustment for medium risk
          (if (<= risk-score u80)
            u120 ;; 20% increase for high risk
            u150 ;; 50% increase for very high risk
          )
        )
      )
    ))
  )
  (/ (* base-premium adjustment-factor) u100))
)

(define-read-only (calculate-deductible (coverage-amount uint) (risk-category (string-ascii 20)))
  (let (
    (deductible-rate (if (is-eq risk-category "low")
      u100  ;; 1%
      (if (is-eq risk-category "medium")
        u250  ;; 2.5%
        (if (is-eq risk-category "high")
          u500  ;; 5%
          u1000 ;; 10%
        )
      )
    ))
  )
  (/ (* coverage-amount deductible-rate) u10000))
)

(define-read-only (is-quote-valid (quote-id uint))
  (match (map-get? policy-quotes { quote-id: quote-id })
    quote-data (let (
      (quote-date (get quote-date quote-data))
      (quote-validity (get quote-validity quote-data))
    )
    (<= block-height (+ quote-date quote-validity)))
    false
  )
)
