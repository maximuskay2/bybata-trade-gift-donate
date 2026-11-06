import type { Metadata } from "next";
import type { ReactNode } from "react";
import LayoutShell from "@/app/components/layout-shell";
import AdminGuard from "@/app/components/admin-guard";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "BYBATA Admin Panel",
  description: "Administrative dashboard for BYBATA platform",
};

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body suppressHydrationWarning>
        <Providers>
          <AdminGuard>
            <LayoutShell>{children}</LayoutShell>
          </AdminGuard>
        </Providers>
      </body>
    </html>
  );
}
