;; CoffeeTrace - Artisan coffee bean traceability and quality verification system
(define-map coffee-batches uint {
  roaster: principal,
  bean-origin: (string-utf8 64),
  roasting-profile: (string-utf8 256),
  harvest-date: uint,
  processing-method: (string-utf8 64),
  quality-certified: bool
})

(define-map roaster-inventory principal (list 100 uint))
(define-map coffee-curators principal bool)
(define-data-var batch-sequence-number uint u0)

;; Error codes
(define-constant err-not-roaster (err u500))
(define-constant err-not-curator (err u501))
(define-constant err-batch-not-found (err u502))
(define-constant err-access-denied (err u403))
(define-constant err-inventory-limit-exceeded (err u504))
(define-constant err-invalid-curator-address (err u505))
(define-constant err-invalid-bean-origin (err u506))
(define-constant err-invalid-roasting-profile (err u507))
(define-constant err-invalid-harvest-date (err u508))
(define-constant err-invalid-processing-method (err u509))
(define-constant err-invalid-batch-sequence (err u510))

;; Contract administrator for coffee curation
(define-constant contract-administrator tx-sender)

;; Register coffee curator
(define-public (register-coffee-curator (curator principal))
  (begin
    ;; Check if sender is contract administrator
    (asserts! (is-eq tx-sender contract-administrator) err-access-denied)
    
    ;; Validate curator principal
    (asserts! (not (is-eq curator 'SP000000000000000000002Q6VF78)) err-invalid-curator-address)
    
    ;; Add curator to registry
    (ok (map-set coffee-curators curator true))
  )
)

;; Register coffee batch
(define-public (register-coffee-batch 
  (bean-origin (string-utf8 64)) 
  (roasting-profile (string-utf8 256)) 
  (harvest-date uint) 
  (processing-method (string-utf8 64)))
  (let
    ((batch-id (var-get batch-sequence-number))
     (roaster tx-sender)
     (current-inventory (default-to (list) (map-get? roaster-inventory roaster))))
    
    ;; Validate inputs
    (asserts! (> (len bean-origin) u0) err-invalid-bean-origin)
    (asserts! (> (len roasting-profile) u0) err-invalid-roasting-profile)
    (asserts! (> harvest-date u1600000000) err-invalid-harvest-date)
    (asserts! (> (len processing-method) u0) err-invalid-processing-method)
    
    ;; Check inventory registration limit
    (asserts! (< (len current-inventory) u100) err-inventory-limit-exceeded)
    
    ;; Store coffee batch information
    (map-set coffee-batches batch-id {
      roaster: roaster,
      bean-origin: bean-origin,
      roasting-profile: roasting-profile,
      harvest-date: harvest-date,
      processing-method: processing-method,
      quality-certified: false
    })
    
    ;; Update roaster's inventory list
    (let 
      ((updated-inventory-list (unwrap-panic (as-max-len? (concat (list batch-id) current-inventory) u100))))
      (map-set roaster-inventory roaster updated-inventory-list)
    )
    
    ;; Increment batch sequence number
    (var-set batch-sequence-number (+ batch-id u1))
    
    (ok batch-id)))

;; Certify coffee quality
(define-public (certify-coffee-quality (batch-id uint))
  (begin
    ;; Validate batch ID
    (asserts! (< batch-id (var-get batch-sequence-number)) err-invalid-batch-sequence)
    
    (let
      ((coffee-batch (unwrap! (map-get? coffee-batches batch-id) err-batch-not-found)))
      
      ;; Check if sender is coffee curator
      (asserts! (default-to false (map-get? coffee-curators tx-sender)) err-not-curator)
      
      ;; Update coffee quality certification status
      (ok (map-set coffee-batches batch-id (merge coffee-batch {quality-certified: true})))
    )
  )
)

;; Get coffee batch details
(define-read-only (get-coffee-batch (batch-id uint))
  (map-get? coffee-batches batch-id))

;; Get roaster's inventory
(define-read-only (get-roaster-inventory (roaster principal))
  (default-to (list) (map-get? roaster-inventory roaster)))

;; Check coffee curator status
(define-read-only (is-coffee-curator (address principal))
  (default-to false (map-get? coffee-curators address)))