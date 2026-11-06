import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { TradesService } from './trades.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { MessageType } from '@prisma/client';

@UseGuards(JwtAuthGuard)
@Controller('v1/offers')
export class OffersController {
  constructor(private trades: TradesService) {}

  @Post(':id/accept')
  async accept(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.acceptOffer(user.sub, id);
  }

  @Post(':id/reject')
  async reject(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.rejectOffer(user.sub, id);
  }

  @Post(':id/withdraw')
  async withdraw(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.withdrawOffer(user.sub, id);
  }

  @Get(':id/negotiation/messages')
  async listMessages(@CurrentUser() user: any, @Param('id') id: string) {
    return this.trades.listMessages(user.sub, id);
  }

  @Post(':id/negotiation/messages')
  async postMessage(
    @CurrentUser() user: any, 
    @Param('id') id: string, 
    @Body() body: { 
      content: string; 
      messageType?: MessageType; 
      proposalData?: any;
    }
  ) {
    return this.trades.postMessage(
      user.sub, 
      id, 
      body.content, 
      body.messageType || MessageType.REGULAR,
      body.proposalData
    );
  }
}
