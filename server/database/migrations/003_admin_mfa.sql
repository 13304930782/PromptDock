ALTER TABLE admin_users
  ADD COLUMN mfa_secret_encrypted TEXT NULL,
  ADD COLUMN mfa_setup_expires_at DATETIME NULL,
  ADD COLUMN mfa_enabled_at DATETIME NULL,
  ADD COLUMN mfa_recovery_hashes JSON NULL,
  ADD COLUMN mfa_last_used_step BIGINT UNSIGNED NULL;
