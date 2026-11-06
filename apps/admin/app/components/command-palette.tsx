"use client";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";

export default function CommandPalette() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [recentUsers, setRecentUsers] = useState<{ label: string; href: string }[]>([]);
  const [recentTrades, setRecentTrades] = useState<{ label: string; href: string }[]>([]);
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen((v) => !v);
      }
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    if (!open) return;
    (async () => {
      try {
        const ures = await api.get<{ items: any[] }>(`/v1/admin/users?page=1&size=5&sort=createdAt&dir=desc`);
        setRecentUsers((ures.data.items || []).map(u => ({ label: u.profile?.displayName || u.email, href: `/users/${u.id}` })));
      } catch { setRecentUsers([]); }
      try {
        const tres = await api.get<{ items: any[] }>(`/v1/admin/trades?page=1&size=5&sort=createdAt&dir=desc`);
        setRecentTrades((tres.data.items || []).map(t => ({ label: t.title, href: `/trades` })));
      } catch { setRecentTrades([]); }
    })();
  }, [open]);

  const staticCommands = useMemo(
    () => [
      { label: "Go to Dashboard", href: "/dashboard" },
      { label: "Go to Users", href: "/users" },
      { label: "Go to Trades", href: "/trades" },
      { label: "Go to Wallet", href: "/wallet" },
      { label: "Check API status", href: "/status" },
    ],
    []
  );

  const all = useMemo(() => {
    const groups = [
      { group: "Static", items: staticCommands },
      { group: "Recent users", items: recentUsers },
      { group: "Recent trades", items: recentTrades },
    ];
    const flat = groups.flatMap(g => g.items.map(i => ({ ...i, group: g.group })));
    const s = q.trim().toLowerCase();
    const filtered = s ? flat.filter(c => c.label.toLowerCase().includes(s)) : flat;
    return { groups, flat: filtered };
  }, [q, staticCommands, recentUsers, recentTrades]);

  const run = (href: string) => {
    setOpen(false);
    setQ("");
    router.push(href);
  };

  useEffect(() => {
    if (!open) return;
    setIndex(0);
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'ArrowDown') { e.preventDefault(); setIndex(i => Math.min(i + 1, all.flat.length - 1)); }
      if (e.key === 'ArrowUp') { e.preventDefault(); setIndex(i => Math.max(i - 1, 0)); }
      if (e.key === 'Enter') {
        const item = all.flat[index];
        if (item) run(item.href);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [open, all.flat, index]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50">
      <div className="absolute inset-0 bg-black/40" onClick={() => setOpen(false)} />
      <div className="relative mx-auto mt-24 w-full max-w-lg">
        <div className="bg-white rounded border shadow-md overflow-hidden">
          <div className="p-2 border-b">
            <input
              autoFocus
              placeholder="Type a command…"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              className="w-full px-3 py-2 text-sm outline-none"
            />
          </div>
          <div className="max-h-80 overflow-auto">
            {all.flat.length === 0 && (
              <div className="px-3 py-4 text-sm text-gray-500">No results</div>
            )}
            {all.flat.length > 0 && (
              <div>
                {all.flat.map((c, i) => (
                  <button
                    key={`${c.group}-${c.href}-${i}`}
                    onClick={() => run(c.href)}
                    className={`w-full text-left px-3 py-2 text-sm ${i === index ? 'bg-gray-100' : 'hover:bg-gray-50'}`}
                  >
                    <span className="text-gray-500 mr-2">[{c.group}]</span>
                    {c.label}
                  </button>
                ))}
              </div>
            )}
          </div>
          <div className="p-2 border-t text-xs text-gray-500 flex items-center justify-between">
            <span>Use ↑/↓ to navigate, Enter to select</span>
            <span>Cmd/Ctrl + K</span>
          </div>
        </div>
      </div>
    </div>
  );
}
