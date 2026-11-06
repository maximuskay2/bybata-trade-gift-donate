import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
const request = require('supertest');
import { AppModule } from '../src/app.module';

describe('Profile (e2e)', () => {
  let app: INestApplication;
  let server: any;
  let access: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleFixture.createNestApplication();
    await app.init();
    server = app.getHttpServer();

    const email = `e2e.profile.${Date.now()}@local.test`;
    const password = 'Test12345';
    const reg = await request(server).post('/v1/auth/register').send({ email, password, displayName: 'E2E Profile' });
    access = reg.body.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /v1/users/me returns current user', async () => {
    const res = await request(server).get('/v1/users/me').set('Authorization', `Bearer ${access}`).expect(200);
    expect(res.body).toHaveProperty('email');
    expect(res.body).toHaveProperty('profile');
  });

  it('PATCH /v1/users/me updates profile fields', async () => {
    const res = await request(server)
      .patch('/v1/users/me')
      .set('Authorization', `Bearer ${access}`)
      .send({ displayName: 'Updated E2E', bio: 'hello', phone: '123456' })
      .expect(200);
    expect(res.body.profile.displayName).toBe('Updated E2E');
    expect(res.body.profile.bio).toBe('hello');
    expect(res.body.profile.phone).toBe('123456');
  });
});