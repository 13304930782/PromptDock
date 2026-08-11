ALTER TABLE admin_users
  ADD COLUMN can_issue_roll_keys TINYINT(1) NOT NULL DEFAULT 0 AFTER status;

CREATE TABLE IF NOT EXISTS roll_access_keys (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  key_hash CHAR(64) NOT NULL,
  key_prefix VARCHAR(12) NOT NULL,
  created_by BIGINT UNSIGNED NULL,
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  last_used_at DATETIME NULL,
  use_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_roll_access_keys_hash (key_hash),
  KEY idx_roll_access_keys_expiry (expires_at),
  KEY idx_roll_access_keys_created (created_at),
  CONSTRAINT fk_roll_access_keys_admin
    FOREIGN KEY (created_by) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
