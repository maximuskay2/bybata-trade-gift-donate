"use client";

import useSWR from "swr";
import { useState } from "react";
import { api } from "@/lib/api";
import { Card } from "@/app/components/ui/card";
import { Input } from "@/app/components/ui/input";
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from "@/app/components/ui/select";
import { Button } from "@/app/components/ui/button";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function EmailLogsPage() {
  const [page, setPage] = useState(1);
  const [status, setStatus] = useState<string | "all">("all");
  const [provider, setProvider] = useState<string | "all">("all");
  const [recipient, setRecipient] = useState<string>("");
  const [eventName, setEventName] = useState<string>("");

  const query = new URLSearchParams({ page: String(page), pageSize: "20" });
  if (status && status !== "all") query.set("status", status);
  if (provider && provider !== "all") query.set("provider", provider);
  if (recipient) query.set("recipientEmail", recipient);
  if (eventName) query.set("eventName", eventName);

  const { data, isLoading, mutate } = useSWR(`/v1/admin/email/logs?${query.toString()}`, fetcher);

  const items = data?.items || [];
  const total = data?.total || 0;
  const [selectedBody, setSelectedBody] = useState<string | null>(null);
  const pageSize = data?.pageSize || 20;
  const totalPages = Math.max(Math.ceil(total / pageSize), 1);

  const applyFilters = () => {
    setPage(1);
    mutate();
  };

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-semibold">Email Activity</h1>
      <p className="text-sm text-muted-foreground">
        All outbound emails sent by the platform are recorded here, including provider, status, and errors.
      </p>

      <Card className="p-4 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm mb-1">Status</label>
            <Select value={status} onValueChange={setStatus}>
              <SelectTrigger>
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="QUEUED">Queued</SelectItem>
                <SelectItem value="SENT">Sent</SelectItem>
                <SelectItem value="FAILED">Failed</SelectItem>
                <SelectItem value="SKIPPED">Skipped</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="block text-sm mb-1">Provider</label>
            <Select value={provider} onValueChange={setProvider}>
              <SelectTrigger>
                <SelectValue placeholder="All" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="smtp">SMTP</SelectItem>
                <SelectItem value="resend">Resend</SelectItem>
                <SelectItem value="sendgrid">SendGrid</SelectItem>
                <SelectItem value="console">Console</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="block text-sm mb-1">Recipient</label>
            <Input
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="user@example.com"
            />
          </div>

          <div>
            <label className="block text-sm mb-1">Event</label>
            <Input
              value={eventName}
              onChange={(e) => setEventName(e.target.value)}
              placeholder="auth/email-verify"
            />
          </div>
        </div>

        <div className="flex justify-end">
          <Button size="sm" onClick={applyFilters} disabled={isLoading}>
            Apply Filters
          </Button>
        </div>
      </Card>

      <Card className="p-4 space-y-4">
        <div className="flex items-center justify-between text-sm text-muted-foreground">
          <span>
            Showing {items.length} of {total} emails
          </span>
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={page <= 1 || isLoading}
              onClick={() => setPage((p) => Math.max(p - 1, 1))}
            >
              Previous
            </Button>
            <span>
              Page {page} / {totalPages}
            </span>
            <Button
              size="sm"
              variant="outline"
              disabled={page >= totalPages || isLoading}
              onClick={() => setPage((p) => Math.min(p + 1, totalPages))}
            >
              Next
            </Button>
          </div>
        </div>

        <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white/50 backdrop-blur-sm shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-200 bg-gradient-to-r from-gray-50 to-gray-50 text-left text-xs uppercase text-gray-700 font-semibold">
                <th className="px-6 py-4">Time</th>
                <th className="px-6 py-4">Recipient</th>
                <th className="px-6 py-4">Event</th>
                <th className="px-6 py-4">Provider</th>
                <th className="px-6 py-4">Status</th>
                <th className="px-6 py-4">Error</th>
                <th className="px-6 py-4">Body</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {items.length === 0 && !isLoading && (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-gray-500">
                    <div className="flex flex-col items-center gap-2">
                      <div className="text-4xl opacity-20">📭</div>
                      <p>No emails found for the selected filters.</p>
                    </div>
                  </td>
                </tr>
              )}

              {items.map((item: any) => {
                const createdAt = item.createdAt ? new Date(item.createdAt) : null;
                const timeLabel = createdAt ? createdAt.toLocaleString() : "-";

                const statusColor =
                  item.status === "SENT"
                    ? "text-green-700"
                    : item.status === "FAILED"
                    ? "text-red-700"
                    : item.status === "SKIPPED"
                    ? "text-amber-700"
                    : "text-slate-700";

                return (
                  <tr key={item.id} className="hover:bg-gray-50 transition-all duration-200">
                    <td className="px-6 py-4 whitespace-nowrap text-gray-700">{timeLabel}</td>
                    <td className="px-6 py-4 break-all text-gray-700">{item.recipientEmail}</td>
                    <td className="px-6 py-4 text-gray-700">{item.eventName}</td>
                    <td className="px-6 py-4 uppercase text-xs text-gray-700">{item.provider || "-"}</td>
                    <td className={`px-6 py-4 font-medium ${statusColor}`}>{item.status}</td>
                    <td className="px-6 py-4 max-w-xs truncate text-gray-700" title={item.error || ""}>
                      {item.error || "-"}
                    </td>
                    <td className="px-6 py-4">
                      {item.metadata?.htmlPreview ? (
                        <Button
                          size="xs"
                          variant="outline"
                          onClick={() => setSelectedBody(item.metadata.htmlPreview as string)}
                        >
                          View
                        </Button>
                      ) : (
                        <span className="text-xs text-gray-500">No body</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Card>

      {selectedBody && (
        <Card className="p-4 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="font-medium">Email Body Preview</h2>
            <Button size="sm" variant="outline" onClick={() => setSelectedBody(null)}>
              Close
            </Button>
          </div>
          <div className="border rounded-md max-h-[400px] overflow-auto bg-white">
            <div
              className="p-4 prose max-w-none"
              // HTML here comes from our own backend templates; safe to render for admins.
              dangerouslySetInnerHTML={{ __html: selectedBody }}
            />
          </div>
        </Card>
      )}
    </div>
  );
}
