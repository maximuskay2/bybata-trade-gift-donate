import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { SearchService } from './search.service';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { CurrentUser } from '../auth/current-user.decorator';

@Controller('v1/search')
@UseGuards(JwtAuthGuard)
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  async search(
    @CurrentUser() user: { sub?: string },
    @Query('q') query: string,
    @Query('type') type?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);

    return this.searchService.search(
      query.trim(),
      type,
      pageNum,
      pageSize,
      user?.sub,
    );
  }

  @Get('trades')
  async searchTrades(
    @CurrentUser() user: { sub?: string },
    @Query('q') query: string,
    @Query('status') status?: string,
    @Query('category') category?: string,
    @Query('location') location?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');

    const filters = {
      status,
      category,
      location,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
    };

    return this.searchService.searchTrades(
      query.trim(),
      filters,
      pageNum,
      pageSize,
      user?.sub,
    );
  }

  @Get('users')
  async searchUsers(
    @Query('q') query: string,
    @Query('verified') verified?: string,
    @Query('location') location?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);

    const filters = {
      verified: verified === 'true',
      location,
    };

    return this.searchService.searchUsers(query.trim(), filters, pageNum, pageSize);
  }

  @Get('communities')
  async searchCommunities(
    @Query('q') query: string,
    @Query('type') type?: string,
    @Query('category') category?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);

    const filters = {
      type,
      category,
    };

    return this.searchService.searchCommunities(query.trim(), filters, pageNum, pageSize);
  }

  @Get('gifts')
  async searchGifts(
    @CurrentUser() user: { sub?: string },
    @Query('q') query: string,
    @Query('type') type?: string,
    @Query('category') category?: string,
    @Query('location') location?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');

    const filters = {
      type,
      category,
      location,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
    };

    return this.searchService.searchGifts(
      query.trim(),
      filters,
      pageNum,
      pageSize,
      user?.sub,
    );
  }

  @Get('campaigns')
  async searchCampaigns(
    @CurrentUser() user: { sub?: string },
    @Query('q') query: string,
    @Query('status') status?: string,
    @Query('category') category?: string,
    @Query('urgent') urgent?: string,
    @Query('location') location?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('lon') lon?: string,
    @Query('radiusKm') radiusKm?: string,
    @Query('page') page: string = '1',
    @Query('size') size: string = '20',
  ) {
    if (!query || query.trim().length < 2) {
      return {
        items: [],
        total: 0,
        page: parseInt(page) || 1,
        size: parseInt(size) || 20,
        totalPages: 0,
      };
    }

    const pageNum = parseInt(page) || 1;
    const pageSize = Math.min(parseInt(size) || 20, 50);
    const parsedLat = parseFloat(lat ?? '');
    const parsedLng = parseFloat(lng ?? lon ?? '');
    const parsedRadius = parseFloat(radiusKm ?? '50');

    const filters = {
      status,
      category,
      urgent: urgent === 'true',
      location,
      lat: Number.isFinite(parsedLat) ? parsedLat : undefined,
      lng: Number.isFinite(parsedLng) ? parsedLng : undefined,
      radiusKm: Number.isFinite(parsedRadius) ? parsedRadius : undefined,
    };

    return this.searchService.searchCampaigns(
      query.trim(),
      filters,
      pageNum,
      pageSize,
      user?.sub,
    );
  }

  @Get('suggestions')
  async getSearchSuggestions(
    @Query('q') query: string,
    @Query('type') type?: string,
  ) {
    if (!query || query.trim().length < 2) {
      return { suggestions: [] };
    }

    return this.searchService.getSearchSuggestions(query.trim(), type);
  }
}
