"use client";
import React, { useEffect, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import AdminGuard from "@/app/components/admin-guard";

export default function AdsReviewPage() {
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function fetchPending() {
    try {
      setError(null);
      const res = await api.get("/v1/admin/ads/schedules", { params: { status: "PENDING_REVIEW" } });
      setItems(res.data || []);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    }
  }

  async function review(id: string, decision: "approve" | "reject") {
    try {
      setLoading(true);
      await api.patch(`/v1/admin/ads/schedules/${id}/review`, { decision });
      await fetchPending();
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { fetchPending(); }, []);

  return (
    <AdminGuard>
      <main style={{ padding: 24 }}>
        <h1 className="text-xl font-semibold">Ads Review</h1>
        <p className="text-sm text-gray-500">Ads stay hidden until approved.</p>
        {error && <p className="text-red-600 mt-2">{error}</p>}
        <div className="mt-6 rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-gray-700 font-semibold">
                <th className="px-6 py-4">Title</th>
                <th className="px-6 py-4">Media</th>
                <th className="px-6 py-4">User</th>
                <th className="px-6 py-4">Placement</th>
                <th className="px-6 py-4">Start</th>
                <th className="px-6 py-4">End</th>
                <th className="px-6 py-4">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {items.map((ad) => (
                <tr key={ad.id} className="hover:bg-gray-50 transition-all duration-200">
                  <td className="px-6 py-4 text-gray-900">{ad.title}</td>
                  <td className="px-6 py-4 text-gray-700">
                    {ad.mediaType === "VIDEO"
                      ? "Video"
                      : `${(ad.mediaKeys?.length ?? 0)} image(s)`}
                  </td>
                  <td className="px-6 py-4 text-gray-700">{ad.user?.email || ad.userId}</td>
                  <td className="px-6 py-4 text-gray-700">
                    {Array.isArray(ad.placementKeys) && ad.placementKeys.length > 0
                      ? ad.placementKeys.join(", ")
                      : ad.placementKey || "N/A"}
                  </td>
                  <td className="px-6 py-4 text-gray-700">{new Date(ad.scheduledStart).toLocaleString()}</td>
                  <td className="px-6 py-4 text-gray-700">{ad.scheduledEnd ? new Date(ad.scheduledEnd).toLocaleString() : "N/A"}</td>
                  <td className="px-6 py-4 flex flex-wrap gap-2 items-center">
                    <Link
                      href={`/ads/${ad.id}/edit`}
                      className="text-indigo-600 hover:text-indigo-800 hover:bg-indigo-50 px-3 py-1 rounded-lg transition-colors text-sm font-medium"
                    >
                      Edit
                    </Link>
                    <button disabled={loading} onClick={() => review(ad.id, "approve")} className="text-green-600 hover:text-green-700 hover:bg-green-50 px-3 py-1 rounded-lg transition-colors">Approve</button>
                    <button disabled={loading} onClick={() => review(ad.id, "reject")} className="text-red-600 hover:text-red-700 hover:bg-red-50 px-3 py-1 rounded-lg transition-colors">Reject</button>
                  </td>
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-gray-500">
                    <div className="flex flex-col items-center gap-2">
                      <div className="text-4xl opacity-20">📭</div>
                      <p>No pending ads.</p>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </main>
    </AdminGuard>
  );
}
