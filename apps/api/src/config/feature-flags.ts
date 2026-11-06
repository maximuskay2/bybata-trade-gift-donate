/**
 * Feature Flags Configuration
 * 
 * Controls gradual rollout of new features.
 * Default to false in production, true in development/staging.
 */

export interface FeatureFlagsConfig {
  ENABLE_UNIFIED_FEED: boolean;
  ENABLE_OFFER_ASK_FLOW: boolean;
  ENABLE_INTERACTION_ENDPOINTS: boolean;
}

export class FeatureFlags {
  private static instance: FeatureFlagsConfig;

  static get(): FeatureFlagsConfig {
    if (!this.instance) {
      this.instance = {
        ENABLE_UNIFIED_FEED: this.parseBoolean(
          process.env.ENABLE_UNIFIED_FEED,
          process.env.NODE_ENV !== 'production'
        ),
        ENABLE_OFFER_ASK_FLOW: this.parseBoolean(
          process.env.ENABLE_OFFER_ASK_FLOW,
          process.env.NODE_ENV !== 'production'
        ),
        // Interaction endpoints (express interest / complete) are a shipped,
        // stable feature. Default to enabled in all environments; the env var
        // can still explicitly disable them by setting it to "false".
        ENABLE_INTERACTION_ENDPOINTS: this.parseBoolean(
          process.env.ENABLE_INTERACTION_ENDPOINTS,
          true
        ),
      };
    }
    return this.instance;
  }

  private static parseBoolean(value: string | undefined, defaultValue: boolean): boolean {
    if (value === undefined) return defaultValue;
    return value.toLowerCase() === 'true';
  }

  static isEnabled(flag: keyof FeatureFlagsConfig): boolean {
    return this.get()[flag];
  }
}
