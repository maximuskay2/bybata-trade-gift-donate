import { haversineMeters } from '../common/listing-location.util';
import { IntentCohort } from './intent-rules';

/** City gates are config, not something the model invents. */
export const ROLLOUT_CITIES: Record<string, { lat: number; lng: number; radiusKm: number }> = {
  uyo: { lat: 5.0378, lng: 7.9128, radiusKm: 25 },
};

export function parseRolloutPercent(raw: string | null | undefined): number {
  if (raw == null || raw.trim() === '') return 100;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return 100;
  return Math.min(100, Math.max(0, Math.round(parsed)));
}

/** Empty or unknown names mean "every city". Only configured cities narrow the gate. */
export function rolloutCity(raw: string | null | undefined): string | null {
  const name = raw?.trim().toLowerCase() ?? '';
  if (!name || !ROLLOUT_CITIES[name]) return null;
  return name;
}

function cityRadiusKm(name: string): number {
  const box = ROLLOUT_CITIES[name];
  const override = Number(process.env.AI_INTENT_ROLLOUT_CITY_RADIUS_KM);
  if (Number.isFinite(override) && override >= 1) return Math.min(500, override);
  return box.radiusKm;
}

function bucket(userId: string): number {
  let hash = 0;
  for (let i = 0; i < userId.length; i += 1) {
    hash = (hash * 33 + userId.charCodeAt(i)) >>> 0;
  }
  return hash % 100;
}

/**
 * Kill switch is checked by the caller. This only splits users who are allowed
 * to reach the model. Staff stay in the AI arm at any percent. Guests stay on
 * rules until the percent is 100. Default percent is 100, so an enabled flag
 * still reaches everyone until an operator lowers it.
 */
export function decideIntentCohort(input: {
  percent: number;
  city: string | null;
  userId?: string;
  role?: string;
  lat?: number;
  lng?: number;
}): IntentCohort {
  const role = (input.role || '').toUpperCase();
  if (role === 'ADMIN' || role === 'MODERATOR') return 'ai';

  const percent = parseRolloutPercent(String(input.percent));
  const city = input.city;
  if (city) {
    const box = ROLLOUT_CITIES[city];
    if (input.lat == null || input.lng == null) return 'rules';
    const meters = haversineMeters(box.lat, box.lng, input.lat, input.lng);
    if (meters > cityRadiusKm(city) * 1000) return 'rules';
  }

  if (percent >= 100) return 'ai';
  if (percent <= 0 || !input.userId) return 'rules';
  return bucket(input.userId) < percent ? 'ai' : 'rules';
}
