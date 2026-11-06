import {
  Controller,
  Post,
  Param,
  Body,
  UseGuards,
  Request,
  HttpCode,
  HttpStatus,
  ForbiddenException,
} from '@nestjs/common';
import { InteractionsService } from './interactions.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import {
  SourceType,
  ExpressInterestDto,
  CompleteInteractionDto,
} from './dto/interaction.dto';
import { FeatureFlags } from '../config/feature-flags';

@Controller('v1/interactions')
@UseGuards(JwtAuthGuard)
export class InteractionsController {
  constructor(private readonly interactionsService: InteractionsService) {}

  @Post(':sourceType/:itemId/interested')
  @HttpCode(HttpStatus.OK)
  async expressInterest(
    @Param('sourceType') sourceType: SourceType,
    @Param('itemId') itemId: string,
    @Request() req: any,
    @Body() dto: ExpressInterestDto,
  ) {
    if (!FeatureFlags.isEnabled('ENABLE_INTERACTION_ENDPOINTS')) {
      throw new ForbiddenException('Interaction endpoints are not enabled');
    }
    return this.interactionsService.expressInterest(
      sourceType,
      itemId,
      req.user.sub,
      dto,
    );
  }

  @Post(':sourceType/:itemId/complete')
  @HttpCode(HttpStatus.OK)
  async completeInteraction(
    @Param('sourceType') sourceType: SourceType,
    @Param('itemId') itemId: string,
    @Request() req: any,
    @Body() dto: CompleteInteractionDto,
  ) {
    if (!FeatureFlags.isEnabled('ENABLE_INTERACTION_ENDPOINTS')) {
      throw new ForbiddenException('Interaction endpoints are not enabled');
    }
    return this.interactionsService.completeInteraction(
      sourceType,
      itemId,
      req.user.sub,
      dto,
    );
  }
}
