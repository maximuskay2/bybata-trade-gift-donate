"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowLeft,
  Bell,
  Calendar,
  CheckCircle,
  Copy,
  Eye,
  RefreshCw,
  Send,
  Users,
} from "lucide-react";
import clsx from "clsx";
import PageHeader from "@/app/components/page-header";
import { api } from "@/app/lib/api";

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
  targetCriteria?: Record<string, unknown> | null;
};

export default function BroadcastDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params?.id ?? "";

  const [broadcast, setBroadcast] = useState<Broadcast | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isSending, setIsSending] = useState(false);
  const [isResending, setIsResending] = useState(false);

  useEffect(() => {
    if (!id) return;

    const load = async () => {
      setIsLoading(true);
      setError(null);
      try {
        const res = await api.get(`/v1/notifications/admin/broadcasts/${id}`);
        setBroadcast(res.data as Broadcast);
      } catch (err: unknown) {
        const message =
          (err as { response?: { data?: { message?: string } } })?.response?.data
            ?.message ?? "Failed to load broadcast";
        setError(message);
      } finally {
        setIsLoading(false);
      }
    };

    load();
  }, [id]);

  const handleSend = async () => {
    if (!broadcast || broadcast.status === "SENT" || broadcast.status === "SENDING") {
      return;
    }
    setIsSending(true);
    try {
      await api.post(`/v1/notifications/admin/broadcasts/${id}/send`);
      const res = await api.get(`/v1/notifications/admin/broadcasts/${id}`);
      setBroadcast(res.data as Broadcast);
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? "Failed to send broadcast";
      setError(message);
    } finally {
      setIsSending(false);
    }
  };

  const handleResend = async () => {
    if (!broadcast || broadcast.status === "SENDING") return;
    const confirmed = window.confirm(
      `Resend "${broadcast.title}" to the same audience?\n\nThis creates a new broadcast and delivers it again. The original stays in history.`,
    );
    if (!confirmed) return;

    setIsResending(true);
    setError(null);
    try {
      const res = await api.post(`/v1/notifications/admin/broadcasts/${id}/resend`);
      const delivered = res.data?.deliveredCount ?? res.data?.totalRecipients;
      const newId = res.data?.broadcastId as string | undefined;
      alert(
        typeof delivered === "number"
          ? `Resent to ${delivered.toLocaleString()} users.`
          : "Broadcast resent successfully.",
      );
      if (newId) {
        router.push(`/notifications/${newId}`);
      } else {
        router.push("/notifications");
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { message?: string } } })?.response?.data
          ?.message ?? "Failed to resend broadcast";
      setError(message);
    } finally {
      setIsResending(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case "SENT":
        return "bg-green-100 text-green-800";
      case "SCHEDULED":
        return "bg-blue-100 text-blue-800";
      case "SENDING":
        return "bg-yellow-100 text-yellow-800";
      default:
        return "bg-gray-100 text-gray-800";
    }
  };

  const deliveryRate =
    broadcast?.recipientCount && broadcast.recipientCount > 0
      ? Math.round((broadcast.deliveredCount / broadcast.recipientCount) * 100)
      : 0;

  const readRate =
    broadcast?.deliveredCount && broadcast.deliveredCount > 0
      ? Math.round((broadcast.readCount / broadcast.deliveredCount) * 100)
      : 0;

  return (
    <div className="space-y-6">
      <PageHeader
        title={broadcast?.title ?? "Broadcast details"}
        description="View broadcast content, status, and delivery metrics"
        breadcrumb={[
          { label: "Notifications", href: "/notifications" },
          { label: broadcast?.title ?? "Details" },
        ]}
        actions={
          <div className="flex flex-wrap items-center gap-3">
            {broadcast && broadcast.status !== "SENDING" && (
              <>
                <Link
                  href={`/notifications/new?from=${id}`}
                  className="inline-flex items-center gap-2 border border-gray-300 text-gray-800 px-4 py-2 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <Copy size={16} />
                  Reuse
                </Link>
                <button
                  type="button"
                  onClick={handleResend}
                  disabled={isResending}
                  className="inline-flex items-center gap-2 bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-60"
                >
                  <RefreshCw size={16} className={isResending ? "animate-spin" : ""} />
                  {isResending ? "Resending…" : "Resend"}
                </button>
              </>
            )}
            {broadcast?.status === "SENT" && (
              <Link
                href={`/notifications/${id}/logs`}
                className="inline-flex items-center gap-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
              >
                <Eye size={16} />
                View delivery logs
              </Link>
            )}
            {broadcast &&
              (broadcast.status === "DRAFT" || broadcast.status === "SCHEDULED") && (
                <button
                  type="button"
                  onClick={handleSend}
                  disabled={isSending}
                  className="inline-flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-60"
                >
                  <Send size={16} />
                  {isSending ? "Sending…" : "Send now"}
                </button>
              )}
            <Link
              href="/notifications"
              className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors"
            >
              <ArrowLeft size={16} />
              Back
            </Link>
          </div>
        }
      />

      {isLoading ? (
        <p className="text-sm text-gray-500">Loading broadcast…</p>
      ) : error ? (
        <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-700">
          {error}
          <button
            type="button"
            onClick={() => router.push("/notifications")}
            className="ml-4 underline"
          >
            Return to list
          </button>
        </div>
      ) : broadcast ? (
        <>
          <div className="bg-white border rounded-xl p-6 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <Bell className="w-6 h-6 text-blue-600" />
              </div>
              <div>
                <h2 className="text-xl font-semibold">{broadcast.title}</h2>
                <span
                  className={clsx(
                    "inline-block mt-1 px-2 py-1 rounded-full text-xs font-medium",
                    getStatusColor(broadcast.status),
                  )}
                >
                  {broadcast.status}
                </span>
              </div>
            </div>
            <p className="text-gray-700 whitespace-pre-wrap">{broadcast.message}</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm text-gray-600">
              <div>
                <span className="font-medium text-gray-800">Created</span>
                <br />
                {new Date(broadcast.createdAt).toLocaleString()}
              </div>
              {broadcast.scheduledAt && (
                <div>
                  <span className="font-medium text-gray-800">Scheduled for</span>
                  <br />
                  {new Date(broadcast.scheduledAt).toLocaleString()}
                </div>
              )}
              {broadcast.sentAt && (
                <div>
                  <span className="font-medium text-gray-800">Sent at</span>
                  <br />
                  {new Date(broadcast.sentAt).toLocaleString()}
                </div>
              )}
            </div>
          </div>

          {broadcast.status === "SENT" && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-white p-6 rounded-xl border">
                <div className="flex items-center gap-3">
                  <Users className="w-6 h-6 text-blue-600" />
                  <div>
                    <p className="text-sm text-gray-600">Recipients</p>
                    <p className="text-2xl font-semibold">
                      {broadcast.recipientCount.toLocaleString()}
                    </p>
                  </div>
                </div>
              </div>
              <div className="bg-white p-6 rounded-xl border">
                <div className="flex items-center gap-3">
                  <CheckCircle className="w-6 h-6 text-green-600" />
                  <div>
                    <p className="text-sm text-gray-600">Delivered</p>
                    <p className="text-2xl font-semibold">
                      {broadcast.deliveredCount.toLocaleString()}
                    </p>
                    <p className="text-xs text-gray-500">{deliveryRate}% rate</p>
                  </div>
                </div>
              </div>
              <div className="bg-white p-6 rounded-xl border">
                <div className="flex items-center gap-3">
                  <Calendar className="w-6 h-6 text-purple-600" />
                  <div>
                    <p className="text-sm text-gray-600">Read</p>
                    <p className="text-2xl font-semibold">
                      {broadcast.readCount.toLocaleString()}
                    </p>
                    <p className="text-xs text-gray-500">{readRate}% rate</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </>
      ) : null}
    </div>
  );
}
