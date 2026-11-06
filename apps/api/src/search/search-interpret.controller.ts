import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import {
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
} from 'class-validator';
import { OptionalJwtAuthGuard } from '../auth/optional-jwt.guard';
import { emptyInterpret } from './intent-rules';
import { SearchIntentService } from './search-intent.service';
import { SearchInterpretService } from './search-interpret.service';

/** The global ValidationPipe forbids undecorated properties, so every field needs a decorator. */
export class InterpretSearchDto {
  @IsOptional() @IsString() q?: string;
  @IsOptional() @IsString() query?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
  @IsOptional() @IsString() locale?: string;
}

export class IntentSearchDto {
  @IsOptional() @IsString() query?: string;
  @IsOptional() @IsString() q?: string;
  @IsOptional() @IsNumber() lat?: number;
  @IsOptional() @IsNumber() lng?: number;
  @IsOptional() @IsNumber() radiusKm?: number;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) categories?: string[];
  @IsOptional() @IsBoolean() skipAi?: boolean;
  @IsOptional() @IsString() locale?: string;
  @IsOptional() @IsBoolean() widenRadius?: boolean;
}

@Controller('v1/search')
export class SearchInterpretController {
  constructor(
    private readonly interpretService: SearchInterpretService,
    private readonly intentService: SearchIntentService,
  ) {}

  @Post('interpret')
  @UseGuards(OptionalJwtAuthGuard)
  interpret(
    @Body() body: InterpretSearchDto,
    @Req() req: { user?: { sub?: string; role?: string } },
  ) {
    const q = (body?.q ?? body?.query ?? '').trim();
    if (q.length < 2) return emptyInterpret(q);
    return this.interpretService.interpret(q, {
      userId: req.user?.sub,
      role: req.user?.role,
      lat: numberOrUndefined(body?.lat),
      lng: numberOrUndefined(body?.lng),
      locale: body?.locale,
    });
  }

  @Post('intent/event')
  @UseGuards(OptionalJwtAuthGuard)
  intentEvent(
    @Body()
    body: {
      event?: string;
      cohort?: string;
      module?: string;
      size?: string;
      reason?: string;
      kind?: string;
      latencyMs?: number;
      cached?: boolean;
    },
    @Req() req: { user?: { sub?: string } },
  ) {
    return this.interpretService.recordEvent(body ?? {}, req.user?.sub);
  }

  @Post('intent')
  @UseGuards(OptionalJwtAuthGuard)
  intent(
    @Body() body: IntentSearchDto,
    @Req() req: { user?: { sub?: string; role?: string } },
  ) {
    const query = (body?.query ?? body?.q ?? '').trim();
    if (query.length < 2) {
      return {
        interpret: emptyInterpret(query),
        results: { gift: [], trade: [], campaign: [] },
        layout: emptyInterpret(query).layout,
        radiusKm: 50,
        liquidityExhausted: true,
      };
    }
    return this.intentService.searchByIntent({
      query,
      lat: numberOrUndefined(body?.lat),
      lng: numberOrUndefined(body?.lng),
      radiusKm: numberOrUndefined(body?.radiusKm),
      location: cleanLocation(body?.location),
      categories: Array.isArray(body?.categories) ? body.categories : undefined,
      skipAi: body?.skipAi === true,
      locale: body?.locale,
      userId: req.user?.sub,
      role: req.user?.role,
      widenRadius: body?.widenRadius === true,
    });
  }
}

function numberOrUndefined(value: unknown): number | undefined {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function cleanLocation(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const trimmed = value
    .replace(/[\u0000-\u001F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (trimmed.length < 2) return undefined;
  return trimmed.slice(0, 80);
}
