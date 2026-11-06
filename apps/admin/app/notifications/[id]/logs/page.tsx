"use client";

import { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import { ArrowLeft, Download, Search, CheckCircle, Clock, Mail, User, Calendar, Filter } from "lucide-react";
import PageHeader from "@/app/components/page-header";
import Link from "next/link";
import clsx from "clsx";
import { api } from "@/app/lib/api";

interface DeliveryLog {
  id: string;
  userId: string;
  userEmail: string;
  userDisplayName: string;
  delivered: boolean;
  deliveredAt: string;
  read: boolean;
  readAt?: string;
}

interface Broadcast {
  id: string;
  title: string;
  message: string;
  status: string;
  recipientCount: number;
  deliveredCount: number;
  readCount: number;
  sentAt?: string | null;
}

export default function DeliveryLogsPage() {
  const params = useParams<{ id: string }>();
  const id = params?.id ?? "";

  const [broadcast, setBroadcast] = useState<Broadcast | null>(null);
  const [logs, setLogs] = useState<DeliveryLog[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "delivered" | "read" | "unread">("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const logsPerPage = 20;

  useEffect(() => {
    if (!id) return;

    const load = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const [broadcastRes, logsRes] = await Promise.all([
          api.get(`/v1/notifications/admin/broadcasts/${id}`),
          api.get(`/v1/notifications/admin/broadcasts/${id}/logs`, {
            params: { page: 1, size: 200 },
          }),
        ]);
        setBroadcast(broadcastRes.data ?? null);
        setLogs((logsRes.data?.items ?? []) as DeliveryLog[]);
      } catch (err: unknown) {
        const message =
          (err as { response?: { data?: { message?: string } } })?.response?.data
            ?.message ?? "Failed to load delivery logs";
        setError(message);
      } finally {
        setIsLoading(false);
      }
    };

    load();
  }, [id]);

  const filteredLogs = logs.filter(log => {
    const matchesSearch = 
      log.userEmail.toLowerCase().includes(searchQuery.toLowerCase()) ||
      log.userDisplayName.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesStatus = 
      statusFilter === "all" ||
      (statusFilter === "delivered" && log.delivered) ||
      (statusFilter === "read" && log.read) ||
      (statusFilter === "unread" && !log.read);
    
    return matchesSearch && matchesStatus;
  });

  const paginatedLogs = filteredLogs.slice(
    (currentPage - 1) * logsPerPage,
    currentPage * logsPerPage
  );

  const totalPages = Math.ceil(filteredLogs.length / logsPerPage);

  const getDeliveryRate = () => {
    if (!broadcast?.recipientCount) return 0;
    return Math.round((broadcast.deliveredCount / broadcast.recipientCount) * 100);
  };

  const getReadRate = () => {
    if (!broadcast?.deliveredCount) return 0;
    return Math.round((broadcast.readCount / broadcast.deliveredCount) * 100);
  };

  const handleExport = () => {
    // Mock export functionality
    const csvContent = [
      ["Email", "Display Name", "Delivered", "Delivered At", "Read", "Read At"],
      ...filteredLogs.map(log => [
        log.userEmail,
        log.userDisplayName,
        log.delivered ? "Yes" : "No",
        log.delivered ? new Date(log.deliveredAt).toLocaleString() : "",
        log.read ? "Yes" : "No",
        log.readAt ? new Date(log.readAt).toLocaleString() : "",
      ])
    ].map(row => row.join(",")).join("\n");

    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `broadcast_${id}_delivery_logs.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Delivery Logs"
        description={`Delivery details for "${broadcast?.title ?? "Broadcast"}"`}
        breadcrumb={[
          { label: "Notifications", href: "/notifications" },
          { label: broadcast?.title ?? "Broadcast", href: `/notifications/${id}` },
          { label: "Logs" },
        ]}
        actions={
          <div className="flex items-center gap-3">
            <button
              onClick={handleExport}
              className="inline-flex items-center gap-2 border border-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-50 transition-colors"
            >
              <Download size={16} />
              Export CSV
            </button>
            <Link
              href="/notifications"
              className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors"
            >
              <ArrowLeft size={16} />
              Back to Notifications
            </Link>
          </div>
        }
      />

      {/* Summary Stats */}
      {error ? (
        <div className="text-sm text-red-600">{error}</div>
      ) : null}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <User className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Total Recipients</p>
              <p className="text-2xl font-semibold">{(broadcast?.recipientCount ?? 0).toLocaleString()}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <CheckCircle className="w-6 h-6 text-green-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Delivered</p>
              <p className="text-2xl font-semibold">{(broadcast?.deliveredCount ?? 0).toLocaleString()}</p>
              <p className="text-xs text-gray-500">{getDeliveryRate()}% delivery rate</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <Mail className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Read</p>
              <p className="text-2xl font-semibold">{(broadcast?.readCount ?? 0).toLocaleString()}</p>
              <p className="text-xs text-gray-500">{getReadRate()}% read rate</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
              <Calendar className="w-6 h-6 text-orange-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Sent At</p>
              <p className="text-lg font-semibold">
                {broadcast?.sentAt ? new Date(broadcast.sentAt).toLocaleDateString() : "-"}
              </p>
              <p className="text-xs text-gray-500">
                {broadcast?.sentAt ? new Date(broadcast.sentAt).toLocaleTimeString() : "-"}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="bg-white border rounded-xl p-6">
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
          <div className="flex items-center gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
              <input
                type="text"
                placeholder="Search by email or name..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <Filter size={16} className="text-gray-400" />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as any)}
                className="border rounded-lg px-3 py-2 text-sm"
              >
                <option value="all">All Status</option>
                <option value="delivered">Delivered</option>
                <option value="read">Read</option>
                <option value="unread">Unread</option>
              </select>
            </div>
          </div>

          <div className="text-sm text-gray-600">
            Showing {paginatedLogs.length} of {filteredLogs.length} records
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="text-sm text-gray-500 py-8 text-center">Loading delivery logs...</div>
      ) : (
        <div className="rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-gray-700 font-semibold">
                <th className="p-4">User</th>
                <th className="p-4">Delivered</th>
                <th className="p-4">Read</th>
                <th className="p-4">Delivered At</th>
                <th className="p-4">Read At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {paginatedLogs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-gray-500">
                    <div className="flex flex-col items-center gap-2">
                      <div className="text-4xl opacity-20">📭</div>
                      <p>No delivery logs found.</p>
                    </div>
                  </td>
                </tr>
              ) : (
                paginatedLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-gray-50 transition-all duration-200">
                    <td className="p-4">
                      <div className="font-medium text-gray-900">{log.userDisplayName || "Unknown"}</div>
                      <div className="text-xs text-gray-500">{log.userEmail}</div>
                    </td>
                    <td className="p-4">
                      <span className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${log.delivered ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                        {log.delivered ? "✓ Yes" : "✗ No"}
                      </span>
                    </td>
                    <td className="p-4">
                      <span className={`inline-block px-2 py-1 rounded-full text-xs font-semibold ${log.read ? 'bg-blue-100 text-blue-800' : 'bg-gray-100 text-gray-800'}`}>
                        {log.read ? "✓ Yes" : "✗ No"}
                      </span>
                    </td>
                    <td className="p-4 text-gray-700">
                      {new Date(log.deliveredAt).toLocaleString()}
                    </td>
                    <td className="p-4 text-gray-700">
                      {log.readAt ? new Date(log.readAt).toLocaleString() : "-"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}

    </div>
  );
}