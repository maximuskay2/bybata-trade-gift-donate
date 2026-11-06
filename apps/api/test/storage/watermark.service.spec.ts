import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { WatermarkService } from '../watermark.service';
import { PrismaService } from '../../common/prisma.service';

describe('WatermarkService', () => {
  let service: WatermarkService;
  let prismaMock: Partial<PrismaService>;

  beforeEach(async () => {
    prismaMock = {
      systemConfig: {
        findUnique: jest.fn(),
        upsert: jest.fn(),
      } as any,
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WatermarkService,
        {
          provide: PrismaService,
          useValue: prismaMock,
        },
      ],
    }).compile();

    service = module.get<WatermarkService>(WatermarkService);
  });

  describe('getSettings', () => {
    it('should return default settings on initialization', () => {
      const settings = service.getSettings();

      expect(settings).toBeDefined();
      expect(settings.enableWatermarking).toBe(true);
      expect(settings.defaultOpacity).toBe(1.0);
      expect(settings.badgeBgAlpha).toBe(160);
    });

    it('should return a copy of settings, not reference', () => {
      const settings1 = service.getSettings();
      const settings2 = service.getSettings();

      expect(settings1).not.toBe(settings2);
      expect(settings1).toEqual(settings2);
    });
  });

  describe('updateSettings', () => {
    it('should update single property', async () => {
      const updated = await service.updateSettings({
        defaultOpacity: 0.8,
      });

      expect(updated.defaultOpacity).toBe(0.8);
    });

    it('should update multiple properties', async () => {
      const updated = await service.updateSettings({
        defaultOpacity: 0.7,
        enableWatermarking: false,
        badgeBgAlpha: 200,
      });

      expect(updated.defaultOpacity).toBe(0.7);
      expect(updated.enableWatermarking).toBe(false);
      expect(updated.badgeBgAlpha).toBe(200);
    });

    it('should validate color values (0-255)', async () => {
      const invalidColor = {
        badgeBgRed: 256, // Invalid
      };

      await expect(service.updateSettings(invalidColor)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should reject negative color values', async () => {
      const negativeColor = {
        badgeBgGreen: -1,
      };

      await expect(service.updateSettings(negativeColor)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should validate percentage values (0-1)', async () => {
      const invalidPercent = {
        badgeHeightPercent: 1.5, // Invalid
      };

      await expect(service.updateSettings(invalidPercent)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should validate opacity (0-1)', async () => {
      const invalidOpacity = {
        defaultOpacity: 1.5,
      };

      await expect(service.updateSettings(invalidOpacity)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should accept boundary values for colors (0 and 255)', async () => {
      const updated = await service.updateSettings({
        badgeBgRed: 0,
        badgeBgAlpha: 255,
      });

      expect(updated.badgeBgRed).toBe(0);
      expect(updated.badgeBgAlpha).toBe(255);
    });

    it('should accept boundary values for percentages (0 and 1)', async () => {
      const updated = await service.updateSettings({
        badgeHeightPercent: 0,
        badgeBottomMarginPercent: 1,
      });

      expect(updated.badgeHeightPercent).toBe(0);
      expect(updated.badgeBottomMarginPercent).toBe(1);
    });
  });

  describe('resetToDefaults', () => {
    it('should reset all settings to defaults', async () => {
      // First, change some settings
      await service.updateSettings({
        defaultOpacity: 0.5,
        enableWatermarking: false,
      });

      // Then reset
      const reset = await service.resetToDefaults();

      expect(reset.defaultOpacity).toBe(1.0);
      expect(reset.enableWatermarking).toBe(true);
    });
  });

  describe('disableWatermarking', () => {
    it('should set enableWatermarking to false', async () => {
      const updated = await service.disableWatermarking();

      expect(updated.enableWatermarking).toBe(false);
    });
  });

  describe('enableWatermarking', () => {
    it('should set enableWatermarking to true', async () => {
      // First disable
      await service.disableWatermarking();

      // Then enable
      const updated = await service.enableWatermarking();

      expect(updated.enableWatermarking).toBe(true);
    });
  });

  describe('color validation', () => {
    it('should validate all color fields with proper boundaries', async () => {
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
        const updateObj = {};
        updateObj[field] = 256;

        await expect(service.updateSettings(updateObj)).rejects.toThrow(
          BadRequestException,
        );
      }
    });
  });

  describe('percentage validation', () => {
    it('should validate all percentage fields with proper boundaries', async () => {
      const percentFields = [
        'badgeHeightPercent',
        'badgeHorizontalPaddingPercent',
        'badgeBottomMarginPercent',
        'glassMarginPercent',
      ];

      for (const field of percentFields) {
        const updateObj = {};
        updateObj[field] = 1.5;

        await expect(service.updateSettings(updateObj)).rejects.toThrow(
          BadRequestException,
        );
      }
    });
  });
});
