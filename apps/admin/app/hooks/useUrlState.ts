"use client";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useCallback, useMemo } from "react";

export default function useUrlState<T extends Record<string, string | number | undefined>>(initial: T) {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const state = useMemo(() => {
    const obj: any = { ...initial };
    for (const key of Object.keys(initial)) {
      const v = params.get(key);
      if (v !== null) obj[key] = v;
    }
    return obj as T;
  }, [params, initial]);

  const setState = useCallback((next: Partial<T>, options?: { replace?: boolean }) => {
    const sp = new URLSearchParams(params.toString());
    for (const [k, v] of Object.entries(next)) {
      if (v === undefined || v === null || v === "") sp.delete(k);
      else sp.set(k, String(v));
    }
    const url = `${pathname}?${sp.toString()}`;
    if (options?.replace ?? true) router.replace(url);
    else router.push(url);
  }, [params, pathname, router]);

  return [state, setState] as const;
}