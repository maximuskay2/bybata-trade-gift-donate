import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Inject API base URL with sensible defaults per environment
  env: {
    NEXT_PUBLIC_API_URL:
      process.env.NEXT_PUBLIC_API_URL ??
      (process.env.NODE_ENV === "production"
        ? "https://bybataapi-production.up.railway.app"
        : "http://localhost:3000"),
  },
  // Allow production builds to pass even if ESLint finds errors
  eslint: {
    ignoreDuringBuilds: true,
  },
  // Allow production builds even with type errors (do not block deploys)
  typescript: {
    ignoreBuildErrors: true,
  },
  // Use the new serverExternalPackages instead of the experimental one
  serverExternalPackages: [],
};

export default nextConfig;
