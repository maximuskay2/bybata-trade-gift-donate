"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowLeft, Send, Save, Clock, Users, Target } from "lucide-react";
import PageHeader from "@/app/components/page-header";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { api } from "@/app/lib/api";

interface TargetCriteria {
  role?: string;
  verified?: boolean;
  location?: string;
  joinedAfter?: string;
  hasCompletedTrades?: boolean;
}

export default function NewBroadcastPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const reuseFromId = searchParams.get("from");

  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [scheduled, setScheduled] = useState(false);
  const [scheduledDate, setScheduledDate] = useState("");
  const [scheduledTime, setScheduledTime] = useState("");
  const [targetCriteria, setTargetCriteria] = useState<TargetCriteria>({});
  const [estimatedRecipients, setEstimatedRecipients] = useState<number | null>(null);
  const [estimateLoading, setEstimateLoading] = useState(true);
  const [estimateError, setEstimateError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [reuseBanner, setReuseBanner] = useState<string | null>(null);
  const estimateRequestId = useRef(0);
  const reuseLoaded = useRef(false);

  useEffect(() => {
    if (!reuseFromId || reuseLoaded.current) return;
    reuseLoaded.current = true;

    const load = async () => {
      try {
        const res = await api.get(`/v1/notifications/admin/broadcasts/${reuseFromId}`);
        const data = res.data as {
          title?: string;
          message?: string;
          targetCriteria?: TargetCriteria | null;
        };
        setTitle(data.title ?? "");
        setMessage(data.message ?? "");
        const criteria =
          data.targetCriteria && typeof data.targetCriteria === "object"
            ? (data.targetCriteria as TargetCriteria)
            : {};
        setTargetCriteria(criteria);
        setReuseBanner("Reusing broadcast — edit and send when ready.");
      } catch {
        setReuseBanner("Could not load the original broadcast to reuse.");
      }
    };

    void load();
  }, [reuseFromId]);

  const refreshAudienceEstimate = useCallback(async (criteria: TargetCriteria) => {
    const requestId = ++estimateRequestId.current;
    setEstimateLoading(true);
    setEstimateError(null);
    try {
      const res = await api.post("/v1/notifications/admin/broadcasts/preview-audience", {
        targetCriteria: criteria,
      });
      if (requestId !== estimateRequestId.current) return;
      const count = Number(res.data?.count);
      setEstimatedRecipients(Number.isFinite(count) ? count : 0);
    } catch {
      if (requestId !== estimateRequestId.current) return;
      setEstimatedRecipients(null);
      setEstimateError("Could not load recipient count");
    } finally {
      if (requestId === estimateRequestId.current) {
        setEstimateLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      void refreshAudienceEstimate(targetCriteria);
    }, 250);
    return () => clearTimeout(timer);
  }, [targetCriteria, refreshAudienceEstimate]);

  const handleSubmit = async (action: "save" | "send") => {
    if (!title.trim() || !message.trim()) {
      alert("Please fill in all required fields");
      return;
    }

    if (scheduled && action === "send" && (!scheduledDate || !scheduledTime)) {
      alert("Please choose a date and time to schedule this broadcast");
      return;
    }

    setIsLoading(true);
    try {
      const scheduledAt =
        scheduled && scheduledDate && scheduledTime
          ? new Date(`${scheduledDate}T${scheduledTime}:00`).toISOString()
          : undefined;

      const createRes = await api.post("/v1/notifications/admin/broadcasts", {
        title: title.trim(),
        message: message.trim(),
        targetCriteria,
        scheduledAt,
      });

      const broadcastId = createRes.data?.id;

      // Schedule for later: do not send immediately.
      if (scheduled && action === "send" && broadcastId) {
        await api.put(`/v1/notifications/admin/broadcasts/${broadcastId}`, {
          status: "SCHEDULED",
          scheduledAt,
        });
        alert("Broadcast scheduled successfully!");
        router.push("/notifications");
        return;
      }

      if (action === "send" && broadcastId) {
        const sendRes = await api.post(
          `/v1/notifications/admin/broadcasts/${broadcastId}/send`,
        );
        const delivered = sendRes.data?.deliveredCount ?? sendRes.data?.totalRecipients;
        const pushOk = sendRes.data?.pushSuccess;
        const pushFail = sendRes.data?.pushFailed;
        const warning = sendRes.data?.warning;
        if (warning) {
          alert(String(warning));
        } else if (typeof delivered === "number") {
          let msg = `Broadcast delivered in-app to ${delivered.toLocaleString()} users.`;
          if (typeof pushOk === "number") {
            msg += ` Push alerts: ${pushOk.toLocaleString()} sent`;
            if (typeof pushFail === "number" && pushFail > 0) {
              msg += `, ${pushFail.toLocaleString()} skipped (no device token / Firebase).`;
            } else {
              msg += ".";
            }
          }
          alert(msg);
        } else {
          alert("Broadcast sent successfully!");
        }
      } else {
        alert("Broadcast saved as draft!");
      }

      router.push("/notifications");
    } catch {
      alert("Error creating broadcast. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  const updateTargetCriteria = (key: keyof TargetCriteria, value: any) => {
    setTargetCriteria((prev) => {
      const next = { ...prev, [key]: value };
      if (value === undefined || value === null || value === "" || value === false) {
        delete next[key];
      }
      return next;
    });
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title={reuseFromId ? "Reuse Broadcast" : "New Broadcast Notification"}
        description={
          reuseFromId
            ? "Edit the copied notification, then save or send"
            : "Create and send notifications to users"
        }
        icon={Send}
        actions={
          <Link
            href="/notifications"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors"
          >
            <ArrowLeft size={16} />
            Back to Notifications
          </Link>
        }
      />

      {reuseBanner && (
        <div className="rounded-lg border border-indigo-200 bg-indigo-50 px-4 py-3 text-sm text-indigo-900">
          {reuseBanner}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Form */}
        <div className="lg:col-span-2 space-y-6">
          {/* Message Content */}
          <div className="bg-white border rounded-xl p-6">
            <h2 className="text-lg font-semibold mb-4">Message Content</h2>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">
                  Title <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Enter notification title..."
                  className="w-full border rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  maxLength={100}
                />
                <div className="text-xs text-gray-500 mt-1">{title.length}/100 characters</div>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">
                  Message <span className="text-red-500">*</span>
                </label>
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Enter your message..."
                  rows={6}
                  className="w-full border rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                  maxLength={500}
                />
                <div className="text-xs text-gray-500 mt-1">{message.length}/500 characters</div>
              </div>
            </div>
          </div>

          {/* Scheduling */}
          <div className="bg-white border rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <Clock className="w-5 h-5 text-blue-600" />
              <h2 className="text-lg font-semibold">Scheduling</h2>
            </div>

            <div className="space-y-4">
              <label className="flex items-center gap-3">
                <input
                  type="radio"
                  name="scheduling"
                  checked={!scheduled}
                  onChange={() => setScheduled(false)}
                  className="text-blue-600 focus:ring-blue-500"
                />
                <span>Send immediately</span>
              </label>

              <label className="flex items-center gap-3">
                <input
                  type="radio"
                  name="scheduling"
                  checked={scheduled}
                  onChange={() => setScheduled(true)}
                  className="text-blue-600 focus:ring-blue-500"
                />
                <span>Schedule for later</span>
              </label>

              {scheduled && (
                <div className="ml-6 grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Date</label>
                    <input
                      type="date"
                      value={scheduledDate}
                      onChange={(e) => setScheduledDate(e.target.value)}
                      className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      min={new Date().toISOString().split("T")[0]}
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium mb-2">Time</label>
                    <input
                      type="time"
                      value={scheduledTime}
                      onChange={(e) => setScheduledTime(e.target.value)}
                      className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Target Audience */}
          <div className="bg-white border rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <Target className="w-5 h-5 text-purple-600" />
              <h2 className="text-lg font-semibold">Target Audience</h2>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">User Role</label>
                <select
                  value={targetCriteria.role || ""}
                  onChange={(e) => updateTargetCriteria("role", e.target.value || undefined)}
                  className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="">All users</option>
                  <option value="USER">Regular users</option>
                  <option value="MODERATOR">Moderators</option>
                </select>
                <p className="text-xs text-gray-500 mt-1">
                  “All users” means active app members (USER role), not admin accounts.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <label className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    checked={targetCriteria.verified || false}
                    onChange={(e) =>
                      updateTargetCriteria("verified", e.target.checked || undefined)
                    }
                    className="text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-sm">Verified users only</span>
                </label>

                <label className="flex items-center gap-3">
                  <input
                    type="checkbox"
                    checked={targetCriteria.hasCompletedTrades || false}
                    onChange={(e) =>
                      updateTargetCriteria(
                        "hasCompletedTrades",
                        e.target.checked || undefined,
                      )
                    }
                    className="text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-sm">Has completed trades</span>
                </label>
              </div>

              <div>
                <label className="block text-sm font-medium mb-2">Joined after</label>
                <input
                  type="date"
                  value={targetCriteria.joinedAfter || ""}
                  onChange={(e) =>
                    updateTargetCriteria("joinedAfter", e.target.value || undefined)
                  }
                  className="w-full border rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Preview */}
          <div className="bg-white border rounded-xl p-6">
            <h3 className="font-semibold mb-4">Preview</h3>
            <div className="bg-gray-50 rounded-lg p-4 space-y-2">
              <div className="font-medium text-gray-900">
                {title || "Notification title..."}
              </div>
              <div className="text-gray-600 text-sm">
                {message || "Your message will appear here..."}
              </div>
            </div>
          </div>

          {/* Estimated Reach */}
          <div className="bg-white border rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <Users className="w-5 h-5 text-green-600" />
              <h3 className="font-semibold">Estimated Reach</h3>
            </div>
            <div className="text-center">
              <div className="text-3xl font-bold text-green-600 mb-2">
                {estimateLoading
                  ? "…"
                  : estimatedRecipients !== null
                    ? estimatedRecipients.toLocaleString()
                    : "—"}
              </div>
              <div className="text-sm text-gray-600">
                {estimateError
                  ? estimateError
                  : "users will receive this notification"}
              </div>
            </div>
          </div>

          {/* Actions */}
          <div className="bg-white border rounded-xl p-6 space-y-3">
            <button
              onClick={() => handleSubmit("send")}
              disabled={isLoading || !title.trim() || !message.trim()}
              className="w-full bg-blue-600 text-white px-4 py-3 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
            >
              <Send size={16} />
              {scheduled ? "Schedule Broadcast" : "Send Now"}
            </button>

            <button
              onClick={() => handleSubmit("save")}
              disabled={isLoading || !title.trim() || !message.trim()}
              className="w-full border border-gray-300 text-gray-700 px-4 py-3 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
            >
              <Save size={16} />
              Save as Draft
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
