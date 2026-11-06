import { Global, Module } from '@nestjs/common';
import { ScaleCacheService } from './scale-cache.service';

@Global()
@Module({
  providers: [ScaleCacheService],
  exports: [ScaleCacheService],
})
export class ScaleCacheModule {}
