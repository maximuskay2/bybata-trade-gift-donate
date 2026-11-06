import { Controller, Get, Post, Body, UseGuards, Param } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { UsersService } from './users.service';

@Controller('v1/users')
export class VerificationController {
  constructor(private users: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me/verification/status')
  async getVerificationStatus(@CurrentUser() user: any) {
    return this.users.getVerificationStateForUser(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/verification/documents')
  async registerVerificationDocument(
    @CurrentUser() user: any,
    @Body() body: { type: string; documentKey: string; fileName?: string },
  ) {
    const doc = await this.users.registerVerificationDocument(
      user.sub,
      body.type,
      body.documentKey,
      body.fileName,
    );
    return {
      ok: true,
      document: doc,
      verification: await this.users.getVerificationStateForUser(user.sub),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/verification')
  async submitVerification(
    @CurrentUser() user: any,
    @Body() body: { documents: Record<string, string> },
  ) {
    return this.users.submitVerification(user.sub, body.documents);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/verification/documents')
  async getVerificationDocuments(@CurrentUser() user: any) {
    return this.users.getVerificationDocuments(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me/verification/documents/:id')
  async getVerificationDocument(@CurrentUser() user: any, @Param('id') id: string) {
    return this.users.getVerificationDocument(user.sub, id);
  }
}