"use client";

import { useState } from "react";
import useSWR from "swr";
import Link from "next/link";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import { Card } from "@/app/components/ui/card";
import { Button } from "@/app/components/ui/button";
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from "@/app/components/ui/select";
import { useToast } from "@/app/components/ui/use-toast";
import { Badge } from "@/app/components/ui/badge";
import { CheckCircle, XCircle } from "lucide-react";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function AppealsPage() {
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [reviewModal, setReviewModal] = useState<{ appeal: any; open: boolean }>({ appeal: null, open: false });
  const [adminNote, setAdminNote] = useState("");
  const [loading, setLoading] = useState(false);

  const query = new URLSearchParams();
  if (statusFilter) query.set("status", statusFilter);
  const { data, mutate } = useSWR(`/v1/admin/appeals?${query}`, fetcher);
  const { toast } = useToast();
  const items = data?.items ?? [];

  const reviewAppeal = async (status: "APPROVED" | "REJECTED") => {
    if (!reviewModal.appeal) return;
    setLoading(true);
    try {
      await api.post(`/v1/admin/appeals/${reviewModal.appeal.id}/review`, {
        status,
        adminNote: adminNote || undefined,
      });
      toast({ title: "Success", description: `Appeal ${status.toLowerCase()}` });
      setReviewModal({ appeal: null, open: false });
      setAdminNote("");
      mutate();
    } catch (e: any) {
      toast({ title: "Error", description: e?.response?.data?.message || "Review failed", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <PageHeader
        title="User Appeals"
        breadcrumb={[{ label: "Appeals", href: "/appeals" }]}
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
                <SelectItem value="UNDER_REVIEW">Under Review</SelectItem>
                <SelectItem value="APPROVED">Approved</SelectItem>
                <SelectItem value="REJECTED">Rejected</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="text-sm text-gray-600">
            Total: <strong>{data?.total ?? 0}</strong> appeals
          </div>
        </div>
      </Card>
      <Card className="overflow-hidden">
        <div className="overflow-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-gray-50">
                <th className="px-6 py-4 text-left font-semibold">User</th>
                <th className="px-6 py-4 text-left font-semibold">Reason</th>
                <th className="px-6 py-4 text-left font-semibold">Status</th>
                <th className="px-6 py-4 text-left font-semibold">Date</th>
                <th className="px-6 py-4 text-left font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.length === 0 && (
                <tr>
                  <td colSpan={5} className="px-6 py-12 text-center text-gray-500">
                    No appeals found
                  </td>
                </tr>
              )}
              {items.map((a: any) => (
                <tr key={a.id} className="border-b hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <Link href={`/users/${a.userId}`} className="text-indigo-600 hover:underline">
                      {a.user?.profile?.displayName ?? a.user?.email ?? a.userId}
                    </Link>
                  </td>
                  <td className="px-6 py-4 max-w-[300px] truncate" title={a.reason}>
                    {a.reason}
                  </td>
                  <td className="px-6 py-4">
                    <Badge
                      variant={
                        a.status === "PENDING"
                          ? "secondary"
                          : a.status === "APPROVED"
                            ? "default"
                            : a.status === "REJECTED"
                              ? "destructive"
                              : "outline"
                      }
                    >
                      {a.status}
                    </Badge>
                  </td>
                  <td className="px-6 py-4 text-gray-600">
                    {a.createdAt ? new Date(a.createdAt).toLocaleString() : "-"}
                  </td>
                  <td className="px-6 py-4">
                    {(a.status === "PENDING" || a.status === "UNDER_REVIEW") && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setReviewModal({ appeal: a, open: true })}
                      >
                        Review
                      </Button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {reviewModal.open && reviewModal.appeal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="w-full max-w-lg p-6 space-y-4">
            <h3 className="font-semibold text-lg">Review Appeal</h3>
            <p className="text-sm text-gray-600">
              User: {reviewModal.appeal.user?.profile?.displayName ?? reviewModal.appeal.user?.email ?? reviewModal.appeal.userId}
            </p>
            <div className="p-3 bg-gray-50 rounded text-sm">
              {reviewModal.appeal.reason}
            </div>
            <div>
              <label className="text-sm text-gray-600">Admin note (optional)</label>
              <textarea
                className="w-full mt-1 border rounded p-2 text-sm"
                rows={2}
                value={adminNote}
                onChange={(e) => setAdminNote(e.target.value)}
                placeholder="Note for user..."
              />
            </div>
            <div className="flex gap-2">
              <Button
                variant="default"
                size="sm"
                onClick={() => reviewAppeal("APPROVED")}
                disabled={loading}
              >
                <CheckCircle className="w-4 h-4 mr-1" />
                Approve (unban)
              </Button>
              <Button
                variant="destructive"
                size="sm"
                onClick={() => reviewAppeal("REJECTED")}
                disabled={loading}
              >
                <XCircle className="w-4 h-4 mr-1" />
                Reject
              </Button>
              <Button variant="secondary" onClick={() => setReviewModal({ appeal: null, open: false })}>
                Cancel
              </Button>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
