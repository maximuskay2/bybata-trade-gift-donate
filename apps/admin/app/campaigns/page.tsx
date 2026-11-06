"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";
import axios from "axios";
import ListingActionsMenu from "@/app/components/listing-actions-menu";

interface Campaign {
  id: string;
  title: string;
  description: string;
  goal: number;
  raised: number;
  status: string;
  adminModerationReason?: string | null;
  category: string;
  creator?: { email?: string; profile?: { displayName?: string } };
  createdAt: string;
  endsAt?: string;
  donorCount: number;
}

interface CampaignStats {
  totalCampaigns: number;
  activeCampaigns: number;
  completedCampaigns: number;
  pausedCampaigns: number;
  totalRaised: number;
  averageGoal: number;
  categoryBreakdown: Record<string, number>;
}

export default function CampaignsPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);
  const [selectedStatus, setSelectedStatus] = useState<string>("all");

  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data: stats } = useQuery({
    queryKey: ["admin-campaigns-stats"],
    queryFn: async () => {
      try {
        const res = await api.get<CampaignStats>(`/v1/admin/campaigns/stats`);
        return res.data;
      } catch {
        return null;
      }
    },
  });

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["admin-campaigns", page, pageSize, q, sortKey, sortDir, selectedStatus],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        if (selectedStatus !== "all") params.set("status", selectedStatus.toUpperCase());
        const res = await api.get<{ items: Campaign[]; total: number }>(`/v1/admin/campaigns?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: Campaign[]; total: number };
      }
    },
  });

  const columns = useMemo<Column<Campaign>[]>(
    () => [
      { key: "title", header: "Title", sortable: true },
      { key: "category", header: "Category", sortable: true },
      { 
        key: "status", 
        header: "Status", 
        sortable: true,
        render: (campaign) => (
          <div>
            <span className={`px-2 py-1 rounded text-xs font-medium ${
            campaign.status === 'ACTIVE' ? 'bg-green-100 text-green-800' :
            campaign.status === 'COMPLETED' ? 'bg-blue-100 text-blue-800' :
            campaign.status === 'PAUSED' ? 'bg-yellow-100 text-yellow-800' :
            campaign.status === 'BANNED' ? 'bg-red-200 text-red-900' :
            'bg-gray-100 text-gray-800'
          }`}>
              {campaign.status.toLowerCase()}
            </span>
            {campaign.adminModerationReason && (
              <p className="text-[10px] text-amber-700 max-w-[140px] truncate mt-1" title={campaign.adminModerationReason}>
                {campaign.adminModerationReason}
              </p>
            )}
          </div>
        )
      },
      { 
        key: "goal", 
        header: "Goal", 
        sortable: true,
        render: (campaign) => `$${(campaign.goal ?? 0).toLocaleString()}`
      },
      { 
        key: "raised", 
        header: "Raised", 
        sortable: true,
        render: (campaign) => `$${(campaign.raised ?? 0).toLocaleString()}`
      },
      { 
        key: "progress", 
        header: "Progress", 
        render: (campaign) => {
          const goal = campaign.goal ?? 0;
          const raised = campaign.raised ?? 0;
          const percentage = goal > 0 ? Math.min((raised / goal) * 100, 100) : 0;
          return `${percentage.toFixed(1)}%`;
        }
      },
      { key: "donorCount", header: "Donors", sortable: true },
      { key: "creatorEmail", header: "Creator", render: (c) => c.creator?.profile?.displayName || c.creator?.email || "-", sortable: true },
      { 
        key: "createdAt", 
        header: "Created", 
        sortable: true,
        render: (campaign) => new Date(campaign.createdAt).toLocaleDateString()
      },
      {
        key: "actions",
        header: "Actions",
        render: (c) => (
          <ListingActionsMenu
            moderation={{
              listingKind: "campaign",
              listingId: c.id,
              listingTitle: c.title,
              status: c.status,
              onComplete: () => refetch(),
            }}
            actions={[
              {
                id: "edit",
                label: "Edit campaign",
                section: "primary",
                onClick: () => openEdit(c),
              },
              {
                id: "activate",
                label: "Activate",
                section: "status",
                tone: "success",
                hidden: c.status === "ACTIVE",
                onClick: () => forceStatus(c.id, "ACTIVE"),
              },
              {
                id: "pause",
                label: "Pause campaign",
                section: "status",
                tone: "warning",
                hidden: c.status === "PAUSED",
                onClick: () => forceStatus(c.id, "PAUSED"),
              },
              {
                id: "complete",
                label: "Mark completed",
                section: "status",
                onClick: () => forceStatus(c.id, "COMPLETED"),
                hidden: c.status === "COMPLETED",
              },
              {
                id: "cancel",
                label: "Cancel campaign",
                section: "status",
                tone: "warning",
                hidden: c.status === "CANCELLED" || c.status === "BANNED",
                onClick: () => forceStatus(c.id, "CANCELLED"),
              },
            ]}
          />
        )
      },
    ],
    []
  );

  const rows = useMemo(
    () => data.items.map((c) => ({ ...c, creatorEmail: c.creator?.email ?? "" })),
    [data]
  );

  async function forceStatus(id: string, status: string) {
    await api.post(`/v1/admin/campaigns/${id}/force-status`, { status });
    await refetch();
  }

  // Edit modal state
  const [editing, setEditing] = useState<Campaign | null>(null);
  const [titleEdit, setTitleEdit] = useState<string>("");
  const [descEdit, setDescEdit] = useState<string>("");
  const [categoryEdit, setCategoryEdit] = useState<string>("");
  const [locationEdit, setLocationEdit] = useState<string>("");
  const [isUrgent, setIsUrgent] = useState<boolean>(false);
  const [files, setFiles] = useState<FileList | null>(null);
  const [existingMedia, setExistingMedia] = useState<{ key: string; url: string }[]>([]);
  const [loadingMedia, setLoadingMedia] = useState<boolean>(false);

  function openEdit(c: Campaign) {
    setEditing(c);
    setTitleEdit(c.title || "");
    setDescEdit(c.description || "");
    setCategoryEdit(c.category || "");
    setLocationEdit("");
    setIsUrgent(false);
    loadCampaignDetails(c.id);
  }

  async function loadCampaignDetails(id: string) {
    try {
      setLoadingMedia(true);
      const res = await api.get<any>(`/v1/campaigns/${id}`);
      const keys: string[] = Array.isArray(res.data?.mediaKeys) ? res.data.mediaKeys : [];
      const resolved: { key: string; url: string }[] = [];
      for (const k of keys) {
        try {
          const du = await api.get<{ url: string }>(`/v1/storage/download-url`, { params: { key: k } });
          resolved.push({ key: k, url: du.data.url });
        } catch {
          resolved.push({ key: k, url: k });
        }
      }
      setExistingMedia(resolved);
      setIsUrgent(Boolean(res.data?.isUrgent));
      setLocationEdit(res.data?.location || "");
    } catch {
      setExistingMedia([]);
    } finally {
      setLoadingMedia(false);
    }
  }

  async function saveEdit() {
    if (!editing) return;
    const mediaKeys: string[] = existingMedia.map(m => m.key);
    if (files && files.length > 0) {
      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const name = f.name.toLowerCase();
        const ext = name.endsWith('.png') ? 'png' : (name.endsWith('.jpg') || name.endsWith('.jpeg')) ? 'jpg' : 'bin';
        const contentType = ext === 'png' ? 'image/png' : ext === 'jpg' ? 'image/jpeg' : f.type || 'application/octet-stream';
        const up = await api.post('/v1/storage/upload-url', { domain: 'donations', ext, contentType });
        const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
        await axios.put(uploadUrl, f, { headers: { 'Content-Type': contentType } });
        mediaKeys.push(key);
      }
    }
    await api.patch(`/v1/admin/campaigns/${editing.id}`, {
      title: titleEdit,
      description: descEdit || undefined,
      category: categoryEdit || undefined,
      location: locationEdit || undefined,
      isUrgent,
      mediaKeys: mediaKeys.length > 0 ? mediaKeys : undefined,
    });
    setEditing(null);
    await refetch();
  }

  function cancelEdit() {
    setEditing(null);
  }

  const statusOptions = [
    { value: "all", label: "All Status" },
    { value: "active", label: "Active" },
    { value: "completed", label: "Completed" },
    { value: "paused", label: "Paused" },
    { value: "cancelled", label: "Cancelled" },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Donations"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Donations" }]}
        actions={
          <div className="flex items-center gap-2">
            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {statusOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <input
              value={qLocal}
              onChange={(e) => setQLocal(e.target.value)}
              onBlur={() => setUrlState({ q: qLocal, page: 1 })}
              placeholder="Search donations…"
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button className="px-3 py-2 text-sm rounded border" onClick={() => refetch()}>
              Refresh
            </button>
          </div>
        }
      />

      {/* Stats Cards */}
      {stats && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-4">
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-gray-900">{stats.totalCampaigns ?? 0}</div>
            <div className="text-sm text-gray-500">Total Donations</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-green-600">{stats.activeCampaigns ?? 0}</div>
            <div className="text-sm text-gray-500">Active</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-blue-600">{stats.completedCampaigns ?? 0}</div>
            <div className="text-sm text-gray-500">Completed</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-yellow-600">{stats.pausedCampaigns ?? 0}</div>
            <div className="text-sm text-gray-500">Paused</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-purple-600">${(stats.totalRaised ?? 0).toLocaleString()}</div>
            <div className="text-sm text-gray-500">Total Raised</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-indigo-600">${(stats.averageGoal ?? 0).toLocaleString()}</div>
            <div className="text-sm text-gray-500">Avg Goal</div>
          </div>
        </div>
      )}

      <Table
        columns={columns}
        data={rows as any}
        loading={isLoading}
        error={isError && "Failed to load donations"}
        emptyLabel="No donations found"
        pagination={{
          page,
          pageSize,
          total: data.total,
          onPageChange: (p) => setUrlState({ page: p }),
          onPageSizeChange: (s) => setUrlState({ size: s, page: 1 }),
        }}
        sortKey={sortKey}
        sortDir={sortDir}
        onSortChange={(key, d) => setUrlState({ sort: key, dir: d })}
      />

      {editing && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-lg p-6">
            <h3 className="text-lg font-semibold mb-4">Edit Donation Campaign</h3>
            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium">Title</label>
                <input className="mt-1 w-full border rounded px-3 py-2" value={titleEdit} onChange={(e) => setTitleEdit(e.target.value)} />
              </div>
              <div>
                <label className="block text-sm font-medium">Description</label>
                <textarea className="mt-1 w-full border rounded px-3 py-2" rows={3} value={descEdit} onChange={(e) => setDescEdit(e.target.value)} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium">Category</label>
                  <input className="mt-1 w-full border rounded px-3 py-2" value={categoryEdit} onChange={(e) => setCategoryEdit(e.target.value)} />
                </div>
                <div>
                  <label className="block text-sm font-medium">Location</label>
                  <input className="mt-1 w-full border rounded px-3 py-2" value={locationEdit} onChange={(e) => setLocationEdit(e.target.value)} />
                </div>
              </div>
              <label className="flex items-center gap-2"><input type="checkbox" checked={isUrgent} onChange={(e) => setIsUrgent(e.target.checked)} /> <span className="text-sm">Urgent</span></label>
              <div>
                <label className="block text-sm font-medium">Existing Photos</label>
                {loadingMedia ? (
                  <p className="text-sm text-gray-500">Loading media…</p>
                ) : existingMedia.length === 0 ? (
                  <p className="text-sm text-gray-500">No existing photos</p>
                ) : (
                  <div className="flex flex-wrap gap-3">
                    {existingMedia.map((m, idx) => (
                      <div key={m.key} className="relative">
                        <img src={m.url} alt="media" className="w-24 h-24 object-cover rounded border" />
                        <button
                          className="absolute -top-2 -right-2 bg-red-600 text-white rounded-full w-6 h-6 text-xs"
                          onClick={() => setExistingMedia(prev => prev.filter((_, i) => i !== idx))}
                          title="Remove"
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium">Add Photos</label>
                <input type="file" multiple accept="image/*" onChange={(e) => setFiles(e.target.files)} />
              </div>
            </div>
            <div className="mt-4 flex items-center justify-end gap-2">
              <button className="px-3 py-2 text-sm rounded border" onClick={cancelEdit}>Cancel</button>
              <button className="px-3 py-2 text-sm rounded bg-indigo-600 text-white" onClick={saveEdit}>Save</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}