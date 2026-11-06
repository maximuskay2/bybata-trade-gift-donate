import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { AdminGuard } from './admin.guard';
import { AdminNegotiationsService } from './admin_negotiations.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin/negotiations')
export class AdminNegotiationsController {
  constructor(private adminNegotiationsService: AdminNegotiationsService) {}

  @Get()
  async listNegotiations() {
    return this.adminNegotiationsService.listNegotiations();
  }

  @Get('stats')
  async getNegotiationStats() {
    return this.adminNegotiationsService.getNegotiationStats();
  }

  @Get(':id/messages')
  async getNegotiationMessages(@Param('id') negotiationId: string) {
    return this.adminNegotiationsService.getNegotiationMessages(negotiationId);
  }

  @Get('disputes')
  async getActiveDisputes() {
    return this.adminNegotiationsService.getActiveDisputes();
  }

  @Get('recent')
  async getRecentActivity() {
    return this.adminNegotiationsService.getRecentActivity();
  }
}