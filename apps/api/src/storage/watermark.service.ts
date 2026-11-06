import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';

export interface WatermarkSettings {
  badgeHeightPercent: number;
  badgeHorizontalPaddingPercent: number;
  badgeBottomMarginPercent: number;
  badgeBgRed: number;
  badgeBgGreen: number;
  badgeBgBlue: number;
  badgeBgAlpha: number;
  glassOverlayRed: number;
  glassOverlayGreen: number;
  glassOverlayBlue: number;
  glassOverlayAlpha: number;
  glassMarginPercent: number;
  textRed: number;
  textGreen: number;
  textBlue: number;
  textAlpha: number;
  enableWatermarking: boolean;
  defaultOpacity: number;
}

/**
 * Manages global watermark configuration for all image uploads.
 * Admin-controlled settings that affect how watermarks are applied.
 */
@Injectable()
export class WatermarkService {
  private static instance: WatermarkService;
  private settings: WatermarkSettings;

  constructor(private prisma: PrismaService) {
    this.initializeDefaults();
  }

  /**
   * Initialize default watermark settings
   */
  private initializeDefaults() {
    this.settings = {
      badgeHeightPercent: 0.18,
      badgeHorizontalPaddingPercent: 0.06,
      badgeBottomMarginPercent: 0.03,
      badgeBgRed: 0,
      badgeBgGreen: 0,
      badgeBgBlue: 0,
      badgeBgAlpha: 160,
      glassOverlayRed: 255,
      glassOverlayGreen: 255,
      glassOverlayBlue: 255,
      glassOverlayAlpha: 40,
      glassMarginPercent: 0.01,
      textRed: 255,
      textGreen: 255,
      textBlue: 255,
      textAlpha: 255,
      enableWatermarking: true,
      defaultOpacity: 1.0,
    };
  }

  /**
   * Get current watermark settings
   */
  getSettings(): WatermarkSettings {
    return { ...this.settings };
  }

  /**
   * Update watermark settings (admin only)
   */
  async updateSettings(updates: Partial<WatermarkSettings>): Promise<WatermarkSettings> {
    // Validate color values
    this.validateColorValues(updates);
    // Validate percentages
    this.validatePercentages(updates);
    // Validate opacity
    if (updates.defaultOpacity !== undefined) {
      if (updates.defaultOpacity < 0 || updates.defaultOpacity > 1) {
        throw new BadRequestException('defaultOpacity must be between 0 and 1');
      }
    }

    // Update settings
    this.settings = { ...this.settings, ...updates };

    // Persist to database
    await this.persistSettings();

    return { ...this.settings };
  }

  /**
   * Reset to default settings
   */
  async resetToDefaults(): Promise<WatermarkSettings> {
    this.initializeDefaults();
    await this.persistSettings();
    return { ...this.settings };
  }

  /**
   * Load settings from database
   *
   * NOTE: The backing systemConfig table does not exist in the current
   * Prisma schema, so for now we operate purely on in-memory defaults.
   */
  async loadFromDatabase(): Promise<void> {
    // No-op until a backing config table is introduced.
    return;
  }

  /**
   * Persist settings to database
   *
   * NOTE: As above, this is currently a no-op because there is no
   * dedicated system configuration model in Prisma. This keeps the
   * service type-safe while allowing future persistence to be wired in
   * without breaking callers.
   */
  private async persistSettings(): Promise<void> {
    // No-op for now.
    return;
  }

  /**
   * Validate RGB color values (0-255)
   */
  private validateColorValues(updates: Partial<WatermarkSettings>): void {
    const colorFields = [
      'badgeBgRed',
      'badgeBgGreen',
      'badgeBgBlue',
      'badgeBgAlpha',
      'glassOverlayRed',
      'glassOverlayGreen',
      'glassOverlayBlue',
      'glassOverlayAlpha',
      'textRed',
      'textGreen',
      'textBlue',
      'textAlpha',
    ];

    for (const field of colorFields) {
      if (field in updates) {
        const value = updates[field as keyof WatermarkSettings] as number;
        if (value < 0 || value > 255) {
          throw new BadRequestException(
            `${field} must be between 0 and 255 (RGBA color value)`,
          );
        }
      }
    }
  }

  /**
   * Validate percentage values (0.0 to 1.0)
   */
  private validatePercentages(updates: Partial<WatermarkSettings>): void {
    const percentFields = [
      'badgeHeightPercent',
      'badgeHorizontalPaddingPercent',
      'badgeBottomMarginPercent',
      'glassMarginPercent',
    ];

    for (const field of percentFields) {
      if (field in updates) {
        const value = updates[field as keyof WatermarkSettings] as number;
        if (value < 0 || value > 1) {
          throw new BadRequestException(`${field} must be between 0 and 1`);
        }
      }
    }
  }

  /**
   * Disable watermarking globally
   */
  async disableWatermarking(): Promise<WatermarkSettings> {
    return this.updateSettings({ enableWatermarking: false });
  }

  /**
   * Enable watermarking globally
   */
  async enableWatermarking(): Promise<WatermarkSettings> {
    return this.updateSettings({ enableWatermarking: true });
  }
}
