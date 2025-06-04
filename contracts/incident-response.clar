;; Incident Response Contract
;; Manages cyber incident reporting and response coordination

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INCIDENT_NOT_FOUND (err u501))
(define-constant ERR_INVALID_SEVERITY (err u502))
(define-constant ERR_INVALID_STATUS (err u503))

;; Incident severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

(define-map cyber-incidents
  { incident-id: uint }
  {
    reporter: principal,
    affected-entity: principal,
    incident-type: (string-ascii 50),
    severity: uint,
    description: (string-ascii 500),
    impact-assessment: uint,
    estimated-loss: uint,
    report-date: uint,
    status: (string-ascii 20),
    response-team: (optional principal),
    resolution-date: (optional uint)
  }
)

(define-map incident-updates
  { incident-id: uint, update-id: uint }
  {
    updater: principal,
    update-type: (string-ascii 30),
    description: (string-ascii 300),
    timestamp: uint,
    status-change: (optional (string-ascii 20))
  }
)

(define-data-var next-incident-id uint u1)

;; Public functions
(define-public (report-incident
  (affected-entity principal)
  (incident-type (string-ascii 50))
  (severity uint)
  (description (string-ascii 500))
  (estimated-loss uint))
  (let ((incident-id (var-get next-incident-id)))
    (begin
      (asserts! (<= severity u4) ERR_INVALID_SEVERITY)
      (asserts! (>= severity u1) ERR_INVALID_SEVERITY)

      (map-set cyber-incidents
        { incident-id: incident-id }
        {
          reporter: tx-sender,
          affected-entity: affected-entity,
          incident-type: incident-type,
          severity: severity,
          description: description,
          impact-assessment: (calculate-impact-score severity estimated-loss),
          estimated-loss: estimated-loss,
          report-date: block-height,
          status: "reported",
          response-team: none,
          resolution-date: none
        }
      )
      (var-set next-incident-id (+ incident-id u1))
      (ok incident-id)
    )
  )
)

(define-public (assign-response-team (incident-id uint) (response-team principal))
  (match (map-get? cyber-incidents { incident-id: incident-id })
    incident-data (begin
      (map-set cyber-incidents
        { incident-id: incident-id }
        (merge incident-data {
          response-team: (some response-team),
          status: "assigned"
        })
      )
      (ok true)
    )
    ERR_INCIDENT_NOT_FOUND
  )
)

(define-public (update-incident-status
  (incident-id uint)
  (new-status (string-ascii 20))
  (update-description (string-ascii 300)))
  (match (map-get? cyber-incidents { incident-id: incident-id })
    incident-data (let (
      (updated-incident (merge incident-data { status: new-status }))
      (final-incident (if (is-eq new-status "resolved")
        (merge updated-incident { resolution-date: (some block-height) })
        updated-incident
      ))
    )
    (begin
      (map-set cyber-incidents { incident-id: incident-id } final-incident)
      (add-incident-update incident-id "status-change" update-description (some new-status))
      (ok true)
    ))
    ERR_INCIDENT_NOT_FOUND
  )
)

(define-public (add-incident-update
  (incident-id uint)
  (update-type (string-ascii 30))
  (description (string-ascii 300))
  (status-change (optional (string-ascii 20))))
  (let ((update-id (get-next-update-id incident-id)))
    (begin
      (map-set incident-updates
        { incident-id: incident-id, update-id: update-id }
        {
          updater: tx-sender,
          update-type: update-type,
          description: description,
          timestamp: block-height,
          status-change: status-change
        }
      )
      (ok update-id)
    )
  )
)

;; Read-only functions
(define-read-only (get-incident (incident-id uint))
  (map-get? cyber-incidents { incident-id: incident-id })
)

(define-read-only (get-incident-update (incident-id uint) (update-id uint))
  (map-get? incident-updates { incident-id: incident-id, update-id: update-id })
)

(define-read-only (calculate-impact-score (severity uint) (estimated-loss uint))
  (let (
    (severity-multiplier (if (is-eq severity u1)
      u1
      (if (is-eq severity u2)
        u3
        (if (is-eq severity u3)
          u7
          u10
        )
      )
    ))
    (loss-factor (if (<= estimated-loss u10000)
      u1
      (if (<= estimated-loss u100000)
        u3
        (if (<= estimated-loss u1000000)
          u7
          u10
        )
      )
    ))
  )
  (* severity-multiplier loss-factor))
)

(define-read-only (get-next-update-id (incident-id uint))
  ;; Simplified - in production, would track per incident
  u1
)

(define-read-only (get-incident-statistics (entity principal))
  ;; Returns basic stats for an entity's incidents
  ;; In production, would aggregate from incident data
  { total-incidents: u0, resolved-incidents: u0, average-resolution-time: u0 }
)
