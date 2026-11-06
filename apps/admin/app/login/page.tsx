"use client";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { api, getApiBaseUrl } from "@/lib/api";

function formatLoginError(err: unknown): string {
  const anyErr = err as {
    response?: { data?: { message?: string | string[]; code?: string } };
    message?: string;
    code?: string;
  };
  const data = anyErr?.response?.data;
  const message = data?.message;
  if (Array.isArray(message)) return message.join(", ");
  if (typeof message === "string" && message.length > 0) return message;
  if (data?.code === "EMAIL_VERIFICATION_REQUIRED") {
    return "Email verification required. Verify the account in the app first.";
  }
  if (anyErr?.message === "Network Error") {
    return "Cannot reach the API. Check your connection or API URL.";
  }
  return "Login failed. Check email, password, and that the account has ADMIN role.";
}

export default function AdminLogin() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");
  const [loading, setLoading] = useState(false);
  const baseHint = getApiBaseUrl();

  const onSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError("");
    setStatus("");

    const form = new FormData(e.currentTarget);
    const email = String(form.get("email") || "").trim();
    const password = String(form.get("password") || "");

    if (!email || !password) {
      setError("Enter email and password.");
      return;
    }

    setLoading(true);
    setStatus("Signing in…");

    try {
      const res = await api.post("/v1/auth/login", { email, password });
      const { accessToken, user } = res.data || {};

      if (!accessToken) {
        setError("Login response missing access token.");
        setStatus("");
        return;
      }

      if (user?.role !== "ADMIN") {
        setError(`Admin access required (this account is ${user?.role || "unknown"}).`);
        setStatus("");
        return;
      }

      localStorage.setItem("admin_token", accessToken);
      setStatus("Success — opening dashboard…");
      router.replace("/dashboard");
      router.refresh();
    } catch (err) {
      setError(formatLoginError(err));
      setStatus("");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen flex items-center justify-center bg-gray-50 p-6">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm bg-white rounded-lg border shadow-sm p-6 space-y-4"
        autoComplete="on"
      >
        <div className="text-[11px] rounded border p-2 bg-yellow-50 border-yellow-200 text-yellow-900">
          <div className="font-medium">API Base URL</div>
          <div className="truncate font-mono">{baseHint}</div>
        </div>

        <h1 className="text-lg font-semibold text-gray-900">Admin Login</h1>
        <p className="text-xs text-gray-500">
          Use an account with the ADMIN role. Password manager autofill is supported.
        </p>

        {error ? (
          <div className="rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700" role="alert">
            {error}
          </div>
        ) : null}

        {status ? (
          <div className="rounded border border-indigo-200 bg-indigo-50 px-3 py-2 text-sm text-indigo-800">
            {status}
          </div>
        ) : null}

        <div className="space-y-1">
          <label htmlFor="email" className="text-sm text-gray-600">
            Email
          </label>
          <input
            id="email"
            name="email"
            type="email"
            autoComplete="username"
            required
            disabled={loading}
            className="w-full border rounded px-3 py-2 text-sm disabled:opacity-60"
          />
        </div>

        <div className="space-y-1">
          <label htmlFor="password" className="text-sm text-gray-600">
            Password
          </label>
          <input
            id="password"
            name="password"
            type="password"
            autoComplete="current-password"
            required
            disabled={loading}
            className="w-full border rounded px-3 py-2 text-sm disabled:opacity-60"
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-indigo-600 hover:bg-indigo-700 text-white rounded py-2.5 text-sm font-medium disabled:opacity-50"
        >
          {loading ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}
