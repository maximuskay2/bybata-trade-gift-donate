"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import Link from "next/link";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import Button from "@/app/components/ui/button";

interface AdminUser {
  id: string;
  email: string;
  role: string;
  banned?: boolean;
  banNote?: string | null;
  bannedUntil?: string | null;
  profile?: { displayName?: string; avatarKey?: string };
  _count?: {
    trades?: number;
    giftsGiven?: number;
    campaignsFounded?: number;
    donations?: number;
    communityMemberships?: number;
  };
}

import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";

export default function UsersPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc", role: "", kyc: "" });
  const [q, setQ] = useState<string>((urlState.q as any) || "");
  const debouncedQ = useDebounce(q, 400);

  const page = Number(urlState.page) || 1;
  const size = Number(urlState.size) || 20;
  const sort = (urlState.sort as string) || "createdAt";
  const dir = (urlState.dir as "asc" | "desc") || "desc";
  const role = (urlState.role as string) || "";
  const kyc = (urlState.kyc as string) || "";

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["users", page, size, debouncedQ, sort, dir, role, kyc],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(size), sort, dir });
        if (debouncedQ) params.set("query", debouncedQ);
        if (role) params.set("role", role);
        if (kyc) params.set("kyc", kyc);
        const res = await api.get<{ items: AdminUser[]; total: number }>(`/v1/admin/users?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: AdminUser[]; total: number };
      }
    },
  });

  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const banUser = async (id: string, type: "ban" | "suspend") => {
    const note = window.prompt(`Reason to ${type} (optional)`) || undefined;
    let durationMinutes: number | undefined;
    if (type === "suspend") {
      const raw = window.prompt("Suspend duration in minutes") || "";
      durationMinutes = Number(raw);
      if (!Number.isFinite(durationMinutes) || durationMinutes <= 0) {
        return;
      }
      const confirmed = window.confirm(`Suspend this user for ${durationMinutes} minutes?`);
      if (!confirmed) return;
    } else {
      const confirmed = window.confirm("Ban this user?");
      if (!confirmed) return;
    }
    try {
      setActionLoading(`${type}:${id}`);
      await api.patch(`/v1/admin/users/${id}`, { ban: type === "ban", note, durationMinutes });
      await refetch();
    } finally {
      setActionLoading(null);
    }
  };

  const unbanUser = async (id: string) => {
    try {
      setActionLoading(`unban:${id}`);
      await api.patch(`/v1/admin/users/${id}/unban`);
      await refetch();
    } finally {
      setActionLoading(null);
    }
  };

  const deleteUser = async (id: string) => {
    const confirmed = window.confirm("Delete this user? This cannot be undone.");
    if (!confirmed) return;
    try {
      setActionLoading(`delete:${id}`);
      try {
        await api.delete(`/v1/admin/users/${id}`);
      } catch (error: any) {
        if (error?.response?.status === 404) {
          await api.post(`/v1/admin/users/${id}/delete`);
        } else {
          throw error;
        }
      }
      await refetch();
    } finally {
      setActionLoading(null);
    }
  };

  const columns = useMemo<Column<AdminUser>[]>(
    () => [
      { key: "email", header: "Email", sortable: true },
      { key: "displayName", header: "Display name", render: (u) => u.profile?.displayName ?? "-", sortable: true },
      { key: "role", header: "Role", sortable: true },
      {
        key: "action",
        header: "Actions",
        render: (u) => (
          <div className="flex items-center gap-2 flex-wrap">
            <Link href={`/users/${u.id}`} className="px-2 py-1 text-xs font-medium bg-indigo-100 text-indigo-700 rounded hover:bg-indigo-200 transition">View</Link>
            <button
              className="px-2 py-1 text-xs font-medium bg-red-100 text-red-700 rounded hover:bg-red-200 transition disabled:opacity-50"
              disabled={actionLoading === `ban:${u.id}`}
              onClick={() => banUser(u.id, "ban")}
            >
              Ban
            </button>
            <button
              className="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700 rounded hover:bg-yellow-200 transition disabled:opacity-50"
              disabled={actionLoading === `suspend:${u.id}`}
              onClick={() => banUser(u.id, "suspend")}
            >
              Suspend
            </button>
            {u.banned && (
              <button
                className="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded hover:bg-green-200 transition disabled:opacity-50"
                disabled={actionLoading === `unban:${u.id}`}
                onClick={() => unbanUser(u.id)}
              >
                Unban
              </button>
            )}
            <button
              className="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition disabled:opacity-50"
              disabled={actionLoading === `delete:${u.id}`}
              onClick={() => deleteUser(u.id)}
            >
              Delete
            </button>
          </div>
        ),
        className: "min-w-[380px]",
      },
      {
        key: "trades",
        header: "Trades",
        render: (u) => (u._count?.trades ?? 0).toString(),
      },
      {
        key: "gifts",
        header: "Gifts",
        render: (u) => (u._count?.giftsGiven ?? 0).toString(),
      },
      {
        key: "campaigns",
        header: "Campaigns",
        render: (u) => (u._count?.campaignsFounded ?? 0).toString(),
      },
      {
        key: "donations",
        header: "Donations",
        render: (u) => (u._count?.donations ?? 0).toString(),
      },
      {
        key: "communities",
        header: "Communities",
        render: (u) => (u._count?.communityMemberships ?? 0).toString(),
      },
      {
        key: "status",
        header: "Status",
        render: (u) => {
          let bgColor = "bg-green-100 text-green-800";
          let text = "ACTIVE";
          if (u.banned) {
            if (u.bannedUntil) {
              bgColor = "bg-yellow-100 text-yellow-800";
              text = "SUSPENDED";
            } else {
              bgColor = "bg-red-100 text-red-800";
              text = "BANNED";
            }
          }
          return <span className={`inline-block px-3 py-1 rounded-full text-xs font-semibold ${bgColor}`}>{text}</span>;
        },
      },
      {
        key: "banUntil",
        header: "Until",
        render: (u) => (u.bannedUntil ? new Date(u.bannedUntil).toLocaleString() : "-"),
      },
      {
        key: "action",
        header: "Action",
        render: (u) => (
          <div className="flex items-center gap-2">
            <Link href={`/users/${u.id}`} className="px-2 py-1 text-xs font-medium bg-indigo-100 text-indigo-700 rounded hover:bg-indigo-200 transition">View</Link>
            <button
              className="px-2 py-1 text-xs font-medium bg-red-100 text-red-700 rounded hover:bg-red-200 transition disabled:opacity-50"
              disabled={actionLoading === `ban:${u.id}`}
              onClick={() => banUser(u.id, "ban")}
            >
              Ban
            </button>
            <button
              className="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-700 rounded hover:bg-yellow-200 transition disabled:opacity-50"
              disabled={actionLoading === `suspend:${u.id}`}
              onClick={() => banUser(u.id, "suspend")}
            >
              Suspend
            </button>
            {u.banned && (
              <button
                className="px-2 py-1 text-xs font-medium bg-green-100 text-green-700 rounded hover:bg-green-200 transition disabled:opacity-50"
                disabled={actionLoading === `unban:${u.id}`}
                onClick={() => unbanUser(u.id)}
              >
                Unban
              </button>
            )}
            <button
              className="px-2 py-1 text-xs font-medium bg-gray-200 text-gray-700 rounded hover:bg-gray-300 transition disabled:opacity-50"
              disabled={actionLoading === `delete:${u.id}`}
              onClick={() => deleteUser(u.id)}
            >
              Delete
            </button>
          </div>
        ),
        className: "min-w-[380px]",
      },
    ],
    [actionLoading, refetch]
  );

  const rows = useMemo(() => data.items.map((u) => ({ ...u, displayName: u.profile?.displayName ?? "" })), [data]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Users Management"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Users" }]}
        description="Manage and monitor all platform users"
        actions={
          <div className="flex items-center gap-2">
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search users…"
              className="px-4 py-2 text-sm rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-all"
            />
            <select
              className="px-3 py-2 text-sm rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-all"
              value={role}
              onChange={(e) => setUrlState({ role: e.target.value, page: 1 })}
            >
              <option value="">All roles</option>
              <option value="USER">USER</option>
              <option value="MODERATOR">MODERATOR</option>
              <option value="ADMIN">ADMIN</option>
            </select>
            <select
              className="px-3 py-2 text-sm rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-all"
              value={kyc}
              onChange={(e) => setUrlState({ kyc: e.target.value, page: 1 })}
            >
              <option value="">All KYC</option>
              <option value="NOT_VERIFIED">NOT_VERIFIED</option>
              <option value="PENDING">PENDING</option>
              <option value="VERIFIED">VERIFIED</option>
              <option value="REJECTED">REJECTED</option>
            </select>
            <Button variant="outline" onClick={() => refetch()}>Refresh</Button>
          </div>
        }
      />
      <div className="rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm overflow-hidden">
        <Table
          columns={columns}
          data={rows as any}
          loading={isLoading}
          error={isError && "Failed to load users"}
          emptyLabel="No users found"
          pagination={{
            page,
            pageSize: size,
            total: data.total,
            onPageChange: (p) => setUrlState({ page: p }),
            onPageSizeChange: (s) => setUrlState({ size: s, page: 1 }),
          }}
          sortKey={sort}
          sortDir={dir as any}
          onSortChange={(key, d) => setUrlState({ sort: key, dir: d })}
        />
      </div>
    </div>
  );
}
