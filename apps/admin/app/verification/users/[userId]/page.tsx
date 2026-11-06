"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useParams } from "next/navigation";
import Link from "next/link";
import { api } from "@/app/lib/api";
import PageHeader from "@/app/components/page-header";
import Button from "@/app/components/ui/button";
import { useToast } from "@/app/components/ui/toast";

type Doc = {
  id: string;
  type: string;
  documentKey: string;
  fileName: string;
  status: string;
  uploadedAt: string;
  reviewedAt: string | null;
  rejectionReason: string | null;
};

type Packet = {
  user: {
    id: string;
    email: string;
    emailVerifiedAt: string | null;
    createdAt: string;
    profile: {
      displayName: string | null;
      phone: string | null;
      phoneVerifiedAt: string | null;
      kycStatus: string;
      kycNote: string | null;
      location: string | null;
      countryCode: string | null;
    } | null;
  };
  documents: Doc[];
  summary: {
    total: number;
    pending: number;
    approved: number;
    rejected: number;
  };
};

function statusClass(status: string) {
  if (status === "PENDING") return "bg-amber-100 text-amber-900 border-amber-200";
  if (status === "APPROVED") return "bg-emerald-100 text-emerald-900 border-emerald-200";
  return "bg-red-100 text-red-900 border-red-200";
}

function formatType(type: string) {
  return type
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/^\w/, (c) => c.toUpperCase());
}

function isPdf(doc: Doc) {
  const name = `${doc.fileName || ""} ${doc.documentKey || ""}`.toLowerCase();
  return name.includes(".pdf");
}

