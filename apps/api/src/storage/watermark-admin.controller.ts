import {
  Controller,
  Get,
  Patch,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { WatermarkService } from './watermark.service';
import type { WatermarkSettings } from './watermark.service';
import { AdminGuard } from '../auth/admin.guard';

/**
 * Admin-only endpoints for managing watermark configuration
 * All endpoints require admin authentication
 */
@Controller('v1/admin/watermark')
@UseGuards(AdminGuard)
export class WatermarkAdminController {
  constructor(private watermarkService: WatermarkService) {}

  /**
   * GET /v1/admin/watermark
   * Retrieve current watermark settings
   */
  @Get()
  getSettings(): WatermarkSettings {
    return this.watermarkService.getSettings();
  }

  /**
   * PATCH /v1/admin/watermark
   * Update watermark settings
   * Supports partial updates
   */
  @Patch()
  async updateSettings(
    @Body() updates: Partial<WatermarkSettings>,
  ): Promise<WatermarkSettings> {
    return this.watermarkService.updateSettings(updates);
  }

  /**
   * POST /v1/admin/watermark/reset
   * Reset watermark settings to defaults
   */
  @Post('reset')
  @HttpCode(HttpStatus.OK)
  async resetToDefaults(): Promise<WatermarkSettings> {
    return this.watermarkService.resetToDefaults();
  }

  /**
   * POST /v1/admin/watermark/disable
   * Disable watermarking globally
   */
  @Post('disable')
  @HttpCode(HttpStatus.OK)
  async disableWatermarking(): Promise<WatermarkSettings> {
    return this.watermarkService.disableWatermarking();
  }

  /**
   * POST /v1/admin/watermark/enable
   * Enable watermarking globally
   */
  @Post('enable')
  @HttpCode(HttpStatus.OK)
  async enableWatermarking(): Promise<WatermarkSettings> {
    return this.watermarkService.enableWatermarking();
  }
}
