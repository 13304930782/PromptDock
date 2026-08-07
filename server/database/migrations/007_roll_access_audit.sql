CREATE TABLE IF NOT EXISTS roll_access_key_audit (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  key_id BIGINT UNSIGNED NOT NULL,
  key_prefix VARCHAR(12) NOT NULL,
  admin_id BIGINT UNSIGNED NULL,
  action ENUM('create', 'revoke', 'delete', 'bulk_delete') NOT NULL,
  batch_id CHAR(36) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_roll_access_audit_key (key_id),
  KEY idx_roll_access_audit_admin (admin_id),
  KEY idx_roll_access_audit_created (created_at),
  KEY idx_roll_access_audit_batch (batch_id),
  CONSTRAINT fk_roll_access_audit_admin
    FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
