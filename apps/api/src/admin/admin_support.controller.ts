import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import {
  SupportChatSessionStatus,
  SupportTicketStatus,
  SupportTicketType,
} from '@prisma/client';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { SupportService } from '../support/support.service';

@Controller('v1/admin/support')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminSupportController {
  constructor(private support: SupportService) {}

  @Get('tickets')
  listTickets(
    @Query('status') status?: SupportTicketStatus,
    @Query('type') type?: SupportTicketType,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    return this.support.adminListTickets({
      status,
      type,
      page: parseInt(pageStr ?? '1', 10) || 1,
      size: parseInt(sizeStr ?? '20', 10) || 20,
    });
  }

  @Get('tickets/:id')
  getTicket(@Param('id') id: string) {
    return this.support.adminGetTicket(id);
  }

  @Patch('tickets/:id')
  updateTicket(
    @Req() req: any,
    @Param('id') id: string,
    @Body()
    body: {
      status?: SupportTicketStatus;
      priority?: string;
      assignedAdminId?: string | null;
      reply?: string;
    },
  ) {
    return this.support.adminUpdateTicket(req.user.sub, id, body as any);
  }

  @Get('bug-reports')
  listBugReports(
    @Query('status') status?: SupportTicketStatus,
    @Query('page') pageStr?: string,
    @Query('size') sizeStr?: string,
  ) {
    return this.support.adminListTickets({
      status,
      type: SupportTicketType.BUG_REPORT,
      page: parseInt(pageStr ?? '1', 10) || 1,
      size: parseInt(sizeStr ?? '20', 10) || 20,
    });
  }

  @Get('chat/sessions')
  listChatSessions(@Query('status') status?: SupportChatSessionStatus) {
    return this.support.adminListChatSessions(status);
  }

  @Get('chat/sessions/:id')
  getChatSession(@Param('id') id: string) {
    return this.support.adminGetChatSession(id);
  }

  @Post('chat/sessions/:id/claim')
  claimChat(@Req() req: any, @Param('id') id: string) {
    return this.support.adminClaimChat(req.user.sub, id);
  }

  @Post('chat/sessions/:id/messages')
  sendChatMessage(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    return this.support.adminSendChatMessage(req.user.sub, id, body.content);
  }

  @Post('chat/sessions/:id/close')
  closeChat(@Param('id') id: string) {
    return this.support.adminCloseChat(id);
  }
}
