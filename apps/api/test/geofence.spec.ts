import { haversineMeters } from '../src/communities/communities.service';

describe('Geofencing Haversine', () => {
  it('distance between same point is ~0', () => {
    const d = haversineMeters(6.5244, 3.3792, 6.5244, 3.3792);
    expect(d).toBeLessThan(1);
  });

  it('distance between nearby points is within expected range', () => {
    const d = haversineMeters(6.5244, 3.3792, 6.5715, 3.3515); // Lagos area ~5km
    expect(d).toBeGreaterThan(1000);
    expect(d).toBeLessThan(10000);
  });
});
