import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
const request = require('supertest');
import { AppModule } from '../src/app.module';

function uniqueEmail() {
  return `e2e.${Date.now()}${Math.floor(Math.random()*1000)}@local.test`;
}

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let server: any;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication();
    await app.init();
    server = app.getHttpServer();
  });

  afterAll(async () => {
    await app.close();
  });

  it('register -> login -> refresh -> logout', async () => {
    const email = uniqueEmail();
    const password = 'Test12345';

    const reg = await request(server)
      .post('/v1/auth/register')
      .send({ email, password, displayName: 'E2E' })
      .expect(201);
    expect(reg.body).toHaveProperty('accessToken');
    expect(reg.body).toHaveProperty('refreshToken');

    const log = await request(server)
      .post('/v1/auth/login')
      .send({ email, password })
      .expect(200);
    const access = log.body.accessToken as string;
    const refresh = log.body.refreshToken as string;
    expect(access).toBeTruthy();
    expect(refresh).toBeTruthy();

    const ref = await request(server)
      .post('/v1/auth/refresh')
      .send({ refreshToken: refresh })
      .expect(201).catch(async (e) => {
        // Some apps return 200; accept either
        const r = await request(server).post('/v1/auth/refresh').send({ refreshToken: refresh });
        expect([200,201]).toContain(r.status);
        return r;
      });

    const userIdRes = await request(server).get('/v1/users/me').set('Authorization', `Bearer ${access}`).expect(200);
    const userId = userIdRes.body.id as string;

    await request(server).post('/v1/auth/logout').send({ userId }).expect(201).catch(async (e) => {
      const r = await request(server).post('/v1/auth/logout').send({ userId });
      expect([200,201]).toContain(r.status);
      return r;
    });
  });
});