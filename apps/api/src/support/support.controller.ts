import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { SupportTicketType } from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { SupportService } from './support.service';

@UseGuards(JwtAuthGuard)
@Controller('v1/support')
export class SupportController {
  constructor(private support: SupportService) {}

  @Get('faqs')
  listFaqs() {
    return this.support.listFaqs();
  }

  @Get('tickets')
  listTickets(@CurrentUser() user: any, @Query('type') type?: SupportTicketType) {
    return this.support.listTickets(user.sub, type);
  }

  @Get('tickets/:id')
  getTicket(@CurrentUser() user: any, @Param('id') id: string) {
    return this.support.getTicket(user.sub, id);
  }

  @Post('tickets')
  createTicket(
    @CurrentUser() user: any,
    @Body()
    body: {
      subject: string;
      description: string;
      category: string;
      type?: SupportTicketType;
      priority?: string;
      metadata?: Record<string, unknown>;
    },
  ) {
    return this.support.createTicket(user.sub, body as any);
  }

  @Post('tickets/:id/messages')
  addTicketMessage(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.support.addTicketMessage(user.sub, id, body.content);
  }

  @Post('bug-reports')
  createBugReport(
    @CurrentUser() user: any,
    @Body()
    body: {
      subject: string;
      description: string;
      category?: string;
      metadata?: Record<string, unknown>;
    },
  ) {
    return this.support.createTicket(user.sub, {
      subject: body.subject,
      description: body.description,
      category: body.category ?? 'Technical',
      type: SupportTicketType.BUG_REPORT,
      metadata: body.metadata,
    });
  }

  @Get('chat/session')
  getChatSession(@CurrentUser() user: any) {
    return this.support.getOrCreateChatSession(user.sub);
  }

  @Post('chat/messages')
  sendChatMessage(@CurrentUser() user: any, @Body() body: { content: string }) {
    return this.support.sendChatMessage(user.sub, body.content);
  }

  @Post('chat/request-admin')
  requestAdmin(@CurrentUser() user: any) {
    return this.support.requestAdminChat(user.sub);
  }
}
