import { EmailTemplateVariables } from './email.types';

const EMAIL_LINK_BASE =
  process.env.APP_DEEP_LINK_BASE_URL?.replace(/\/$/, '') || 'https://bybata.com';

const FALLBACK_OPEN_APP = `${EMAIL_LINK_BASE}/open-app`;

/**
 * Simple {{#if var}}...{{/if}} blocks (no else).
 */
export function processSimpleConditionals(
  html: string,
  vars: EmailTemplateVariables,
): string {
  return html.replace(
    /\{\{#if\s+(\w+)\}\}([\s\S]*?)\{\{\/if\}\}/g,
    (_, key: string, content: string) => {
      const val = vars[key];
      const truthy =
        val !== undefined &&
        val !== null &&
        val !== '' &&
        val !== false &&
        val !== 0;
      return truthy ? content : '';
    },
  );
}

export function replaceTemplateVars(
  html: string,
  vars: EmailTemplateVariables,
): string {
  return Object.entries(vars).reduce((acc, [key, value]) => {
    const token = new RegExp(`{{\\s*${key}\\s*}}`, 'g');
    return acc.replace(token, String(value ?? ''));
  }, html);
}

/**
 * Converts custom app schemes to HTTPS universal links email clients recognize.
 */
export function customSchemeToHttpsUrl(url: string): string {
  const trimmed = url.trim();
  if (!trimmed) return FALLBACK_OPEN_APP;

  const schemeMatch = trimmed.match(/^bybata:\/\/\/?(.*)$/i);
  if (schemeMatch) {
    const rawPath = schemeMatch[1] || '';
    if (rawPath.startsWith('invite?')) {
      return `${EMAIL_LINK_BASE}/open-app?${rawPath.split('?')[1] || ''}`;
    }
    const path = rawPath.startsWith('/') ? rawPath : `/${rawPath}`;
    return `${EMAIL_LINK_BASE}/open-app?path=${encodeURIComponent(path)}`;
  }

  return trimmed;
}

function isLikelyOtpCode(href: string): boolean {
  return /^\d{4,8}$/.test(href.trim());
}

function isSafeClickableHref(href: string): boolean {
  const h = href.trim();
  if (!h || h === '#') return false;
  if (isLikelyOtpCode(h)) return false;
  return /^https?:\/\//i.test(h) || /^mailto:/i.test(h);
}

/**
 * Ensures <a href> values are HTTPS (or mailto) and adds target/rel for buttons.
 */
export function normalizeEmailLinks(html: string): string {
  let out = html.replace(
    /<a\s+([^>]*?)href\s*=\s*"([^"]*)"([^>]*?)>/gi,
    (_match, before: string, href: string, after: string) => {
      let url = href.trim();

      if (/^bybata:\/\//i.test(url)) {
        url = customSchemeToHttpsUrl(url);
      } else if (!isSafeClickableHref(url)) {
        if (isLikelyOtpCode(url)) {
          // OTP displayed in span elsewhere; don't use code as href
          url = FALLBACK_OPEN_APP;
        } else if (!url || /^\{\{/.test(url)) {
          url = FALLBACK_OPEN_APP;
        } else if (url.startsWith('/')) {
          url = `${EMAIL_LINK_BASE}/open-app?path=${encodeURIComponent(url)}`;
        } else {
          url = FALLBACK_OPEN_APP;
        }
      }

      const attrs = `${before}href="${url}"${after}`;
      let extra = '';
      if (!/\btarget\s*=/i.test(attrs)) {
        extra += ' target="_blank"';
      }
      if (!/\brel\s*=/i.test(attrs)) {
        extra += ' rel="noopener noreferrer"';
      }
      const isButton = /\bbtn-3d\b/i.test(attrs) || /\bbtn-small\b/i.test(attrs);
      if (isButton && !/\bstyle\s*=/i.test(attrs)) {
        extra +=
          ' style="color:#ffffff !important;text-decoration:none !important;display:inline-block;"';
      } else if (!isButton && !/\bstyle\s*=/i.test(attrs)) {
        extra +=
          ' style="color:#7B2CBF !important;text-decoration:underline !important;"';
      }

      return `<a ${before}href="${url}"${after}${extra}>`;
    },
  );

  // Strip any leftover handlebars fragments that break layout
  out = out.replace(/\{\{[#/]?if\s+\w+\}\}/g, '');
  out = out.replace(/\{\{\/if\}\}/g, '');

  return injectEmailLinkStyles(out);
}

function injectEmailLinkStyles(html: string): string {
  const extraCss = `
        a { color: #7B2CBF !important; text-decoration: underline !important; pointer-events: auto !important; }
        .btn-3d, .btn-small, a.btn-3d, a.btn-small {
          color: #ffffff !important;
          text-decoration: none !important;
          pointer-events: auto !important;
          cursor: pointer !important;
        }
  `;
  if (html.includes('pointer-events: auto')) {
    return html;
  }
  const styleClose = html.indexOf('</style>');
  if (styleClose === -1) {
    return html;
  }
  return `${html.slice(0, styleClose)}${extraCss}${html.slice(styleClose)}`;
}

export function renderEmailHtml(
  raw: string,
  vars: EmailTemplateVariables,
): string {
  const withConditionals = processSimpleConditionals(raw, vars);
  const withVars = replaceTemplateVars(withConditionals, vars);
  return normalizeEmailLinks(withVars);
}
