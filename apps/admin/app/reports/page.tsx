"use client";

import { useState, useEffect } from "react";
import useSWR from "swr";
import Link from "next/link";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import { Card } from "@/app/components/ui/card";
import { Button } from "@/app/components/ui/button";
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from "@/app/components/ui/select";
import { useToast } from "@/app/components/ui/use-toast";
import { Badge } from "@/app/components/ui/badge";
import { Ban, AlertTriangle, CheckCircle, XCircle, Eye, MessageSquare } from "lucide-react";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

const REASON_LABELS: Record<string, string> = {
  SCAM: "Scam",
  SUSPICIOUS_ACTIVITY: "Suspicious Activity",
  HARASSMENT: "Harassment",
  INAPPROPRIATE_CONTENT: "Inappropriate Content",
  SPAM: "Spam",
  VIOLENCE: "Violence",
  OTHER: "Other",
};

export default function ReportsPage() {
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [actionModal, setActionModal] = useState<{ report: any; open: boolean }>({ report: null, open: false });
  const [adminNote, setAdminNote] = useState("");
  const [suspendHours, setSuspendHours] = useState("24");
  const [actionLoading, setActionLoading] = useState(false);

  const query = new URLSearchParams();
  if (statusFilter) query.set("status", statusFilter);
  const { data, mutate } = useSWR(`/v1/admin/reports?${query}`, fetcher);
  const { toast } = useToast();
  const items = data?.items ?? [];

  const takeAction = async (action: string) => {
    if (!actionModal.report) return;
    setActionLoading(true);
    try {
      const payload: any = { action };
      if (adminNote) payload.adminNote = adminNote;
      if (action === "SUSPEND") payload.suspendDurationHours = parseInt(suspendHours, 10) || 24;
      await api.post(`/v1/admin/reports/${actionModal.report.id}/action`, payload);
      toast({ title: "Success", description: `Report ${action.toLowerCase()}ed` });
      setActionModal({ report: null, open: false });
      setAdminNote("");
      mutate();
    } catch (e: any) {
      toast({ title: "Error", description: e?.response?.data?.message || "Action failed", variant: "destructive" });
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <PageHeader
        title="User Reports"
        breadcrumb={[{ label: "Reports", href: "/reports" }]}
      />
      <Card className="p-4">
        <div className="flex flex-wrap gap-4 items-center">
          <div>
            <label className="text-sm text-gray-600">Status</label>
            <Select value={statusFilter || "all"} onValueChange={(v) => setStatusFilter(v === "all" ? "" : v)}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="PENDING">Pending</SelectItem>
                <SelectItem value="REVIEWING">Reviewing</SelectItem>
                <SelectItem value="RESOLVED">Resolved</SelectItem>
                <SelectItem value="DISMISSED">Dismissed</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="text-sm text-gray-600">
            Total: <strong>{data?.total ?? 0}</strong> reports
          </div>
        </div>
      </Card>
      <Card className="overflow-hidden">
        <div className="overflow-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="px-6 py-4 text-left font-semibold">Reporter</th>
                <th className="px-6 py-4 text-left font-semibold">Reported User</th>
                <th className="px-6 py-4 text-left font-semibold">Reason</th>
                <th className="px-6 py-4 text-left font-semibold">Details</th>
                <th className="px-6 py-4 text-left font-semibold">Status</th>
                <th className="px-6 py-4 text-left font-semibold">Date</th>
                <th className="px-6 py-4 text-left font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-6 py-12 text-center text-gray-500">
                    No reports found
                  </td>
                </tr>
              )}
              {items.map((r: any) => (
                <tr key={r.id} className="border-b hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div>
                      <div className="font-medium">{r.reporter?.profile?.displayName ?? r.reporter?.email ?? "-"}</div>
                      <div className="text-xs text-gray-500">{r.reporter?.email}</div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <Link href={`/users/${r.reportedUserId}`} className="text-indigo-600 hover:underline">
                      {r.reportedUser?.profile?.displayName ?? r.reportedUser?.email ?? r.reportedUserId}
                    </Link>
                  </td>
                  <td className="px-6 py-4">{REASON_LABELS[r.reason] ?? r.reason}</td>
                  <td className="px-6 py-4 max-w-[200px] truncate" title={r.details}>
                    {r.details || "-"}
                  </td>
                  <td className="px-6 py-4">
                    <Badge
                      variant={
                        r.status === "PENDING"
                          ? "secondary"
                          : r.status === "RESOLVED"
                            ? "default"
                            : "outline"
                      }
                    >
                      {r.status}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 text-gray-600">
                    {r.createdAt ? new Date(r.createdAt).toLocaleString() : "-"}
                  </td>
                  <td className="px-6 py-4">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setActionModal({ report: r, open: true })}
                    >
                      <Eye className="w-4 h-4 mr-1" />
                      Actions
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {actionModal.open && actionModal.report && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-md p-6 space-y-4">
            <h3 className="font-semibold text-lg">Take action on report</h3>
            <p className="text-sm text-gray-600">
              Reported: {actionModal.report.reportedUser?.profile?.displayName ?? actionModal.report.reportedUser?.email ?? actionModal.report.reportedUserId}
            </p>
            <div>
              <label className="text-sm text-gray-600">Admin note (optional)</label>
              <textarea
                className="w-full mt-1 border rounded p-2 text-sm"
                rows={2}
                value={adminNote}
                onChange={(e) => setAdminNote(e.target.value)}
                placeholder="Internal note..."
              />
            </div>
            <div>
              <label className="text-sm text-gray-600">Suspend duration (hours, for Suspend only)</label>
              <input
                type="number"
                className="w-full mt-1 border rounded p-2 text-sm"
                value={suspendHours}
                onChange={(e) => setSuspendHours(e.target.value)}
                min="1"
              />
            </div>
            <div className="flex gap-2 flex-wrap">
              <Button variant="outline" size="sm" onClick={() => takeAction("DISMISS")} disabled={actionLoading}>
                <XCircle className="w-4 h-4 mr-1" />
                Dismiss
              </Button>
              <Button variant="outline" size="sm" onClick={() => takeAction("WARN")} disabled={actionLoading}>
                <AlertTriangle className="w-4 h-4 mr-1" />
                Warn
              </Button>
              <Button variant="outline" size="sm" onClick={() => takeAction("SUSPEND")} disabled={actionLoading}>
                <Ban className="w-4 h-4 mr-1" />
                Suspend
              </Button>
              <Button variant="destructive" size="sm" onClick={() => takeAction("BAN")} disabled={actionLoading}>
                <Ban className="w-4 h-4 mr-1" />
                Ban
              </Button>
              <Button variant="secondary" onClick={() => setActionModal({ report: null, open: false })}>
                Cancel
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
