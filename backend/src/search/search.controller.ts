import { Controller, Get, Query } from '@nestjs/common';
import { SearchService } from './search.service';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get('all')
  searchAll(
    @Query('userId') userId: string,
    @Query('q') q: string,
    @Query('type') type: string,
  ) {
    return this.searchService.searchAll(
      Number(userId),
      q || '',
      type || 'all',
    );
  }
}
