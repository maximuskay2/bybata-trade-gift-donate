"use client";
import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

export type ToastOptions = {
  title: string;
  description?: string;
  variant?: "default" | "success" | "error";
  durationMs?: number;
};

type ToastItem = ToastOptions & { id: string };

type ToastCtx = {
  push: (opts: ToastOptions) => void;
};

const Ctx = createContext<ToastCtx | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);

  const push = useCallback((opts: ToastOptions) => {
    const id = Math.random().toString(36).slice(2);
    const item: ToastItem = { id, durationMs: 3000, variant: "default", ...opts };
    setItems((arr) => [...arr, item]);
    const ms = item.durationMs ?? 3000;
    window.setTimeout(() => {
      setItems((arr) => arr.filter((i) => i.id !== id));
    }, ms);
  }, []);

  const value = useMemo(() => ({ push }), [push]);

  return (
    <Ctx.Provider value={value}>
      {children}
      <ToastContainer items={items} onClose={(id) => setItems((arr) => arr.filter((i) => i.id !== id))} />
    </Ctx.Provider>
  );
}

export function useToast() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useToast must be used within ToastProvider");
  return ctx;
}

export function ToastContainer({ items, onClose }: { items: ToastItem[]; onClose: (id: string) => void }) {
  return (
    <div className="fixed bottom-4 right-4 z-50 space-y-2">
      {items.map((t) => (
        <div
          key={t.id}
          className={
            "min-w-[260px] max-w-sm bg-white rounded border shadow-sm px-3 py-2 text-sm " +
            (t.variant === "success"
              ? "border-emerald-200"
              : t.variant === "error"
              ? "border-red-200"
              : "border-gray-200")
          }
        >
          <div className="font-medium mb-0.5">{t.title}</div>
          {t.description && <div className="text-gray-600">{t.description}</div>}
          <div className="text-right mt-1">
            <button className="text-xs text-gray-500 hover:underline" onClick={() => onClose(t.id)}>
              Dismiss
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}