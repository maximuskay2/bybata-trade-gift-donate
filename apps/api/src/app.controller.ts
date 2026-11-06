import { Controller, Get, HttpStatus, HttpException } from '@nestjs/common';
import { AppService } from './app.service';
import { PrismaService } from './common/prisma.service';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  /**
   * Health check endpoint for load balancers and monitoring
   * Returns 200 if healthy, 503 if unhealthy
   * 
   * Checks:
   * - Database connectivity
   * - Basic system status
   * 
   * Usage:
   * - Load balancers: Use this endpoint for health checks
   * - Monitoring: Poll this endpoint for system status
   */
  @Get('health')
  async health() {
    const startTime = Date.now();
    const healthStatus: any = {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      scale: {
        prismaConnectionLimit:
          process.env.PRISMA_CONNECTION_LIMIT || '5',
        poolerConfigured: !!(
          process.env.DATABASE_POOL_URL ||
          process.env.PRISMA_PGBOUNCER === 'true'
        ),
        redisConfigured: !!(
          process.env.REDIS_URL || process.env.REDIS_SOCKET_IO_URL
        ),
      },
      checks: {
        database: 'unknown',
        redis: 'unknown',
      },
    };

    try {
      // Check database connectivity
      await this.prisma.$queryRaw`SELECT 1`;
      healthStatus.checks.database = 'healthy';
    } catch (error) {
      healthStatus.checks.database = 'unhealthy';
      healthStatus.status = 'error';
      const responseTime = Date.now() - startTime;
      
      throw new HttpException(
        {
          ...healthStatus,
          error: 'Database connection failed',
          responseTime: `${responseTime}ms`,
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    const redisUrl = process.env.REDIS_URL || process.env.REDIS_SOCKET_IO_URL;
    healthStatus.checks.redis = redisUrl ? 'configured' : 'not_configured';
    if (process.env.NODE_ENV === 'production' && !redisUrl) {
      healthStatus.status = 'degraded';
    }

    const responseTime = Date.now() - startTime;
    return {
      ...healthStatus,
      responseTime: `${responseTime}ms`,
    };
  }

  /**
   * Liveness probe - simple check if service is running
   * Always returns 200 if service is up
   */
  @Get('health/live')
  liveness() {
    return {
      status: 'alive',
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Readiness probe - checks if service is ready to accept traffic
   * Returns 200 if ready, 503 if not ready
   */
  @Get('health/ready')
  async readiness() {
    try {
      // Check database connectivity
      await this.prisma.$queryRaw`SELECT 1`;
      return {
        status: 'ready',
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      throw new HttpException(
        {
          status: 'not ready',
          timestamp: new Date().toISOString(),
          error: 'Database not available',
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }

  /**
   * Basic monitoring endpoint - provides system metrics and status
   * Returns system information, metrics, and health status
   * 
   * Usage:
   * - Monitoring dashboards: Poll this endpoint for metrics
   * - System administrators: Check system status and performance
   */
  @Get('monitoring')
  async monitoring() {
    const startTime = Date.now();
    
    // Get basic system metrics
    const memUsage = process.memoryUsage();
    const uptime = process.uptime();
    
    // Check database connectivity
    let dbStatus = 'unknown';
    let dbResponseTime = 0;
    try {
      const dbStart = Date.now();
      await this.prisma.$queryRaw`SELECT 1`;
      dbResponseTime = Date.now() - dbStart;
      dbStatus = 'healthy';
    } catch (error) {
      dbStatus = 'unhealthy';
    }

    // Calculate response time
    const responseTime = Date.now() - startTime;

    return {
      status: dbStatus === 'healthy' ? 'ok' : 'degraded',
      timestamp: new Date().toISOString(),
      uptime: {
        seconds: Math.floor(uptime),
        formatted: this.formatUptime(uptime),
      },
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      memory: {
        rss: `${Math.round(memUsage.rss / 1024 / 1024)}MB`,
        heapTotal: `${Math.round(memUsage.heapTotal / 1024 / 1024)}MB`,
        heapUsed: `${Math.round(memUsage.heapUsed / 1024 / 1024)}MB`,
        external: `${Math.round(memUsage.external / 1024 / 1024)}MB`,
      },
      checks: {
        database: {
          status: dbStatus,
          responseTime: `${dbResponseTime}ms`,
        },
      },
      responseTime: `${responseTime}ms`,
    };
  }

  /**
   * Format uptime in human-readable format
   */
  private formatUptime(seconds: number): string {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);

    if (days > 0) {
      return `${days}d ${hours}h ${minutes}m ${secs}s`;
    } else if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${secs}s`;
    } else {
      return `${secs}s`;
    }
  }
}
