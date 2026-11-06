"use client";

import React, { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";

type AdRow = {
  id: string;
  title: string;
  description?: string | null;
  status: string;
  lifecycleLabel: string;
  mediaType?: string;
  mediaKeys?: string[];
  videoKey?: string | null;
  placementKey?: string | null;
  placementKeys?: string[];
  destinationUrl?: string | null;
  scheduledStart: string;
  scheduledEnd?: string | null;
  viewCount?: number;
  clickCount?: number;
  clickThroughRate?: number;
  costBYC?: number | null;
  daysRemaining?: number | null;
  renewEligible?: boolean;
  createdAt: string;
  user?: { id: string; email: string };
  userDisplayName?: string;
};

type Stats = {
  total: number;
  pendingReview: number;
  endingSoon: number;
  live: number;
  finished: number;
  byStatus: Record<string, number>;
};

type FilterKey =
  | "all"
  | "PENDING_REVIEW"
  | "SCHEDULED"
  | "ACTIVE"
  | "PAUSED"
  | "ending_soon"
  | "live"
  | "finished"
  | "EXPIRED"
  | "REJECTED"
  | "CANCELLED";

const FILTERS: { key: FilterKey; label: string; status?: string; lifecycle?: string }[] = [
  { key: "all", label: "All" },
  { key: "PENDING_REVIEW", label: "Pending review", status: "PENDING_REVIEW" },
  { key: "SCHEDULED", label: "Scheduled", status: "SCHEDULED" },
  { key: "ACTIVE", label: "Running", status: "ACTIVE" },
  { key: "PAUSED", label: "Paused", status: "PAUSED" },
  { key: "ending_soon", label: "Ending soon", lifecycle: "ending_soon" },
  { key: "live", label: "Live (all)", lifecycle: "live" },
  { key: "EXPIRED", label: "Expired", status: "EXPIRED" },
  { key: "REJECTED", label: "Rejected", status: "REJECTED" },
  { key: "CANCELLED", label: "Cancelled", status: "CANCELLED" },
  { key: "finished", label: "All finished", lifecycle: "finished" },
];

function statusBadge(status: string, lifecycleLabel?: string) {
  const label = lifecycleLabel && lifecycleLabel !== status ? lifecycleLabel : status;
  const colors: Record<string, string> = {
    PENDING_REVIEW: "bg-amber-100 text-amber-800 border-amber-200",
    SCHEDULED: "bg-blue-100 text-blue-800 border-blue-200",
    ACTIVE: "bg-green-100 text-green-800 border-green-200",
    Running: "bg-green-100 text-green-800 border-green-200",
    PAUSED: "bg-orange-100 text-orange-800 border-orange-200",
    "Ending soon": "bg-yellow-100 text-yellow-900 border-yellow-300",
    EXPIRED: "bg-gray-100 text-gray-700 border-gray-200",
    Finished: "bg-gray-100 text-gray-700 border-gray-200",
    REJECTED: "bg-red-100 text-red-800 border-red-200",
    CANCELLED: "bg-slate-100 text-slate-700 border-slate-200",
  };
  const cls = colors[label] ?? colors[status] ?? "bg-gray-100 text-gray-700 border-gray-200";
  return (
    <span className={`inline-block px-2 py-0.5 rounded-md text-xs font-semibold border ${cls}`}>
      {label.replace(/_/g, " ")}
    </span>
  );
}

export default function AllAdsPage() {
  const [items, setItems] = useState<AdRow[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [filter, setFilter] = useState<FilterKey>("all");
  const [q, setQ] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const activeFilter = useMemo(() => FILTERS.find((f) => f.key === filter) ?? FILTERS[0], [filter]);

  const fetchStats = useCallback(async () => {
    try {
      const res = await api.get<Stats>("/v1/admin/ads/stats");
      setStats(res.data);
    } catch {
      setStats(null);
    }
  }, []);

  const fetchAds = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params: Record<string, string> = {};
      if (activeFilter.status) params.status = activeFilter.status;
      if (activeFilter.lifecycle) params.lifecycle = activeFilter.lifecycle;
      if (search.trim()) params.q = search.trim();
      const res = await api.get<AdRow[]>("/v1/admin/ads/schedules", { params });
      setItems(res.data || []);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [activeFilter, search]);

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  useEffect(() => {
    fetchAds();
  }, [fetchAds]);

  useEffect(() => {
    const t = setTimeout(() => setSearch(q), 400);
    return () => clearTimeout(t);
  }, [q]);

  function countForFilter(key: FilterKey): number | null {
    if (!stats) return null;
    if (key === "all") return stats.total;
    if (key === "PENDING_REVIEW") return stats.byStatus.PENDING_REVIEW ?? stats.pendingReview;
    if (key === "ending_soon") return stats.endingSoon;
    if (key === "live") return stats.live;
    if (key === "finished") return stats.finished;
    return stats.byStatus[key] ?? 0;
  }

  return (
    <AdminGuard>
      <main className="p-6 max-w-[1400px] mx-auto">
        <motionDiv className="flex flex-wrap items-start justify-between gap-4 mb-6">
          <motionDiv>
            <h1 className="text-2xl font-bold text-gray-900">All feed ads</h1>
            <p className="text-sm text-gray-500 mt-1 max-w-2xl">
              Every ad campaign across all statuses — running, scheduled, ending soon, expired, rejected, and
              cancelled. Use this to help users renew or recreate ads. New submissions still go through{" "}
              <Link href="/ads-review" className="text-indigo-600 underline font-medium">
                Ads Review
              </Link>
              .
            </p>
          </motionDiv>
          <motionDiv className="flex gap-2">
            <Link
              href="/ads-review"
              className="px-4 py-2 text-sm rounded-lg border border-amber-300 bg-amber-50 text-amber-900 font-medium"
            >
              Pending review{stats ? ` (${stats.pendingReview})` : ""}
            </Link>
            <Link
              href="/promotions"
              className="px-4 py-2 text-sm rounded-lg bg-indigo-600 text-white font-medium"
            >
              Create ad
            </Link>
          </motionDiv>
        </motionDiv>

        {stats && (
          <motionDiv className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3 mb-6">
            <StatCard label="Total" value={stats.total} />
            <StatCard label="Pending review" value={stats.pendingReview} highlight="amber" />
            <StatCard label="Live" value={stats.live} highlight="green" />
            <StatCard label="Ending soon" value={stats.endingSoon} highlight="yellow" />
            <StatCard label="Running" value={stats.byStatus.ACTIVE ?? 0} />
            <StatCard label="Finished" value={stats.finished} />
          </motionDiv>
        )}

        <motionDiv className="flex flex-wrap gap-2 mb-4">
          {FILTERS.map((f) => {
            const count = countForFilter(f.key);
            const active = filter === f.key;
            return (
              <button
                key={f.key}
                type="button"
                onClick={() => setFilter(f.key)}
                className={`px-3 py-1.5 rounded-full text-xs font-semibold border transition-colors ${
                  active
                    ? "bg-indigo-600 text-white border-indigo-600"
                    : "bg-white text-gray-600 border-gray-200 hover:border-indigo-300"
                }`}
              >
                {f.label}
                {count != null ? ` (${count})` : ""}
              </button>
            );
          })}
        </motionDiv>

        <motionDiv className="mb-4">
          <input
            type="search"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search title, email, destination URL…"
            className="w-full max-w-md border border-gray-200 rounded-lg px-4 py-2 text-sm"
          />
        </motionDiv>

        {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

        <motionDiv className="rounded-xl border border-gray-200 bg-white shadow-sm overflow-x-auto">
          <table className="w-full text-sm min-w-[1000px]">
            <thead>
              <tr className="border-b bg-gray-50 text-left text-gray-700 font-semibold">
                <th className="px-4 py-3 w-8" />
                <th className="px-4 py-3">Title</th>
                <th className="px-4 py-3">Status</th>
                <th className="px-4 py-3">Advertiser</th>
                <th className="px-4 py-3">Placements</th>
                <th className="px-4 py-3">Schedule</th>
                <th className="px-4 py-3">Left</th>
                <th className="px-4 py-3">Performance</th>
                <th className="px-4 py-3">Cost</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading && (
                <tr>
                  <td colSpan={9} className="py-12 text-center text-gray-500">
                    Loading…
                  </td>
                </tr>
              )}
              {!loading &&
                items.map((ad) => (
                  <React.Fragment key={ad.id}>
                    <tr
                      className="hover:bg-gray-50 cursor-pointer"
                      onClick={() => setExpandedId(expandedId === ad.id ? null : ad.id)}
                    >
                      <td className="px-4 py-3 text-gray-400">{expandedId === ad.id ? "▼" : "▶"}</td>
                      <td className="px-4 py-3 font-medium text-gray-900 max-w-[200px] truncate">{ad.title}</td>
                      <td className="px-4 py-3">{statusBadge(ad.status, ad.lifecycleLabel)}</td>
                      <td className="px-4 py-3 text-gray-700">
                        <motionDiv className="truncate max-w-[160px]" title={ad.user?.email}>
                          <motionDiv>{ad.userDisplayName || ad.user?.email || "—"}</motionDiv>
                          <motionDiv className="text-xs text-gray-400 truncate">{ad.user?.email}</motionDiv>
                        </motionDiv>
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs max-w-[140px]">
                        {(ad.placementKeys?.length ? ad.placementKeys : ad.placementKey ? [ad.placementKey] : [])
                          .join(", ") || "—"}
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs whitespace-nowrap">
                        <motionDiv>
                          <motionDiv>{new Date(ad.scheduledStart).toLocaleDateString()}</motionDiv>
                          <motionDiv className="text-gray-400">
                            → {ad.scheduledEnd ? new Date(ad.scheduledEnd).toLocaleDateString() : "open"}
                          </motionDiv>
                        </motionDiv>
                      </td>
                      <td className="px-4 py-3 text-gray-700">
                        {ad.daysRemaining != null && (ad.status === "ACTIVE" || ad.status === "SCHEDULED")
                          ? `${ad.daysRemaining}d`
                          : "—"}
                      </td>
                      <td className="px-4 py-3 text-gray-600 text-xs">
                        {ad.viewCount ?? 0} views · {ad.clickCount ?? 0} clicks
                        <br />
                        <span className="text-gray-400">CTR {ad.clickThroughRate ?? 0}%</span>
                      </td>
                      <td className="px-4 py-3 text-gray-700 font-medium">
                        {ad.costBYC != null ? `${ad.costBYC} BYC` : "—"}
                      </td>
                    </tr>
                    {expandedId === ad.id && (
                      <tr className="bg-indigo-50/40">
                        <td colSpan={9} className="px-6 py-4">
                          <motionDiv className="grid sm:grid-cols-2 gap-4 text-sm">
                            <Detail label="Ad ID" value={ad.id} mono />
                            <Detail label="Created" value={new Date(ad.createdAt).toLocaleString()} />
                            <Detail
                              label="Media"
                              value={
                                ad.mediaType === "VIDEO"
                                  ? `Video (${ad.videoKey ?? "key missing"})`
                                  : `${ad.mediaKeys?.length ?? 0} image(s)`
                              }
                            />
                            <Detail label="Destination" value={ad.destinationUrl || "—"} link />
                            {ad.description && (
                              <Detail label="Description" value={ad.description} className="sm:col-span-2" />
                            )}
                            {ad.renewEligible && (
                              <motionDiv className="sm:col-span-2 rounded-lg bg-white border border-indigo-200 p-3 text-indigo-900">
                                <strong>Renew / reuse:</strong> User can create a new ad in the app (Promotion
                                Center → Create Ad) with the same creative, or you can create one on their behalf
                                via{" "}
                                <Link href="/promotions" className="underline font-medium">
                                  Ads & Promotions
                                </Link>
                                . This record is kept for history.
                              </motionDiv>
                            )}
                            {["PENDING_REVIEW", "REJECTED", "SCHEDULED", "PAUSED", "ACTIVE"].includes(
                              ad.status,
                            ) && (
                              <motionDiv className="sm:col-span-2 flex flex-wrap gap-3">
                                <Link
                                  href={`/ads/${ad.id}/edit`}
                                  className="inline-flex items-center px-4 py-2 rounded-lg bg-indigo-600 text-white text-sm font-semibold"
                                >
                                  Edit ad
                                </Link>
                                {ad.status === "PENDING_REVIEW" && (
                                  <Link
                                    href="/ads-review"
                                    className="inline-flex items-center px-4 py-2 rounded-lg border border-amber-300 bg-amber-50 text-amber-900 text-sm font-medium"
                                  >
                                    Open Ads Review →
                                  </Link>
                                )}
                              </motionDiv>
                            )}
                          </motionDiv>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                ))}
              {!loading && items.length === 0 && (
                <tr>
                  <td colSpan={9} className="py-12 text-center text-gray-500">
                    No ads match this filter.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </motionDiv>

        <p className="text-xs text-gray-400 mt-4">
          {items.length} ad{items.length === 1 ? "" : "s"} shown
          {search ? ` matching “${search}”` : ""}.
        </p>
      </main>
    </AdminGuard>
  );
}

function StatCard({
  label,
  value,
  highlight,
}: {
  label: string;
  value: number;
  highlight?: "amber" | "green" | "yellow";
}) {
  const border =
    highlight === "amber"
      ? "border-amber-200 bg-amber-50"
      : highlight === "green"
        ? "border-green-200 bg-green-50"
        : highlight === "yellow"
          ? "border-yellow-200 bg-yellow-50"
          : "border-gray-200 bg-white";
  return (
    <motionDiv className={`rounded-xl border p-3 ${border}`}>
      <p className="text-xs text-gray-500 font-medium">{label}</p>
      <p className="text-xl font-bold text-gray-900 mt-0.5">{value}</p>
    </motionDiv>
  );
}

function Detail({
  label,
  value,
  mono,
  link,
  className,
}: {
  label: string;
  value: string;
  mono?: boolean;
  link?: boolean;
  className?: string;
}) {
  return (
    <motionDiv className={className}>
      <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">{label}</p>
      {link && value.startsWith("http") ? (
        <a href={value} target="_blank" rel="noreferrer" className="text-indigo-600 underline break-all">
          {value}
        </a>
      ) : (
        <p className={`mt-0.5 text-gray-800 break-words ${mono ? "font-mono text-xs" : ""}`}>{value}</p>
      )}
    </motionDiv>
  );
}

function motionDiv({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return <div className={className}>{children}</div>;
}
