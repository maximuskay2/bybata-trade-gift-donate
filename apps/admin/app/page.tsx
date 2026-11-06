"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function HomeRedirect() {
  const router = useRouter();
  useEffect(() => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('admin_token') : null;
    router.replace(token ? '/dashboard' : '/login');
  }, [router]);
  return null;
}
