import { Injectable } from '@nestjs/common';

/** Base URL for app deep links - opens app when installed, else loads bybata.com */
const APP_DEEP_LINK_BASE = process.env.APP_DEEP_LINK_BASE_URL || 'https://bybata.com';

/** Production fallback when APP_PUBLIC_URL is localhost */
const PRODUCTION_WEB_FALLBACK = 'https://bybata.com';

/**
 * Email Link Router Service
 *
 * Generates HTTPS universal links for transactional emails.
 * Email clients (Gmail, Outlook, Apple Mail) do NOT reliably make custom
 * schemes (bybata://) clickable — always use https://bybata.com/open-app?path=...
 */
@Injectable()
export class EmailLinkRouterService {
  /**
   * Get the app-open link for emails (Login to Dashboard, Open App, etc.).
   */
  getAppOpenLink(path?: string): string {
    const base = APP_DEEP_LINK_BASE.replace(/\/$/, '');
    if (path) {
      const normalized = path.startsWith('/') ? path : `/${path}`;
      return `${base}/open-app?path=${encodeURIComponent(normalized)}`;
    }
    return `${base}/open-app`;
  }

  /**
   * Get web link for emails. When APP_PUBLIC_URL is localhost, use production fallback.
   */
  private getEmailSafeBaseUrl(): string {
    const url = process.env.APP_PUBLIC_URL || 'http://localhost:3001';
    if (url.includes('localhost') || url.includes('127.0.0.1')) {
      return PRODUCTION_WEB_FALLBACK;
    }
    return url.replace(/\/$/, '');
  }

  private universalPathLink(path: string): string {
    const base = this.getEmailSafeBaseUrl();
    const normalized = path.startsWith('/') ? path : `/${path}`;
    return `${base}/open-app?path=${encodeURIComponent(normalized)}`;
  }

  getCampaignLink(campaignId: string, _preferMobile = false): string {
    return this.universalPathLink(`/campaign/${campaignId}`);
  }

  getTradeLink(tradeId: string, _preferMobile = false): string {
    return this.universalPathLink(`/trade/${tradeId}`);
  }

  getGiftLink(giftId: string, _preferMobile = false): string {
    return this.universalPathLink(`/gift/${giftId}`);
  }

  getCommunityLink(communityId: string, _preferMobile = false): string {
    return this.universalPathLink(`/community/${communityId}`);
  }

  getChatLink(conversationId: string, _preferMobile = false): string {
    return this.universalPathLink(`/chat/${conversationId}`);
  }

  getProfileLink(username: string, _preferMobile = false): string {
    return this.universalPathLink(`/profile/${encodeURIComponent(username)}`);
  }

  getCommunityInviteLink(inviteCode: string, _preferMobile = false): string {
    const base = this.getEmailSafeBaseUrl();
    return `${base}/open-app?code=${encodeURIComponent(inviteCode)}`;
  }

  getWebLink(path: string): string {
    const baseUrl = this.getEmailSafeBaseUrl();
    return `${baseUrl}${path.startsWith('/') ? '' : '/'}${path}`;
  }

  getAdminDashboardLink(): string {
    return (
      process.env.ADMIN_URL ||
      process.env.APP_PUBLIC_URL ||
      'http://localhost:3001'
    );
  }
}
