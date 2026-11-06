"use client";
import React from "react";
import { usePathname, useRouter } from "next/navigation";

export default function AdminGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname() || "";
  const isLogin = pathname.startsWith("/login");
  const [ready, setReady] = React.useState(isLogin);

  React.useEffect(() => {
    if (isLogin) {
      setReady(true);
      return;
    }

    const token =
      typeof window !== "undefined"
        ? localStorage.getItem("admin_token")
        : null;

    if (!token) {
      router.replace("/login");
      return;
    }

    setReady(true);
  }, [isLogin, pathname, router]);

  if (!ready) {
    return (
      <div className="min-h-screen flex items-center justify-center text-sm text-gray-500">
        Checking session…
      </div>
    );
  }

  return <>{children}</>;
}
