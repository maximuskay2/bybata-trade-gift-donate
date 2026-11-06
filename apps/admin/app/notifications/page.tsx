"use client";

import { useEffect, useState } from "react";
import { Bell, Plus, Send, Eye, BarChart3, Users, Calendar, Filter } from "lucide-react";
import PageHeader from "@/app/components/page-header";
import Link from "next/link";
import clsx from "clsx";
import { api } from "@/app/lib/api";

type Tab = "broadcasts" | "analytics" | "templates";

type Broadcast = {
  id: string;
  title: string;
  message: string;
  status: "DRAFT" | "SCHEDULED" | "SENDING" | "SENT";
  recipientCount: number;
  deliveredCount: number;
  readCount: number;
  createdAt: string;
  scheduledAt?: string | null;
  sentAt?: string | null;
};

type Analytics = {
  totalSent: number;
  totalRead: number;
  readRate: number;
  totalBroadcasts: number;
  activeBroadcasts: number;
  weeklyGrowth: number;
};

export default function NotificationsPage() {
  const [activeTab, setActiveTab] = useState<Tab>("broadcasts");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [broadcasts, setBroadcasts] = useState<Broadcast[]>([]);
  const [analytics, setAnalytics] = useState<Analytics>({
    totalSent: 0,
    totalRead: 0,
    readRate: 0,
    totalBroadcasts: 0,
    activeBroadcasts: 0,
    weeklyGrowth: 0,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const [broadcastRes, analyticsRes] = await Promise.all([
          api.get("/v1/notifications/admin/broadcasts", {
            params: {
              page: 1,
              size: 50,
              ...(statusFilter !== "all" ? { status: statusFilter.toUpperCase() } : {}),
            },
          }),
          api.get("/v1/notifications/admin/notification-analytics", {
            params: { period: "7d" },
          }),
        ]);

        const items = (broadcastRes.data?.items ?? []) as Broadcast[];
        const analyticsData = analyticsRes.data;

        setBroadcasts(items);
        setAnalytics({
          totalSent: analyticsData?.notifications?.total ?? 0,
          totalRead: analyticsData?.notifications?.read ?? 0,
          readRate: analyticsData?.notifications?.readRate ?? 0,
          totalBroadcasts: analyticsData?.broadcasts?.total ?? 0,
          activeBroadcasts:
            (analyticsData?.broadcasts?.total ?? 0) -
            (analyticsData?.broadcasts?.sent ?? 0),
          weeklyGrowth: 0,
        });
      } catch (err: any) {
        setError(err?.response?.data?.message || "Failed to load notifications");
      } finally {
        setIsLoading(false);
      }
    };

    load();
  }, [statusFilter]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notifications"
        description="Manage broadcast notifications and delivery analytics"
        actions={
          <Link
            href="/notifications/new"
            className="inline-flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus size={16} />
            New Broadcast
          </Link>
        }
      />

      {/* Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <Send className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Total Sent</p>
              <p className="text-2xl font-semibold">{analytics.totalSent.toLocaleString()}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <Eye className="w-6 h-6 text-green-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Total Read</p>
              <p className="text-2xl font-semibold">{analytics.totalRead.toLocaleString()}</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <BarChart3 className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Read Rate</p>
              <p className="text-2xl font-semibold">{analytics.readRate}%</p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
              <Users className="w-6 h-6 text-orange-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Active Broadcasts</p>
              <p className="text-2xl font-semibold">{analytics.activeBroadcasts}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white border rounded-xl">
        <div className="border-b">
          <nav className="flex gap-8 px-6">
            {[
              { key: "broadcasts" as Tab, label: "Broadcasts", icon: Bell },
              { key: "analytics" as Tab, label: "Analytics", icon: BarChart3 },
              { key: "templates" as Tab, label: "Templates", icon: Calendar },
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={clsx(
                  "flex items-center gap-2 py-4 px-1 border-b-2 text-sm font-medium transition-colors",
                  activeTab === tab.key
                    ? "border-blue-500 text-blue-600"
                    : "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                )}
              >
                <tab.icon size={16} />
                {tab.label}
              </button>
            ))}
          </nav>
        </div>

        <div className="p-6">
          {activeTab === "broadcasts" && (
            <div className="space-y-6">
              {/* Filters */}
              <div className="flex items-center gap-4">
                <div className="flex items-center gap-2">
                  <Filter size={16} className="text-gray-400" />
                  <select
                    value={statusFilter}
                    onChange={(e) => setStatusFilter(e.target.value)}
                    className="border rounded-lg px-3 py-1 text-sm"
                  >
                    <option value="all">All Status</option>
                    <option value="draft">Draft</option>
                    <option value="scheduled">Scheduled</option>
                    <option value="sending">Sending</option>
                    <option value="sent">Sent</option>
                  </select>
                </div>
              </div>

              {/* Broadcasts List */}
              <div className="space-y-4">
                {isLoading ? (
                  <div className="text-sm text-gray-500">Loading broadcasts...</div>
                ) : error ? (
                  <div className="text-sm text-red-600">{error}</div>
                ) : broadcasts.length === 0 ? (
                  <div className="text-sm text-gray-500">No broadcasts found.</div>
                ) : (
                  broadcasts.map((broadcast) => (
                    <BroadcastCard key={broadcast.id} broadcast={broadcast} />
                  ))
                )}
              </div>
            </div>
          )}

          {activeTab === "analytics" && (
            <div className="space-y-6">
              {isLoading ? (
                <div className="text-sm text-gray-500">Loading analytics...</div>
              ) : error ? (
                <div className="text-sm text-red-600">{error}</div>
              ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  <div className="bg-white border rounded-xl p-6">
                    <p className="text-sm text-gray-600">Total Broadcasts</p>
                    <p className="text-2xl font-semibold">{analytics.totalBroadcasts}</p>
                  </div>
                  <div className="bg-white border rounded-xl p-6">
                    <p className="text-sm text-gray-600">Active Broadcasts</p>
                    <p className="text-2xl font-semibold">{analytics.activeBroadcasts}</p>
                  </div>
                  <div className="bg-white border rounded-xl p-6">
                    <p className="text-sm text-gray-600">Read Rate</p>
                    <p className="text-2xl font-semibold">{analytics.readRate}%</p>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === "templates" && (
            <div className="space-y-6">
              <div className="text-center py-12">
                <Calendar className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                <h3 className="text-lg font-semibold mb-2">Notification Templates</h3>
                <p className="text-gray-600">
                  Template management will be implemented here
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function BroadcastCard({ broadcast }: { broadcast: Broadcast }) {
  const [isResending, setIsResending] = useState(false);

  const getStatusColor = (status: string) => {
    switch (status) {
      case "SENT": return "bg-green-100 text-green-800";
      case "SCHEDULED": return "bg-blue-100 text-blue-800";
      case "SENDING": return "bg-yellow-100 text-yellow-800";
      case "DRAFT": return "bg-gray-100 text-gray-800";
      default: return "bg-gray-100 text-gray-800";
    }
  };

  const getDeliveryRate = () => {
    if (!broadcast.recipientCount) return 0;
    return Math.round((broadcast.deliveredCount / broadcast.recipientCount) * 100);
  };

  const getReadRate = () => {
    if (!broadcast.deliveredCount) return 0;
    return Math.round((broadcast.readCount / broadcast.deliveredCount) * 100);
  };

  const handleResend = async () => {
    if (broadcast.status === "SENDING" || isResending) return;
    const confirmed = window.confirm(
      `Resend "${broadcast.title}" now?\n\nCreates a new broadcast with the same content and audience.`,
    );
    if (!confirmed) return;
    setIsResending(true);
    try {
      const res = await api.post(`/v1/notifications/admin/broadcasts/${broadcast.id}/resend`);
      const delivered = res.data?.deliveredCount ?? res.data?.totalRecipients;
      alert(
        typeof delivered === "number"
          ? `Resent to ${delivered.toLocaleString()} users.`
          : "Broadcast resent successfully.",
      );
      window.location.reload();
    } catch {
      alert("Failed to resend broadcast. Please try again.");
    } finally {
      setIsResending(false);
    }
  };

  return (
    <div className="border rounded-lg p-6 hover:bg-gray-50 transition-colors">
      <div className="flex items-start justify-between mb-4 gap-4">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3 mb-2 flex-wrap">
            <h3 className="font-semibold text-lg">{broadcast.title}</h3>
            <span className={clsx("px-2 py-1 rounded-full text-xs font-medium", getStatusColor(broadcast.status))}>
              {broadcast.status}
            </span>
          </div>
          <p className="text-gray-600 mb-3 line-clamp-2">{broadcast.message}</p>
          
          {broadcast.status === "SENT" && (
            <div className="grid grid-cols-3 gap-6">
              <div>
                <p className="text-sm text-gray-500">Recipients</p>
                <p className="font-semibold">{broadcast.recipientCount?.toLocaleString()}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Delivery Rate</p>
                <p className="font-semibold">{getDeliveryRate()}%</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Read Rate</p>
                <p className="font-semibold">{getReadRate()}%</p>
              </div>
            </div>
          )}

          {broadcast.status === "SCHEDULED" && broadcast.scheduledAt && (
            <div>
              <p className="text-sm text-gray-500">Scheduled for</p>
              <p className="font-medium">
                {new Date(broadcast.scheduledAt).toLocaleDateString()} at{" "}
                {new Date(broadcast.scheduledAt).toLocaleTimeString()}
              </p>
            </div>
          )}
        </div>

        <div className="flex flex-col items-end gap-2 shrink-0">
          <Link
            href={`/notifications/${broadcast.id}`}
            className="text-blue-600 hover:text-blue-800 transition-colors text-sm"
          >
            View Details
          </Link>
          {broadcast.status !== "SENDING" && (
            <>
              <Link
                href={`/notifications/new?from=${broadcast.id}`}
                className="text-gray-700 hover:text-gray-900 transition-colors text-sm"
              >
                Reuse
              </Link>
              <button
                type="button"
                onClick={handleResend}
                disabled={isResending}
                className="text-indigo-600 hover:text-indigo-800 transition-colors text-sm disabled:opacity-50"
              >
                {isResending ? "Resending…" : "Resend"}
              </button>
            </>
          )}
          {broadcast.status === "SENT" && (
            <Link
              href={`/notifications/${broadcast.id}/logs`}
              className="text-green-600 hover:text-green-800 transition-colors text-sm"
            >
              View Logs
            </Link>
          )}
        </div>
      </div>

      <div className="text-xs text-gray-500">
        Created {new Date(broadcast.createdAt || "").toLocaleDateString()}
      </div>
    </div>
  );
}