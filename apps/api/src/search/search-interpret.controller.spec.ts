import { ArgumentMetadata, ValidationPipe } from '@nestjs/common';
import {
  IntentSearchDto,
  InterpretSearchDto,
} from './search-interpret.controller';

const pipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: { enableImplicitConversion: true },
});

function body(metatype: ArgumentMetadata['metatype']): ArgumentMetadata {
  return { type: 'body', metatype, data: '' };
}

describe('search intent DTOs under the global ValidationPipe', () => {
  it('accepts the body the app sends to /v1/search/intent', async () => {
    const value: unknown = await pipe.transform(
      {
        query: 'i need a macbook',
        locale: 'en-NG',
        lat: 5.03,
        lng: 7.92,
        radiusKm: 50,
        location: 'Uyo',
        categories: ['ELECTRONICS'],
        skipAi: true,
        widenRadius: true,
      },
      body(IntentSearchDto),
    );
    expect(value).toMatchObject({
      query: 'i need a macbook',
      radiusKm: 50,
      skipAi: true,
    });
  });

  it('accepts the body the app sends to /v1/search/interpret', async () => {
    await expect(
      pipe.transform({ q: 'i need a macbook' }, body(InterpretSearchDto)),
    ).resolves.toMatchObject({
      q: 'i need a macbook',
    });
  });

  it('still rejects unknown fields', async () => {
    await expect(
      pipe.transform({ query: 'chair', admin: true }, body(IntentSearchDto)),
    ).rejects.toBeDefined();
  });
});
