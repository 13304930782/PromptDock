export type AdminUser = {
  id: number;
  name: string;
  email: string;
  role: 'owner' | 'admin';
};

export type EarlyAccessSettings = {
  applications_open: boolean;
  cohort: string;
  download_url: string;
  feedback_url: string;
  notify_email: string;
  notify_on_new_application: boolean;
};

export type MailSettings = {
  configured: boolean;
  source: 'environment' | 'database';
  enabled: boolean;
  ready: boolean;
  host: string;
  port: number;
  secure: boolean;
  auth_required: boolean;
  timeout_ms: number;
  helo_name: string;
  user: string;
  password_configured: boolean;
  from: string;
  reply_to: string;
  configuration_error: string;
};

export type ManagedAdminUser = AdminUser & {
  status: 'active' | 'disabled';
  failed_login_count: number;
  locked_until: string | null;
  last_login_at: string | null;
  created_at: string;
};

export type Application = {
  id: number;
  full_name: string;
  email: string;
  role: string;
  use_case: string;
  motivation: string;
  locale: 'zh' | 'en';
  cohort: string;
  status: 'pending' | 'approved' | 'rejected';
  reviewer_name: string | null;
  internal_note: string | null;
  applicant_message: string | null;
  reviewed_at: string | null;
  created_at: string;
  latest_email_status: 'sent' | 'failed' | null;
  latest_email_error: string | null;
};
