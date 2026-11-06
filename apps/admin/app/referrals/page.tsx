"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import Link from "next/link";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import useUrlState from "@/app/hooks/useUrlState";

interface ReferralItem {
  id: string;
  referrerId: string;
  referredUserId: string;
  referralCode: string;
  status: string;
  karmaAwarded: number;
  bycAwarded: number;
  signedUpAt: string | null;
  firstTradeAt: string | null;
  firstDonationAt: string | null;
  firstGiftAt: string | null;
  createdAt: string;
  referrer: { id: string; email: string; profile?: { displayName?: string; referralCode?: string } };
  referredUser: { id: string; email: string; createdAt: string; profile?: { displayName?: string } };
}

interface Stats {
  totalReferrals: number;
  totalReferrers: number;
  totalKarmaAwarded: number;
  totalBycEarned: number;
  byStatus: Record<string, number>;
}

export default function ReferralsPage() {
  const [urlState, setUrlState] = useUrlState({
    page: 1,
    size: 20,
    sort: "createdAt",
    dir: "desc",
    referrerId: "",
    referredUserId: "",
  });

  const page = Number(urlState.page) || 1;
  const size = Number(urlState.size) || 20;
  const sort = (urlState.sort as string) || "createdAt";
  const dir = (urlState.dir as "asc" | "desc") || "desc";
  const referrerId = (urlState.referrerId as string) || "";
  const referredUserId = (urlState.referredUserId as string) || "";

  const { data: listData, isLoading } = useQuery({
    queryKey: ["admin-referrals", page, size, sort, dir, referrerId, referredUserId],
    queryFn: async () => {
      const params = new URLSearchParams({ page: String(page), size: String(size), sort, dir });
      if (referrerId) params.set("referrerId", referrerId);
      if (referredUserId) params.set("referredUserId", referredUserId);
      const res = await api.get<{ items: ReferralItem[]; total: number }>(
        `/v1/admin/referrals?${params.toString()}`
      );
      return res.data;
    },
  });

  const { data: stats } = useQuery({
    queryKey: ["admin-referrals-stats"],
    queryFn: async () => {
      const res = await api.get<Stats>("/v1/admin/referrals/stats");
      return res.data;
    },
  });

  const items = listData?.items ?? [];
  const total = listData?.total ?? 0;

  const columns = useMemo<Column<ReferralItem>[]>(
    () => [
      {
        key: "referrer",
        header: "Referrer",
        render: (r) => (
          <Link href={`/users/${r.referrerId}`} className="text-indigo-600 hover:underline">
            {r.referrer?.profile?.displayName ?? r.referrer?.email ?? r.referrerId}
          </Link>
        ),
      },
      {
        key: "referredUser",
        header: "Referred User",
        render: (r) => (
          <Link href={`/users/${r.referredUserId}`} className="text-indigo-600 hover:underline">
            {r.referredUser?.profile?.displayName ?? r.referredUser?.email ?? r.referredUserId}
          </Link>
        ),
      },
      { key: "referralCode", header: "Code", render: (r) => r.referralCode },
      {
        key: "status",
        header: "Status",
        render: (r) => (
          <span className="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-indigo-50 text-indigo-700">
            {r.status}
          </span>
        ),
      },
      { key: "karmaAwarded", header: "KARMA", render: (r) => r.karmaAwarded },
      { key: "bycAwarded", header: "BYC", render: (r) => r.bycAwarded.toFixed(2) },
      {
        key: "signedUpAt",
        header: "Signed up",
        render: (r) => (r.signedUpAt ? new Date(r.signedUpAt).toLocaleDateString() : "-"),
      },
      {
        key: "firstTradeAt",
        header: "First trade",
        render: (r) => (r.firstTradeAt ? new Date(r.firstTradeAt).toLocaleDateString() : "-"),
      },
      {
        key: "firstDonationAt",
        header: "First donation",
        render: (r) => (r.firstDonationAt ? new Date(r.firstDonationAt).toLocaleDateString() : "-"),
      },
      {
        key: "firstGiftAt",
        header: "First gift",
        render: (r) => (r.firstGiftAt ? new Date(r.firstGiftAt).toLocaleDateString() : "-"),
      },
    ],
    []
  );

  return (
    <div className="p-6">
      <PageHeader
        title="Referrals"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Referrals" }]}
        description="Manage referral relationships and rewards"
      />

      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div className="rounded-lg border bg-white p-4 shadow-sm">
            <div className="text-sm text-gray-500">Total Referrals</div>
            <div className="text-2xl font-bold text-gray-900">{stats.totalReferrals}</div>
          </div>
          <div className="rounded-lg border bg-white p-4 shadow-sm">
            <div className="text-sm text-gray-500">Unique Referrers</div>
            <div className="text-2xl font-bold text-gray-900">{stats.totalReferrers}</div>
          </div>
          <div className="rounded-lg border bg-white p-4 shadow-sm">
            <div className="text-sm text-gray-500">Total KARMA Awarded</div>
            <div className="text-2xl font-bold text-amber-600">{stats.totalKarmaAwarded}</div>
          </div>
          <div className="rounded-lg border bg-white p-4 shadow-sm">
            <div className="text-sm text-gray-500">Total BYC Earned</div>
            <div className="text-2xl font-bold text-emerald-600">{stats.totalBycEarned.toFixed(2)}</div>
          </div>
        </div>
      )}

      <div className="rounded-lg border bg-white shadow-sm">
        <div className="p-4 border-b flex flex-wrap gap-4 items-center">
          <input
            type="text"
            placeholder="Filter by referrer ID"
            value={referrerId}
            onChange={(e) => setUrlState({ referrerId: e.target.value, page: 1 })}
            className="rounded border px-3 py-2 text-sm w-48"
          />
          <input
            type="text"
            placeholder="Filter by referred user ID"
            value={referredUserId}
            onChange={(e) => setUrlState({ referredUserId: e.target.value, page: 1 })}
            className="rounded border px-3 py-2 text-sm w-48"
          />
        </div>
        <Table
          columns={columns}
          data={items}
          loading={isLoading}
          emptyLabel="No referrals found"
          pagination={{
            page,
            pageSize: size,
            total,
            onPageChange: (p) => setUrlState({ page: p }),
            onPageSizeChange: (s) => setUrlState({ size: s, page: 1 }),
          }}
          sortKey={sort}
          sortDir={dir}
          onSortChange={(key, d) => setUrlState({ sort: key, dir: d })}
        />
      </div>
    </div>
  );
}
