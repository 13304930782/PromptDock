export type AdminUser = {
  id: number;
  name: string;
  email: string;
  role: 'owner' | 'admin';
  mfa_enabled: boolean;
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

export type FeedbackReport = {
  id: number;
  application_id: number;
  category: 'bug' | 'idea' | 'ux' | 'performance' | 'other';
  title: string;
  details: string;
  steps: string | null;
  expected: string | null;
  actual: string | null;
  device: string | null;
  macos_version: string | null;
  app_build: string | null;
  status: 'new' | 'triaged' | 'resolved';
  created_at: string;
  updated_at: string;
  full_name: string;
  email: string;
  cohort: string;
};
