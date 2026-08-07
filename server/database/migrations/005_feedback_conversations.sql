CREATE TABLE IF NOT EXISTS feedback_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  report_id BIGINT UNSIGNED NOT NULL,
  author_type ENUM('tester', 'developer') NOT NULL,
  admin_id BIGINT UNSIGNED NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_feedback_messages_report_created (report_id, created_at, id),
  CONSTRAINT fk_feedback_message_report
    FOREIGN KEY (report_id) REFERENCES feedback_reports(id) ON DELETE CASCADE,
  CONSTRAINT fk_feedback_message_admin
    FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE feedback_access_tokens
  ADD KEY idx_feedback_token_application (application_id),
  DROP INDEX uq_feedback_token_application;

ALTER TABLE mail_delivery_logs
  MODIFY mail_kind ENUM(
    'new_application',
    'approved',
    'rejected',
    'password_reset',
    'test',
    'feedback_to_owner',
    'feedback_to_tester'
  ) NOT NULL;
