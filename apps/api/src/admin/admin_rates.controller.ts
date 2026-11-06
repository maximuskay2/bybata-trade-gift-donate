import { Body, Controller, Get, Post, Patch, UseGuards, Delete, Param, Req, Query } from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { EmailService } from '../common/email.service';
import { EmailEventName } from '../email/email-events';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';

interface CreateRateDto {
  base?: string;
  quote?: string;
  rate: number;
  active?: boolean;
  validFrom?: string; // ISO 8601 date string
  validTo?: string; // ISO 8601 date string
  changeReason?: string;
}

interface UpdateRateDto {
  rate?: number;
  active?: boolean;
  validFrom?: string;
  validTo?: string;
  changeReason?: string;
}

@Controller('v1/admin/rates')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminRatesController {
  constructor(private prisma: PrismaService, private email: EmailService) {}

  /**
   * List all conversion rates with optional filters
   * Supports filtering by base, quote, active status, and date range
   */
  @Get()
  async list(
    @Query('base') base?: string,
    @Query('quote') quote?: string,
    @Query('active') active?: string,
    @Query('includeHistory') includeHistory?: string,
  ) {
    const where: any = {};
    if (base) where.base = base;
    if (quote) where.quote = quote;
    if (active !== undefined) {
      where.active = active === 'true' || active === '1';
    }

    // If includeHistory is false, only show active rates
    const includeHistoryFlag = includeHistory === 'true' || includeHistory === '1';
    if (!includeHistoryFlag && active === undefined) {
      where.active = true;
    }

    const rates = await this.prisma.conversionRate.findMany({
      where,
      orderBy: { createdAt: 'desc' },
    });

    return rates;
  }

  /**
   * Get rate history for a specific base/quote pair
   */
  @Get('history')
  async getHistory(
    @Query('base') base: string = 'BYC',
    @Query('quote') quote: string,
  ) {
    if (!quote) {
      return { error: 'quote parameter is required' };
    }

    const rates = await this.prisma.conversionRate.findMany({
      where: { base, quote },
      orderBy: { createdAt: 'desc' },
    });

    return rates;
  }

  /**
   * Create a new conversion rate
   * Automatically deactivates old active rates for the same base/quote pair
   * Supports validity windows and audit trail
   */
  @Post()
  async create(@Body() body: CreateRateDto, @Req() req: any) {
    const base = body.base ?? 'BYC';
    const quote = body.quote ?? 'USD';
    const active = body.active ?? true;
    const adminId = (req.user as any)?.sub as string | undefined;

    // Parse validity windows
    const validFrom = body.validFrom ? new Date(body.validFrom) : null;
    const validTo = body.validTo ? new Date(body.validTo) : null;

    // Validate validity window
    if (validFrom && validTo && validFrom >= validTo) {
      return { ok: false, error: 'validFrom must be before validTo' };
    }

    // If setting a new active rate, deactivate all existing active rates for this pair
    const previousActive = active
      ? await this.prisma.conversionRate.findFirst({
          where: { base, quote, active: true },
          orderBy: { createdAt: 'desc' },
        })
      : null;
    if (active) {
      await this.prisma.conversionRate.updateMany({
        where: {
          base,
          quote,
          active: true,
        },
        data: {
          active: false,
        },
      });
    }

    const rate = await this.prisma.conversionRate.create({
      data: {
        base,
        quote,
        rate: Number(body.rate),
        active,
        validFrom,
        validTo,
        createdBy: adminId,
        updatedBy: adminId,
        changeReason: body.changeReason || null,
      } as any,
    });

    if (active) {
      try {
        const [adminUser, users] = await Promise.all([
          adminId
            ? this.prisma.user.findUnique({
                where: { id: adminId },
                select: { email: true, profile: { select: { displayName: true } } },
              })
            : Promise.resolve(null),
          this.prisma.user.findMany({
            where: { email: { not: '' } },
            select: { id: true, email: true, profile: { select: { displayName: true } } },
          }),
        ]);
        const actorName = adminUser?.profile?.displayName || adminUser?.email || 'Admin';
        const effectiveAt = (validFrom instanceof Date ? validFrom : new Date()).toISOString();
        await Promise.all(
          users
            .filter((u) => u.email)
            .map((u) =>
              this.email.dispatch({
                eventName: EmailEventName.WalletRateUpdated,
                recipient: { email: u.email as string, userId: u.id },
                vars: {
                  actorName,
                  oldRate: Number(previousActive?.rate ?? 0),
                  newRate: Number(rate.rate),
                  effectiveAt,
                },
              }),
            ),
        );
      } catch (e) {
        console.warn('Failed to send rate update emails:', e);
      }
    }

    // Create audit trail entry
    if (adminId) {
      try {
        await (this.prisma as any).adminActionAudit.create({
          data: {
            adminId,
            action: 'RATE_CREATE',
            details: {
              rateId: rate.id,
              base,
              quote,
              rate: body.rate,
              active,
              validFrom,
              validTo,
              changeReason: body.changeReason,
            },
          },
        });
      } catch (e) {
        // Audit creation is non-critical, log and continue
        console.warn('Failed to create rate audit entry:', e);
      }
    }

    return rate;
  }

  /**
   * Update an existing conversion rate
   * If activating a rate, deactivates other active rates for the same pair
   */
  @Patch(':id')
  async update(@Param('id') id: string, @Body() body: UpdateRateDto, @Req() req: any) {
    const existing = await this.prisma.conversionRate.findUnique({ where: { id } });
    if (!existing) {
      return { ok: false, error: 'Rate not found' };
    }

    const adminId = (req.user as any)?.sub as string | undefined;
    const updateData: any = {};

    if (body.rate !== undefined) {
      updateData.rate = Number(body.rate);
    }
    if (body.active !== undefined) {
      updateData.active = body.active;
    }
    if (body.validFrom !== undefined) {
      updateData.validFrom = body.validFrom ? new Date(body.validFrom) : null;
    }
    if (body.validTo !== undefined) {
      updateData.validTo = body.validTo ? new Date(body.validTo) : null;
    }
    if (body.changeReason !== undefined) {
      updateData.changeReason = body.changeReason || null;
    }

    updateData.updatedBy = adminId;

    // Validate validity window if both dates are being set
    if (updateData.validFrom && updateData.validTo) {
      const validFrom = updateData.validFrom instanceof Date ? updateData.validFrom : new Date(updateData.validFrom);
      const validTo = updateData.validTo instanceof Date ? updateData.validTo : new Date(updateData.validTo);
      if (validFrom >= validTo) {
        return { ok: false, error: 'validFrom must be before validTo' };
      }
    }

    // If activating this rate, deactivate other active rates for the same base/quote pair
    if (body.active === true) {
      await this.prisma.conversionRate.updateMany({
        where: {
          base: existing.base,
          quote: existing.quote,
          active: true,
          id: { not: id }, // Exclude the current rate
        },
        data: {
          active: false,
        },
      });
    }

    const updated = await this.prisma.conversionRate.update({
      where: { id },
      data: updateData,
    });

    if (body.active === true || (body.rate !== undefined && existing.active)) {
      try {
        const [adminUser, users] = await Promise.all([
          adminId
            ? this.prisma.user.findUnique({
                where: { id: adminId },
                select: { email: true, profile: { select: { displayName: true } } },
              })
            : Promise.resolve(null),
          this.prisma.user.findMany({
            where: { email: { not: '' } },
            select: { id: true, email: true, profile: { select: { displayName: true } } },
          }),
        ]);
        const actorName = adminUser?.profile?.displayName || adminUser?.email || 'Admin';
        const effectiveAt = (updateData.validFrom instanceof Date ? updateData.validFrom : new Date()).toISOString();
        await Promise.all(
          users
            .filter((u) => u.email)
            .map((u) =>
              this.email.dispatch({
                eventName: EmailEventName.WalletRateUpdated,
                recipient: { email: u.email as string, userId: u.id },
                vars: {
                  actorName,
                  oldRate: Number(existing.rate),
                  newRate: Number(updated.rate),
                  effectiveAt,
                },
              }),
            ),
        );
      } catch (e) {
        console.warn('Failed to send rate update emails:', e);
      }
    }

    // Create audit trail entry
    if (adminId) {
      try {
        await (this.prisma as any).adminActionAudit.create({
          data: {
            adminId,
            action: 'RATE_UPDATE',
            details: {
              rateId: id,
              previous: existing,
              changes: updateData,
            },
          },
        });
      } catch (e) {
        console.warn('Failed to create rate update audit entry:', e);
      }
    }

    return updated;
  }

  @Delete(':id')
  async remove(@Param('id') id: string, @Req() req: any) {
    const prev = await this.prisma.conversionRate.findUnique({ where: { id } });
    if (!prev) return { ok: false, error: 'Rate not found' };
    await this.prisma.conversionRate.delete({ where: { id } });
    const admin = (req.user as any)?.sub as string | undefined;
    if (admin) {
      await (this.prisma as any).adminActionAudit.create({ data: { adminId: admin, action: 'RATE_DELETE', details: { prev } } });
    }
    return { ok: true };
  }

  // Fallback for environments where DELETE may be blocked or proxied
  @Post(':id/delete')
  async removeFallback(@Param('id') id: string, @Req() req: any) {
    return this.remove(id, req);
  }
}
