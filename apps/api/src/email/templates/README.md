# Email Templates

This folder holds transactional email templates for BYBATA.

## Structure

Templates are organized by feature area to match `email-template-registry.ts`.
Each email event now maps to its own template file.

- `auth/`
- `trade/`
- `gift/`
- `campaign/`
- `donation/`
- `wallet/`
- `community/`
- `chat/`
- `profile/`
- `verification/`
- `karma/`
- `ads/`
- `system/`

## Naming

Each template file should match its `templateId` in the registry:

`<feature>/<event-name>`

Example:

`auth/signup-welcome`

## Notes

- Use the same variables as defined in `EMAIL_TEMPLATE_REGISTRY`.
- Keep subject lines in the template metadata or provider config.
- Add a footer with unsubscribe/support links for non-transactional emails.
