import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
const request = require('supertest');
import { AppModule } from '../src/app.module';

const HAS_STORAGE = !!process.env.STORAGE_ENDPOINT && !!process.env.STORAGE_BUCKET;

describe('Storage (e2e)', () => {
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

    const email = `e2e.storage.${Date.now()}@local.test`;
    const password = 'Test12345';
    const reg = await request(server).post('/v1/auth/register').send({ email, password, displayName: 'E2E Storage' });
    access = reg.body.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  (HAS_STORAGE ? it : it.skip)('POST /v1/storage/upload-url returns signed URL', async () => {
    const res = await request(server)
      .post('/v1/storage/upload-url')
      .set('Authorization', `Bearer ${access}`)
      .send({ domain: 'profiles', contentType: 'image/jpeg', ext: 'jpg' })
      .expect(201).catch(async (e) => {
        // Accept 200 or 201
        const r = await request(server)
          .post('/v1/storage/upload-url')
          .set('Authorization', `Bearer ${access}`)
          .send({ domain: 'profiles', contentType: 'image/jpeg', ext: 'jpg' });
        expect([200,201]).toContain(r.status);
        return r;
      });
    expect(res.body).toHaveProperty('key');
    expect(res.body).toHaveProperty('uploadUrl');
  });
});