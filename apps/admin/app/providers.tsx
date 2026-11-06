"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { ToastProvider } from "@/app/components/ui/toast";
import { ErrorBoundary } from "@/app/components/error-boundary";

export function Providers({ children }: { children: ReactNode }) {
  const [client] = useState(() => new QueryClient());
  return (
    <ErrorBoundary
      onError={(error, errorInfo) => {
        // Log error for tracking
        console.error('Application error:', error, errorInfo);
        // TODO: Send to error tracking service (Sentry, etc.)
      }}
    >
      <QueryClientProvider client={client}>
        <ToastProvider>{children}</ToastProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
}
