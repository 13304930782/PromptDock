INSERT INTO site_settings (setting_key, setting_value)
VALUES (
  'mail_transport',
  JSON_OBJECT(
    'configured', FALSE,
    'enabled', FALSE,
    'host', '',
    'port', 587,
    'secure', FALSE,
    'auth_required', TRUE,
    'timeout_ms', 20000,
    'helo_name', '',
    'user', '',
    'password_encrypted', '',
    'from', '',
    'reply_to', ''
  )
)
ON DUPLICATE KEY UPDATE setting_key=VALUES(setting_key);
