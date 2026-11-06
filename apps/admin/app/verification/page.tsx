"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { api } from "@/app/lib/api";
import PageHeader from "@/app/components/page-header";
import Button from "@/app/components/ui/button";
import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";

type Submission = {
  userId: string;
  email: string | null;
  displayName: string | null;
  phone: string | null;
  phoneVerified: boolean;
  emailVerified: boolean;
  kycStatus: string;
  documentCount: number;
  pendingCount: number;
  approvedCount: number;
  rejectedCount: number;
  lastSubmittedAt: string | null;
  documentTypes: string[];
};

function kycBadge(status: string) {
  const map: Record<string, string> = {
    PENDING: "bg-amber-100 text-amber-900 border-amber-200",
    VERIFIED: "bg-emerald-100 text-emerald-900 border-emerald-200",
    REJECTED: "bg-red-100 text-red-900 border-red-200",
    NOT_VERIFIED: "bg-slate-100 text-slate-700 border-slate-200",
  };
  return map[status] || map.NOT_VERIFIED;
}

function formatType(type: string) {
  return type
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .toLowerCase()
    .replace(/^\w/, (c) => c.toUpperCase());
}

export default function VerificationSubmissionsPage() {
  const [urlState, setUrlState] = useUrlState({
    page: 1,
    size: 20,
    status: "PENDING",
    kyc: "",
    q: "",
  });

  const page = Number(urlState.page) || 1;
  const size = Number(urlState.size) || 20;
  const statusFilter = (urlState.status as string) || "";
  const kycFilter = (urlState.kyc as string) || "";
  const q = (urlState.q as string) || "";
  const debouncedQ = useDebounce(q, 300);

  const { data = { items: [], total: 0 }, isLoading, isError, refetch, isFetching } =
    useQuery({
      queryKey: ["verification-submissions", page, size, statusFilter, kycFilter, debouncedQ],
      queryFn: async () => {
        const params = new URLSearchParams({
          page: String(page),
          size: String(size),
        });
        if (statusFilter) params.set("status", statusFilter);
        if (kycFilter) params.set("kyc", kycFilter);
        if (debouncedQ) params.set("q", debouncedQ);
        const res = await api.get<{ items: Submission[]; total: number }>(
          `/v1/admin/verification/submissions?${params.toString()}`,
        );
        return res.data;
      },
    });

  const pendingTotal = useMemo(
    () => data.items.reduce((n, s) => n + s.pendingCount, 0),
    [data.items],
  );

  return (
    <div className="space-y-5">
      <PageHeader
        title="Identity verification"
        breadcrumb={[
          { label: "Home", href: "/dashboard" },
          { label: "Verification" },
        ]}
        actions={
          <Button variant="secondary" onClick={() => refetch()} disabled={isFetching}>
            {isFetching ? "Refreshing…" : "Refresh"}
          </Button>
        }
      />

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="rounded-xl border border-amber-200 bg-amber-50/80 px-4 py-3">
          <div className="text-xs font-semibold uppercase tracking-wide text-amber-800/80">
            Queue
          </div>
          <div className="mt-1 text-2xl font-bold text-amber-950">{data.total}</div>
          <div className="text-xs text-amber-800/70">users with submissions</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white px-4 py-3">
          <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Pending docs (page)
          </div>
          <div className="mt-1 text-2xl font-bold text-slate-900">{pendingTotal}</div>
          <div className="text-xs text-slate-500">awaiting review on this page</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white px-4 py-3">
          <div className="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Tip
          </div>
          <div className="mt-1 text-sm text-slate-700 leading-snug">
            Open a user to review every document they submitted together.
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <input
          className="w-full sm:max-w-sm rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400"
          placeholder="Search name or email…"
          value={q}
          onChange={(e) => setUrlState({ q: e.target.value, page: 1 })}
        />
        <div className="flex flex-wrap items-center gap-2">
          <select
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
            value={statusFilter}
            onChange={(e) => setUrlState({ status: e.target.value, page: 1 })}
          >
            <option value="">All document statuses</option>
            <option value="PENDING">Has pending docs</option>
            <option value="APPROVED">Has approved docs</option>
            <option value="REJECTED">Has rejected docs</option>
          </select>
          <select
            className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
            value={kycFilter}
            onChange={(e) => setUrlState({ kyc: e.target.value, page: 1 })}
          >
            <option value="">All KYC</option>
            <option value="PENDING">KYC pending</option>
            <option value="VERIFIED">KYC verified</option>
            <option value="REJECTED">KYC rejected</option>
            <option value="NOT_VERIFIED">Not verified</option>
          </select>
        </div>
      </div>

      {isLoading && (
        <div className="rounded-xl border border-slate-200 bg-white p-10 text-center text-slate-500">
          Loading submissions…
        </div>
      )}

      {isError && (
        <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-red-800">
          Failed to load verification submissions.
        </div>
      )}

      {!isLoading && !isError && data.items.length === 0 && (
        <div className="rounded-xl border border-dashed border-slate-300 bg-white p-12 text-center">
          <div className="text-lg font-semibold text-slate-800">No submissions</div>
          <p className="mt-1 text-sm text-slate-500">
            Users who upload ID documents will appear here for review.
          </p>
        </div>
      )}

      <div className="space-y-3">
        {data.items.map((s) => {
          const name = s.displayName || s.email || "Unknown user";
          const initials = name
            .split(/\s+/)
            .slice(0, 2)
            .map((p) => p[0]?.toUpperCase() || "")
            .join("");
          return (
            <Link
              key={s.userId}
              href={`/verification/users/${s.userId}`}
              className="block rounded-2xl border border-slate-200 bg-white p-4 shadow-sm transition hover:border-indigo-300 hover:shadow-md"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-start gap-3 min-w-0">
                  <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-indigo-600 text-sm font-bold text-white">
                    {initials || "?"}
                  </div>
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="truncate font-semibold text-slate-900">{name}</h3>
                      <span
                        className={`inline-flex rounded-full border px-2 py-0.5 text-[11px] font-semibold ${kycBadge(
                          s.kycStatus,
                        )}`}
                      >
                        {s.kycStatus.replace(/_/g, " ")}
                      </span>
                    </div>
                    <div className="mt-0.5 truncate text-sm text-slate-500">{s.email}</div>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {s.documentTypes.map((t) => (
                        <span
                          key={t}
                          className="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-700"
                        >
                          {formatType(t)}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-3 sm:justify-end">
                  <div className="flex gap-2 text-center">
                    <StatChip label="Docs" value={s.documentCount} />
                    <StatChip
                      label="Pending"
                      value={s.pendingCount}
                      tone={s.pendingCount > 0 ? "amber" : "muted"}
                    />
                    <StatChip label="OK" value={s.approvedCount} tone="green" />
                    <StatChip label="Rejected" value={s.rejectedCount} tone="red" />
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-slate-400">Last submitted</div>
                    <div className="text-sm font-medium text-slate-700">
                      {s.lastSubmittedAt
                        ? new Date(s.lastSubmittedAt).toLocaleString()
                        : "—"}
                    </div>
                    <div className="mt-1 text-sm font-semibold text-indigo-600">
                      Review submission →
                    </div>
                  </div>
                </div>
              </div>
            </Link>
          );
        })}
      </div>

      {data.total > size && (
        <div className="flex items-center justify-between gap-3 pt-2">
          <div className="text-sm text-slate-500">
            Page {page} · {data.total} users
          </div>
          <div className="flex gap-2">
            <Button
              variant="secondary"
              disabled={page <= 1}
              onClick={() => setUrlState({ page: page - 1 })}
            >
              Previous
            </Button>
            <Button
              variant="secondary"
              disabled={page * size >= data.total}
              onClick={() => setUrlState({ page: page + 1 })}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}

function StatChip({
  label,
  value,
  tone = "muted",
}: {
  label: string;
  value: number;
  tone?: "muted" | "amber" | "green" | "red";
}) {
  const tones = {
    muted: "bg-slate-50 text-slate-700 border-slate-200",
    amber: "bg-amber-50 text-amber-900 border-amber-200",
    green: "bg-emerald-50 text-emerald-900 border-emerald-200",
    red: "bg-red-50 text-red-900 border-red-200",
  };
  return (
    <div className={`min-w-[58px] rounded-lg border px-2 py-1.5 ${tones[tone]}`}>
      <div className="text-base font-bold leading-none">{value}</div>
      <div className="mt-0.5 text-[10px] font-semibold uppercase tracking-wide opacity-70">
        {label}
      </div>
    </div>
  );
}
