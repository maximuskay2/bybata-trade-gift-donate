import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { PaymentsService } from './payments.service';

@Controller('v1/payments')
@UseGuards(JwtAuthGuard)
export class PaymentsController {
  constructor(private payments: PaymentsService) {}

  // Phase 1 scaffold endpoint to list configured providers
  @Get('providers')
  async providers() {
    return { providers: this.payments.listProviders() };
  }
}