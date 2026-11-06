import { Injectable } from '@nestjs/common';
import * as DOMPurify from 'isomorphic-dompurify';

/**
 * Input sanitization service for XSS prevention
 * 
 * Sanitizes user input to prevent XSS attacks
 * Uses DOMPurify for HTML sanitization
 */
@Injectable()
export class InputSanitizerService {
  /**
   * Sanitize HTML content to prevent XSS
   * 
   * @param dirty - Potentially unsafe HTML string
   * @param options - Sanitization options
   * @returns Sanitized HTML string
   */
  sanitizeHtml(dirty: string, options?: { allowedTags?: string[]; allowedAttributes?: Record<string, string[]> }): string {
    if (!dirty || typeof dirty !== 'string') {
      return '';
    }

    const config: DOMPurify.Config = {
      ALLOWED_TAGS: options?.allowedTags || ['p', 'br', 'strong', 'em', 'u', 'a', 'ul', 'ol', 'li'],
      ALLOWED_ATTR: options?.allowedAttributes 
        ? (Object.values(options.allowedAttributes).flat() as string[])
        : ['href', 'title'],
      ALLOW_DATA_ATTR: false,
    };

    return DOMPurify.sanitize(dirty, config);
  }

  /**
   * Sanitize plain text (removes all HTML)
   * 
   * @param dirty - Potentially unsafe string
   * @returns Sanitized plain text
   */
  sanitizeText(dirty: string): string {
    if (!dirty || typeof dirty !== 'string') {
      return '';
    }

    // Remove all HTML tags and decode HTML entities
    return DOMPurify.sanitize(dirty, { ALLOWED_TAGS: [] });
  }

  /**
   * Sanitize URL to prevent XSS and malicious redirects
   * 
   * @param url - Potentially unsafe URL
   * @returns Sanitized URL or empty string if invalid
   */
  sanitizeUrl(url: string): string {
    if (!url || typeof url !== 'string') {
      return '';
    }

    try {
      // Only allow http, https protocols
      const parsed = new URL(url);
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        return '';
      }
      return parsed.toString();
    } catch {
      return '';
    }
  }

  /**
   * Sanitize object recursively
   * 
   * @param obj - Object to sanitize
   * @param fields - Fields to sanitize (if not provided, sanitizes all string fields)
   * @returns Sanitized object
   */
  sanitizeObject<T extends Record<string, any>>(
    obj: T,
    fields?: string[],
    sanitizeType: 'html' | 'text' = 'text'
  ): T {
    if (!obj || typeof obj !== 'object') {
      return obj;
    }

    const sanitized = { ...obj };

    for (const key in sanitized) {
      if (fields && !fields.includes(key)) {
        continue;
      }

      const value = sanitized[key];

      if (typeof value === 'string') {
        (sanitized as any)[key] = sanitizeType === 'html' 
          ? this.sanitizeHtml(value)
          : this.sanitizeText(value);
      } else if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
        sanitized[key] = this.sanitizeObject(value, undefined, sanitizeType);
      } else if (Array.isArray(value)) {
        sanitized[key] = value.map((item) => {
          if (typeof item === 'string') {
            return sanitizeType === 'html' 
              ? this.sanitizeHtml(item)
              : this.sanitizeText(item);
          } else if (typeof item === 'object' && item !== null) {
            return this.sanitizeObject(item, undefined, sanitizeType);
          }
          return item;
        });
      }
    }

    return sanitized;
  }

  /**
   * Validate and sanitize SQL input (for Prisma, this is less critical but good practice)
   * Prisma uses parameterized queries, but we still validate input
   * 
   * @param input - Input to validate
   * @returns Sanitized input
   */
  sanitizeSqlInput(input: string): string {
    if (!input || typeof input !== 'string') {
      return '';
    }

    // Remove SQL injection patterns (Prisma handles this, but extra safety)
    const dangerousPatterns = [
      /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|SCRIPT)\b)/gi,
      /(--|#|\/\*|\*\/|;)/g,
      /(\bOR\b\s*\d+\s*=\s*\d+)/gi,
      /(\bAND\b\s*\d+\s*=\s*\d+)/gi,
    ];

    let sanitized = input;
    for (const pattern of dangerousPatterns) {
      sanitized = sanitized.replace(pattern, '');
    }

    return sanitized.trim();
  }
}

