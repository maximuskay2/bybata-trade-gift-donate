"use client";

import { useState } from "react";
import useSWR from "swr";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import { Card } from "@/app/components/ui/card";
import { Button } from "@/app/components/ui/button";
import { Select, SelectTrigger, SelectContent, SelectItem, SelectValue } from "@/app/components/ui/select";
import { useToast } from "@/app/components/ui/use-toast";
import { Badge } from "@/app/components/ui/badge";
import { Textarea } from "@/app/components/ui/textarea";

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function SupportPage() {
  const [tab, setTab] = useState<"tickets" | "bugs" | "chat">("tickets");
  const [statusFilter, setStatusFilter] = useState("");
  const [selectedTicket, setSelectedTicket] = useState<any>(null);
  const [selectedChat, setSelectedChat] = useState<any>(null);
  const [reply, setReply] = useState("");
  const [chatReply, setChatReply] = useState("");
  const [loading, setLoading] = useState(false);
  const { toast } = useToast();

  const ticketsUrl =
    tab === "bugs"
      ? `/v1/admin/support/bug-reports?${statusFilter ? `status=${statusFilter}` : ""}`
      : `/v1/admin/support/tickets?${statusFilter ? `status=${statusFilter}` : ""}`;

  const { data: ticketsData, mutate: mutateTickets } = useSWR(
    tab === "chat" ? null : ticketsUrl,
    fetcher,
  );
  const { data: chatData, mutate: mutateChat } = useSWR(
    tab === "chat" ? "/v1/admin/support/chat/sessions" : null,
    fetcher,
  );

  const tickets = ticketsData?.items ?? [];
  const chats = chatData?.items ?? [];

  const loadTicket = async (id: string) => {
    const res = await api.get(`/v1/admin/support/tickets/${id}`);
    setSelectedTicket(res.data);
  };

  const loadChat = async (id: string) => {
    const res = await api.get(`/v1/admin/support/chat/sessions/${id}`);
    setSelectedChat(res.data);
  };

  const updateTicket = async (status?: string) => {
    if (!selectedTicket) return;
    setLoading(true);
    try {
      await api.patch(`/v1/admin/support/tickets/${selectedTicket.id}`, {
        status,
        reply: reply || undefined,
      });
      toast({ title: "Ticket updated" });
      setReply("");
      await loadTicket(selectedTicket.id);
      mutateTickets();
    } catch (e: any) {
      toast({ title: "Error", description: e?.response?.data?.message || "Update failed", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const claimChat = async (id: string) => {
    setLoading(true);
    try {
      await api.post(`/v1/admin/support/chat/sessions/${id}/claim`);
      toast({ title: "Chat claimed" });
      await loadChat(id);
      mutateChat();
    } catch (e: any) {
      toast({ title: "Error", description: e?.response?.data?.message || "Claim failed", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const sendChat = async () => {
    if (!selectedChat || !chatReply.trim()) return;
    setLoading(true);
    try {
      await api.post(`/v1/admin/support/chat/sessions/${selectedChat.id}/messages`, {
        content: chatReply.trim(),
      });
      setChatReply("");
      await loadChat(selectedChat.id);
      mutateChat();
    } catch (e: any) {
      toast({ title: "Error", description: e?.response?.data?.message || "Send failed", variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <PageHeader title="Help & Support" breadcrumb={[{ label: "Support", href: "/support" }]} />

      <div className="flex gap-2">
        {(["tickets", "bugs", "chat"] as const).map((t) => (
          <Button key={t} variant={tab === t ? "default" : "outline"} onClick={() => { setTab(t); setSelectedTicket(null); setSelectedChat(null); }}>
            {t === "tickets" ? "Tickets" : t === "bugs" ? "Bug Reports" : "Live Chat"}
          </Button>
        ))}
      </div>

      {tab !== "chat" && (
        <Card className="p-4 flex gap-4 items-center">
          <Select value={statusFilter || "all"} onValueChange={(v) => setStatusFilter(v === "all" ? "" : v)}>
            <SelectTrigger className="w-[180px]"><SelectValue placeholder="Status" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="OPEN">Open</SelectItem>
              <SelectItem value="IN_PROGRESS">In Progress</SelectItem>
              <SelectItem value="WAITING">Waiting</SelectItem>
              <SelectItem value="RESOLVED">Resolved</SelectItem>
              <SelectItem value="CLOSED">Closed</SelectItem>
            </SelectContent>
          </Select>
          <span className="text-sm text-gray-600">Total: <strong>{ticketsData?.total ?? tickets.length}</strong></span>
        </Card>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card className="overflow-auto max-h-[70vh]">
          {tab === "chat" ? (
            <table className="w-full text-sm">
              <thead><tr className="border-b bg-gray-50"><th className="p-3 text-left">User</th><th className="p-3 text-left">Status</th><th className="p-3 text-left">Updated</th><th className="p-3">Action</th></tr></thead>
              <tbody>
                {chats.map((c: any) => (
                  <tr key={c.id} className="border-b hover:bg-gray-50">
                    <td className="p-3">{c.user?.displayName ?? c.user?.email ?? c.userId}</td>
                    <td className="p-3"><Badge>{c.status}</Badge></td>
                    <td className="p-3">{new Date(c.updatedAt).toLocaleString()}</td>
                    <td className="p-3"><Button size="sm" variant="outline" onClick={() => loadChat(c.id)}>Open</Button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <table className="w-full text-sm">
              <thead><tr className="border-b bg-gray-50"><th className="p-3 text-left">Subject</th><th className="p-3 text-left">User</th><th className="p-3 text-left">Status</th><th className="p-3">Action</th></tr></thead>
              <tbody>
                {tickets.map((t: any) => (
                  <tr key={t.id} className="border-b hover:bg-gray-50">
                    <td className="p-3">{t.subject}</td>
                    <td className="p-3">{t.user?.displayName ?? t.user?.email ?? t.userId}</td>
                    <td className="p-3"><Badge>{t.status}</Badge></td>
                    <td className="p-3"><Button size="sm" variant="outline" onClick={() => loadTicket(t.id)}>View</Button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>

        <Card className="p-4 max-h-[70vh] overflow-auto">
          {selectedTicket && (
            <div className="space-y-4">
              <h3 className="font-semibold text-lg">{selectedTicket.subject}</h3>
              <p className="text-sm text-gray-600">{selectedTicket.category} · {selectedTicket.type} · {selectedTicket.priority}</p>
              <p className="whitespace-pre-wrap">{selectedTicket.description}</p>
              <div className="space-y-2 border-t pt-4">
                {(selectedTicket.messages ?? []).map((m: any) => (
                  <div key={m.id} className={`p-2 rounded text-sm ${m.isFromUser ? "bg-blue-50" : "bg-gray-50"}`}>
                    <div className="font-medium text-xs text-gray-500">{m.authorName ?? (m.isFromUser ? "User" : "Support")}</div>
                    {m.content}
                  </div>
                ))}
              </div>
              <Textarea value={reply} onChange={(e) => setReply(e.target.value)} placeholder="Reply to user…" />
              <div className="flex flex-wrap gap-2">
                <Button disabled={loading} onClick={() => updateTicket()}>Send reply</Button>
                <Button variant="outline" disabled={loading} onClick={() => updateTicket("IN_PROGRESS")}>Mark in progress</Button>
                <Button variant="outline" disabled={loading} onClick={() => updateTicket("RESOLVED")}>Resolve</Button>
              </div>
            </div>
          )}

          {selectedChat && (
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h3 className="font-semibold">Chat with {selectedChat.user?.displayName ?? selectedChat.user?.email}</h3>
                <Badge>{selectedChat.status}</Badge>
              </div>
              {selectedChat.status === "AWAITING_ADMIN" && (
                <Button disabled={loading} onClick={() => claimChat(selectedChat.id)}>Claim chat</Button>
              )}
              <div className="space-y-2">
                {(selectedChat.messages ?? []).map((m: any) => (
                  <div key={m.id} className={`p-2 rounded text-sm ${m.isFromUser ? "bg-blue-50 ml-8" : "bg-gray-50 mr-8"}`}>
                    <div className="text-xs text-gray-500">{m.senderName ?? (m.isFromUser ? "User" : "Support")}</div>
                    {m.content}
                  </div>
                ))}
              </div>
              <Textarea value={chatReply} onChange={(e) => setChatReply(e.target.value)} placeholder="Message user…" />
              <Button disabled={loading} onClick={sendChat}>Send message</Button>
            </div>
          )}

          {!selectedTicket && !selectedChat && (
            <p className="text-gray-500 text-sm">Select a ticket or chat session to manage it.</p>
          )}
        </Card>
      </div>
    </div>
  );
}
