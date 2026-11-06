import axios from "axios";

const apiBaseUrl =
  process.env.NEXT_PUBLIC_API_URL ||
  (process.env.NODE_ENV === "production"
    ? "https://bybataapi-production.up.railway.app"
    : "http://localhost:3000");

export const api = axios.create({
  baseURL: apiBaseUrl,
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 30000,
});

export function getApiBaseUrl() {
  return apiBaseUrl;
}

const appBaseUrl =
  process.env.NEXT_PUBLIC_APP_URL ||
  process.env.NEXT_PUBLIC_ADMIN_URL ||
  "http://localhost:3001";

const paymentStatusPath =
  process.env.NEXT_PUBLIC_PAYMENT_STATUS_PATH || "/status";

export function buildWalletFundingReturnUrl() {
  return `${appBaseUrl}${paymentStatusPath}`;
}

export async function createPaystackFundingSession(amountNgn: number) {
  const returnUrl = buildWalletFundingReturnUrl();
  const res = await api.post("/v1/wallet/fund/paystack/create", {
    amountNgn,
    returnUrl,
  });
  return res.data;
}

api.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = localStorage.getItem("admin_token");
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    const status = err?.response?.status;
    const path =
      typeof window !== "undefined" ? window.location.pathname : "";
    const requestUrl = String(err?.config?.url || "");

    // Never redirect away from the login page while the user is signing in.
    if (
      status === 401 &&
      typeof window !== "undefined" &&
      !path.startsWith("/login") &&
      !requestUrl.includes("/v1/auth/login")
    ) {
      localStorage.removeItem("admin_token");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);