export default function UserVerificationReviewPage() {
  const params = useParams();
  const userId = params.userId as string;
  const qc = useQueryClient();
  const { push } = useToast();

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [rejectionReason, setRejectionReason] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["verification-user", userId],
    queryFn: async () => {
      const res = await api.get<Packet>(`/v1/admin/verification/users/${userId}`);
      return res.data;
    },
    enabled: !!userId,
  });

  const selected = useMemo(() => {
    if (!data?.documents?.length) return null;
    return (
      data.documents.find((d) => d.id === selectedId) ||
      data.documents.find((d) => d.status === "PENDING") ||
      data.documents[0]
    );
  }, [data, selectedId]);

  useEffect(() => {
    if (selected && selected.id !== selectedId) {
      setSelectedId(selected.id);
    }
  }, [selected, selectedId]);

  const loadPreview = useCallback(async (docId: string) => {
    setLoadingPreview(true);
    setPreviewUrl(null);
    try {
      const res = await api.get<{ url: string | null }>(
        `/v1/admin/verification/documents/${docId}/preview-url`,
      );
      setPreviewUrl(res.data?.url ?? null);
    } catch {
      setPreviewUrl(null);
    } finally {
      setLoadingPreview(false);
    }
  }, []);

  useEffect(() => {
    if (selected?.id) loadPreview(selected.id);
  }, [selected?.id, loadPreview]);

  const invalidate = async () => {
    await qc.invalidateQueries({ queryKey: ["verification-user", userId] });
    await qc.invalidateQueries({ queryKey: ["verification-submissions"] });
    await refetch();
  };

  const approveDoc = async (docId: string) => {
    try {
      setBusy(`approve-${docId}`);
      await api.put(`/v1/admin/verification/documents/${docId}/approve`, {});
      push({ title: "Document approved", variant: "success" });
      await invalidate();
    } catch (e: any) {
      push({
        title: "Approve failed",
        description: e?.response?.data?.message,
        variant: "error",
      });
    } finally {
      setBusy(null);
    }
  };

  const rejectDoc = async (docId: string) => {
    if (!rejectionReason.trim()) {
      push({ title: "Enter a rejection reason", variant: "error" });
      return;
    }
    try {
      setBusy(`reject-${docId}`);
      await api.put(`/v1/admin/verification/documents/${docId}/reject`, {
        reason: rejectionReason.trim(),
      });
      push({ title: "Document rejected", variant: "success" });
      setRejectionReason("");
      await invalidate();
    } catch (e: any) {
      push({
        title: "Reject failed",
        description: e?.response?.data?.message,
        variant: "error",
      });
    } finally {
      setBusy(null);
    }
  };

  const approveAll = async () => {
    try {
      setBusy("approve-all");
      await api.put(`/v1/admin/verification/users/${userId}/approve`, {});
      push({ title: "User verified", description: "All pending documents approved", variant: "success" });
      await invalidate();
    } catch (e: any) {
      push({
        title: "Approve failed",
        description: e?.response?.data?.message,
        variant: "error",
      });
    } finally {
      setBusy(null);
    }
  };

  const rejectAll = async () => {
    if (!rejectionReason.trim()) {
      push({ title: "Enter a rejection reason", variant: "error" });
      return;
    }
    try {
      setBusy("reject-all");
      await api.put(`/v1/admin/verification/users/${userId}/reject`, {
        reason: rejectionReason.trim(),
      });
      push({ title: "Verification rejected", variant: "success" });
      setRejectionReason("");
      await invalidate();
    } catch (e: any) {
      push({
        title: "Reject failed",
        description: e?.response?.data?.message,
        variant: "error",
      });
    } finally {
      setBusy(null);
    }
  };

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center text-slate-500">
        Loading submission…
      </div>
    );
  }

  if (isError || !data) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-4 text-red-800">
        Failed to load this verification submission.
      </div>
    );
  }

  const profile = data.user.profile;
  const name = profile?.displayName || data.user.email;
  const hasPending = data.summary.pending > 0;

  return (
    <div className="space-y-5">
      <PageHeader
        title="Review submission"
        breadcrumb={[
          { label: "Home", href: "/dashboard" },
          { label: "Verification", href: "/verification" },
          { label: name },
        ]}
        actions={
          <Link href={`/users/${userId}`}>
            <Button variant="secondary">Open user profile</Button>
          </Link>
        }
      />

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-[320px_1fr]">
        {/* User + document list */}
        <div className="space-y-4">
          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <div className="flex items-start gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-indigo-600 text-sm font-bold text-white">
                {name
                  .split(/\s+/)
                  .slice(0, 2)
                  .map((p) => p[0]?.toUpperCase() || "")
                  .join("") || "?"}
              </div>
              <div className="min-w-0">
                <h2 className="truncate text-lg font-bold text-slate-900">{name}</h2>
                <p className="truncate text-sm text-slate-500">{data.user.email}</p>
                <span
                  className={`mt-2 inline-flex rounded-full border px-2 py-0.5 text-[11px] font-semibold ${statusClass(
                    profile?.kycStatus === "VERIFIED"
                      ? "APPROVED"
                      : profile?.kycStatus === "REJECTED"
                        ? "REJECTED"
                        : "PENDING",
                  )}`}
                >
                  KYC: {(profile?.kycStatus || "NOT_VERIFIED").replace(/_/g, " ")}
                </span>
              </div>
            </div>

            <dl className="mt-4 space-y-2 border-t border-slate-100 pt-4 text-sm">
              <Row
                label="Phone"
                value={
                  profile?.phone
                    ? `${profile.phone}${profile.phoneVerifiedAt ? " · verified" : ""}`
                    : "—"
                }
              />
              <Row
                label="Email"
                value={data.user.emailVerifiedAt ? "Verified" : "Not verified"}
              />
              <Row label="Location" value={profile?.location || profile?.countryCode || "—"} />
              <Row
                label="Joined"
                value={new Date(data.user.createdAt).toLocaleDateString()}
              />
              {profile?.kycNote && <Row label="KYC note" value={profile.kycNote} />}
            </dl>

            <div className="mt-4 grid grid-cols-4 gap-2 text-center">
              <MiniStat label="Total" value={data.summary.total} />
              <MiniStat label="Pending" value={data.summary.pending} tone="amber" />
              <MiniStat label="Approved" value={data.summary.approved} tone="green" />
              <MiniStat label="Rejected" value={data.summary.rejected} tone="red" />
            </div>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-3 shadow-sm">
            <div className="px-2 pb-2 pt-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
              Submitted documents
            </div>
            <div className="space-y-2">
              {data.documents.length === 0 && (
                <div className="px-2 py-6 text-center text-sm text-slate-500">
                  No documents uploaded.
                </div>
              )}
              {data.documents.map((doc) => {
                const active = selected?.id === doc.id;
                return (
                  <button
                    key={doc.id}
                    type="button"
                    onClick={() => setSelectedId(doc.id)}
                    className={`w-full rounded-xl border px-3 py-3 text-left transition ${
                      active
                        ? "border-indigo-400 bg-indigo-50 shadow-sm"
                        : "border-slate-200 bg-white hover:border-slate-300"
                    }`}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold text-slate-900">
                          {formatType(doc.type)}
                        </div>
                        <div className="truncate text-xs text-slate-500">{doc.fileName}</div>
                        <div className="mt-1 text-[11px] text-slate-400">
                          {new Date(doc.uploadedAt).toLocaleString()}
                        </div>
                      </div>
                      <span
                        className={`shrink-0 rounded-full border px-2 py-0.5 text-[10px] font-bold ${statusClass(
                          doc.status,
                        )}`}
                      >
                        {doc.status}
                      </span>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Preview + actions */}
        <div className="space-y-4">
          <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-5 py-4">
              <div>
                <h3 className="text-base font-bold text-slate-900">
                  {selected ? formatType(selected.type) : "Document preview"}
                </h3>
                <p className="text-sm text-slate-500">
                  {selected?.fileName || "Select a document from the list"}
                </p>
              </div>
              {selected && (
                <span
                  className={`rounded-full border px-2.5 py-1 text-xs font-bold ${statusClass(
                    selected.status,
                  )}`}
                >
                  {selected.status}
                </span>
              )}
            </div>

            <div className="flex min-h-[420px] items-center justify-center bg-slate-50 p-4">
              {!selected ? (
                <p className="text-slate-500">No document selected</p>
              ) : loadingPreview ? (
                <p className="text-slate-500">Loading preview…</p>
              ) : previewUrl ? (
                isPdf(selected) ? (
                  <iframe
                    src={previewUrl}
                    title="Document preview"
                    className="h-[520px] w-full rounded-lg border border-slate-200 bg-white"
                  />
                ) : (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={previewUrl}
                    alt={selected.fileName}
                    className="max-h-[560px] max-w-full rounded-lg object-contain shadow-sm"
                  />
                )
              ) : (
                <p className="text-slate-500">Preview not available</p>
              )}
            </div>

            {previewUrl && (
              <div className="border-t border-slate-100 px-5 py-3">
                <Button variant="secondary" onClick={() => window.open(previewUrl, "_blank")}>
                  Open full size
                </Button>
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
            <h3 className="text-base font-bold text-slate-900">Review actions</h3>
            <p className="mt-1 text-sm text-slate-500">
              Approve or reject the selected document, or decide the whole submission at once.
            </p>

            <textarea
              className="mt-4 w-full rounded-xl border border-slate-200 px-3 py-2 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-500/20"
              rows={3}
              placeholder="Rejection reason (required to reject)…"
              value={rejectionReason}
              onChange={(e) => setRejectionReason(e.target.value)}
            />

            <div className="mt-4 flex flex-col gap-2 sm:flex-row sm:flex-wrap">
              {selected?.status === "PENDING" && (
                <>
                  <Button
                    onClick={() => approveDoc(selected.id)}
                    disabled={!!busy}
                    className="bg-emerald-600 hover:bg-emerald-700"
                  >
                    {busy === `approve-${selected.id}` ? "Approving…" : "Approve this document"}
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={() => rejectDoc(selected.id)}
                    disabled={!!busy || !rejectionReason.trim()}
                  >
                    {busy === `reject-${selected.id}` ? "Rejecting…" : "Reject this document"}
                  </Button>
                </>
              )}
              {hasPending && (
                <>
                  <Button
                    onClick={approveAll}
                    disabled={!!busy}
                    className="bg-indigo-600 hover:bg-indigo-700"
                  >
                    {busy === "approve-all" ? "Approving…" : "Approve all & verify user"}
                  </Button>
                  <Button
                    variant="destructive"
                    onClick={rejectAll}
                    disabled={!!busy || !rejectionReason.trim()}
                  >
                    {busy === "reject-all" ? "Rejecting…" : "Reject entire submission"}
                  </Button>
                </>
              )}
              {!hasPending && selected?.status !== "PENDING" && (
                <p className="text-sm text-slate-500">
                  No pending documents left on this submission.
                </p>
              )}
            </div>

            {selected?.rejectionReason && (
              <div className="mt-4 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
                Previous rejection: {selected.rejectionReason}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-3">
      <dt className="text-slate-500">{label}</dt>
      <dd className="text-right font-medium text-slate-800">{value}</dd>
    </div>
  );
}

function MiniStat({
  label,
  value,
  tone = "muted",
}: {
  label: string;
  value: number;
  tone?: "muted" | "amber" | "green" | "red";
}) {
  const tones = {
    muted: "bg-slate-50 text-slate-800",
    amber: "bg-amber-50 text-amber-900",
    green: "bg-emerald-50 text-emerald-900",
    red: "bg-red-50 text-red-900",
  };
  return (
    <div className={`rounded-lg px-1 py-2 ${tones[tone]}`}>
      <div className="text-base font-bold">{value}</div>
      <div className="text-[10px] font-semibold uppercase opacity-70">{label}</div>
    </div>
  );
}
