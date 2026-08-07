CREATE TABLE IF NOT EXISTS feedback_access_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NULL,
  revoked_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_feedback_token_application (application_id),
  UNIQUE KEY uq_feedback_token_hash (token_hash),
  CONSTRAINT fk_feedback_token_application
    FOREIGN KEY (application_id) REFERENCES early_access_applications(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feedback_reports (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  application_id BIGINT UNSIGNED NOT NULL,
  category ENUM('bug', 'idea', 'ux', 'performance', 'other') NOT NULL,
  title VARCHAR(160) NOT NULL,
  details TEXT NOT NULL,
  steps TEXT NULL,
  expected TEXT NULL,
  actual TEXT NULL,
  device VARCHAR(120) NULL,
  macos_version VARCHAR(80) NULL,
  app_build VARCHAR(80) NULL,
  status ENUM('new', 'triaged', 'resolved') NOT NULL DEFAULT 'new',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_feedback_reports_created (created_at),
  KEY idx_feedback_reports_status (status),
  CONSTRAINT fk_feedback_report_application
    FOREIGN KEY (application_id) REFERENCES early_access_applications(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
