import { EmailEventName } from './email-events';

export interface EmailRecipient {
  email: string;
  displayName?: string;
  userId?: string;
  locale?: string;
}

export type EmailTemplateVariables = Record<string, string | number | boolean | null>;

export interface EmailDispatchInput {
  eventName: EmailEventName;
  recipient: EmailRecipient;
  vars: EmailTemplateVariables;
  locale?: string;
  category?: string;
  subject?: string;
  metadata?: Record<string, string | number | boolean | null>;
}

export interface EmailTemplateSpec {
  templateId: string;
  requiredVars: string[];
}
