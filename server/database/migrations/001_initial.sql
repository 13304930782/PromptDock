CREATE TABLE IF NOT EXISTS admin_users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  email VARCHAR(160) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('owner', 'admin') NOT NULL DEFAULT 'admin',
  status ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
  failed_login_count INT UNSIGNED NOT NULL DEFAULT 0,
  locked_until DATETIME NULL,
  last_login_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_users_email (email),
  KEY idx_admin_users_status (status),
  KEY idx_admin_users_locked_until (locked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS admin_password_resets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_password_resets_token (token_hash),
  KEY idx_admin_password_resets_admin (admin_id),
  KEY idx_admin_password_resets_expiry (expires_at),
  CONSTRAINT fk_admin_password_resets_admin
    FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS early_access_applications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  full_name VARCHAR(80) NOT NULL,
  email VARCHAR(160) NOT NULL,
  role ENUM('student', 'creator', 'developer', 'researcher', 'product', 'other') NOT NULL,
  use_case TEXT NOT NULL,
  motivation TEXT NOT NULL,
  locale ENUM('zh', 'en') NOT NULL DEFAULT 'zh',
  cohort VARCHAR(80) NOT NULL,
  status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
  reviewer_id BIGINT UNSIGNED NULL,
  internal_note TEXT NULL,
  applicant_message TEXT NULL,
  consented_at DATETIME NOT NULL,
  reviewed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_early_access_email_cohort (email, cohort),
  KEY idx_early_access_status_created (status, created_at),
  KEY idx_early_access_reviewer (reviewer_id),
  CONSTRAINT fk_early_access_reviewer
    FOREIGN KEY (reviewer_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mail_delivery_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id BIGINT UNSIGNED NULL,
  mail_kind ENUM('new_application', 'approved', 'rejected', 'password_reset', 'test') NOT NULL,
  locale ENUM('zh', 'en') NOT NULL DEFAULT 'en',
  recipient VARCHAR(160) NOT NULL,
  subject VARCHAR(255) NOT NULL,
  status ENUM('sent', 'failed') NOT NULL,
  attempt_number INT UNSIGNED NOT NULL DEFAULT 1,
  error_message VARCHAR(500) NULL,
  sent_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_mail_application_kind (application_id, mail_kind, id),
  KEY idx_mail_status_created (status, created_at),
  KEY idx_mail_recipient_created (recipient, created_at),
  CONSTRAINT fk_mail_application
    FOREIGN KEY (application_id) REFERENCES early_access_applications(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS site_settings (
  setting_key VARCHAR(100) NOT NULL,
  setting_value JSON NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO site_settings (setting_key, setting_value)
VALUES (
  'early_access',
  JSON_OBJECT(
    'applications_open', TRUE,
    'cohort', 'promptdock-early-access-1',
    'download_url', '',
    'feedback_url', '',
    'notify_email', '',
    'notify_on_new_application', FALSE
  )
)
ON DUPLICATE KEY UPDATE setting_key=VALUES(setting_key);
