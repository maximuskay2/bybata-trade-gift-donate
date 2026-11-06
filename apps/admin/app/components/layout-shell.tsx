"use client";
import { usePathname } from "next/navigation";
import { useState, type ReactNode } from "react";
import Sidebar from "@/app/components/sidebar";
import Topbar from "@/app/components/topbar";
import CommandPalette from "@/app/components/command-palette";

const bareRoutes = ["/login"];

export default function LayoutShell({ children }: { children: ReactNode }) {
  const pathname = usePathname() || "";
  const bare = bareRoutes.some((route) => pathname.startsWith(route));

  if (bare) {
    return <>{children}</>;
  }

  return <AdminChrome>{children}</AdminChrome>;
}

function AdminChrome({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(true);
  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 via-white to-gray-50 text-gray-900 flex overflow-hidden">
      <Sidebar open={open} onToggle={() => setOpen((v) => !v)} />
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Topbar onToggleSidebar={() => setOpen((v) => !v)} />
        <main className="flex-1 overflow-y-auto">
          <div className="p-6 max-w-7xl mx-auto">{children}</div>
        </main>
      </div>
      <CommandPalette />
    </div>
  );
}
