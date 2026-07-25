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
