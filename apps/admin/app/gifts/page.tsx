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

interface GiftItem {
  id: string;
  title: string;
  type: string;
  category: string;
  status: string;
  adminModerationReason?: string | null;
  karmaReward: number;
  maxClaims: number;
  currentClaims: number;
  giver?: { email?: string; profile?: { displayName?: string } };
  createdAt: string;
  expiresAt?: string;
}

interface GiftRequest {
  id: string;
  message?: string;
  status: string;
  createdAt: string;
  respondedAt?: string;
  responseMessage?: string;
  declineReason?: string;
  gift: {
    id: string;
    title: string;
    karmaReward: number;
    giver?: { profile?: { displayName?: string } };
  };
  requester: {
    id: string;
    profile?: { displayName?: string };
  };
}

interface GiftStats {
  totalGifts: number;
  activeGifts: number;
  claimedGifts: number;
  expiredGifts: number;
  totalClaims: number;
  pendingRequests: number;
  categoryBreakdown: Record<string, number>;
  typeBreakdown: Record<string, number>;
}

interface GiftAnalytics {
  recentGifts: number;
  recentClaims: number;
  topCategories: { category: string; _count: { category: number } }[];
  expiringGifts: number;
  claimRate: string;
  topGivers: { giverId: string; _count: { giverId: number } }[];
  monthlyTrends: { date: string; count: number }[];
  avgKarmaPerGift: number;
  topReceivers: { claimerId: string; _count: { claimerId: number } }[];
}

export default function GiftsPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);
  const [selectedStatus, setSelectedStatus] = useState<string>("all");
  const [activeTab, setActiveTab] = useState<'gifts' | 'requests'>('gifts');

  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data: stats } = useQuery({
    queryKey: ["admin-gifts-stats"],
    queryFn: async () => {
      try {
        const res = await api.get<GiftStats>(`/v1/admin/gifts/stats`);
        return res.data;
      } catch {
        return null;
      }
    },
  });

  const { data: analytics } = useQuery({
    queryKey: ["admin-gifts-analytics"],
    queryFn: async () => {
      try {
        const res = await api.get<GiftAnalytics>(`/v1/admin/gifts/analytics`);
        return res.data;
      } catch {
        return null;
      }
    },
  });

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["admin-gifts", page, pageSize, q, sortKey, sortDir, selectedStatus],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        if (selectedStatus !== "all") params.set("status", selectedStatus.toUpperCase());
        const res = await api.get<{ items: GiftItem[]; total: number }>(`/v1/admin/gifts?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: GiftItem[]; total: number };
      }
    },
  });

  const { data: requestsData = { items: [], total: 0 }, refetch: refetchRequests } = useQuery({
    queryKey: ["admin-gift-requests", page, pageSize, selectedStatus],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize) });
        if (selectedStatus !== "all") params.set("status", selectedStatus.toUpperCase());
        const res = await api.get<{ items: GiftRequest[]; total: number }>(`/v1/admin/gifts/requests?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: GiftRequest[]; total: number };
      }
    },
  });

  const columns = useMemo<Column<GiftItem>[]>(
    () => [
      { key: "title", header: "Title", sortable: true },
      { key: "type", header: "Type", sortable: true },
      { key: "category", header: "Category", sortable: true },
      { 
        key: "status", 
        header: "Status", 
        sortable: true,
        render: (gift) => (
          <div>
            <span className={`px-2 py-1 rounded text-xs font-medium ${
            gift.status === 'ACTIVE' ? 'bg-green-100 text-green-800' :
            gift.status === 'CLAIMED' ? 'bg-blue-100 text-blue-800' :
            gift.status === 'EXPIRED' ? 'bg-red-100 text-red-800' :
            gift.status === 'PAUSED' ? 'bg-yellow-100 text-yellow-800' :
            gift.status === 'BANNED' ? 'bg-red-200 text-red-900' :
            'bg-gray-100 text-gray-800'
          }`}>
              {gift.status.toLowerCase()}
            </span>
            {gift.adminModerationReason && (
              <p className="text-[10px] text-amber-700 max-w-[140px] truncate mt-1" title={gift.adminModerationReason}>
                {gift.adminModerationReason}
              </p>
            )}
          </div>
        )
      },
      { key: "karmaReward", header: "Karma", sortable: true },
      { 
        key: "claims", 
        header: "Claims", 
        render: (gift) => `${gift.currentClaims}/${gift.maxClaims}` 
      },
      { key: "giverEmail", header: "Giver", render: (t) => t.giver?.profile?.displayName || t.giver?.email || "-", sortable: true },
      { 
        key: "createdAt", 
        header: "Created", 
        sortable: true,
        render: (gift) => new Date(gift.createdAt).toLocaleDateString()
      },
      {
        key: "actions",
        header: "Actions",
        render: (g) => (
          <ListingActionsMenu
            moderation={{
              listingKind: "gift",
              listingId: g.id,
              listingTitle: g.title,
              status: g.status,
              onComplete: () => refetch(),
            }}
            actions={[
              {
                id: "edit",
                label: "Edit details",
                section: "primary",
                onClick: () => openEdit(g),
              },
              {
                id: "expire",
                label: "Mark expired",
                section: "status",
                tone: "warning",
                hidden: g.status === "EXPIRED",
                onClick: () => forceExpire(g.id),
              },
              {
                id: "cancel",
                label: "Cancel gift",
                section: "status",
                tone: "warning",
                hidden: g.status === "CANCELLED" || g.status === "BANNED",
                onClick: () => forceCancel(g.id),
              },
              {
                id: "reactivate",
                label: "Reactivate gift",
                section: "status",
                tone: "success",
                hidden: g.status === "ACTIVE",
                onClick: () => reactivate(g.id),
              },
            ]}
          />
        )
      },
    ],
    []
  );

  const rows = useMemo(
    () => data.items.map((t) => ({ ...t, giverEmail: t.giver?.email ?? "" })),
    [data]
  );

  async function forceExpire(id: string) {
    await api.post(`/v1/admin/gifts/${id}/force-expire`);
    await refetch();
  }
  async function forceCancel(id: string) {
    await api.post(`/v1/admin/gifts/${id}/force-cancel`);
    await refetch();
  }
  async function reactivate(id: string) {
    await api.post(`/v1/admin/gifts/${id}/reactivate`);
    await refetch();
  }

  async function approveRequest(requestId: string) {
    try {
      await api.post(`/v1/admin/gifts/requests/${requestId}/approve`, { message: 'Approved by admin' });
      await refetchRequests();
      await refetch();
    } catch (e: any) {
      alert(e.response?.data?.message || 'Failed to approve request');
    }
  }

  async function declineRequest(requestId: string) {
    const reason = prompt('Decline reason (optional):');
    try {
      await api.post(`/v1/admin/gifts/requests/${requestId}/decline`, { reason });
      await refetchRequests();
    } catch (e: any) {
      alert(e.response?.data?.message || 'Failed to decline request');
    }
  }

  // Edit modal state
  const [editing, setEditing] = useState<GiftItem | null>(null);
  const [titleEdit, setTitleEdit] = useState<string>("");
  const [descEdit, setDescEdit] = useState<string>("");
  const [typeEdit, setTypeEdit] = useState<string>("RANDOM");
  const [categoryEdit, setCategoryEdit] = useState<string>("OTHERS");
  const [karmaReward, setKarmaReward] = useState<number>(30);
  const [maxClaims, setMaxClaims] = useState<number>(1);
  const [locationEdit, setLocationEdit] = useState<string>("");
  const [isLocationRestricted, setIsLocationRestricted] = useState<boolean>(false);
  const [files, setFiles] = useState<FileList | null>(null);
  const [existingMedia, setExistingMedia] = useState<{ key: string; url: string }[]>([]);
  const [loadingMedia, setLoadingMedia] = useState<boolean>(false);

  function openEdit(g: GiftItem) {
    setEditing(g);
    setTitleEdit(g.title || "");
    setDescEdit("");
    setTypeEdit(g.type || "RANDOM");
    setCategoryEdit(g.category || "OTHERS");
    setKarmaReward(g.karmaReward || 30);
    setMaxClaims(g.maxClaims || 1);
    setLocationEdit("");
    setIsLocationRestricted(false);
    loadGiftDetails(g.id);
  }

  async function loadGiftDetails(id: string) {
    try {
      setLoadingMedia(true);
      const res = await api.get<any>(`/v1/gifts/${id}`);
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
      setLocationEdit(res.data?.location || "");
      setIsLocationRestricted(Boolean(res.data?.isLocationRestricted));
      setDescEdit(res.data?.description || "");
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
        const up = await api.post('/v1/storage/upload-url', { domain: 'gifts', ext, contentType });
        const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
        await axios.put(uploadUrl, f, { headers: { 'Content-Type': contentType } });
        mediaKeys.push(key);
      }
    }
    await api.patch(`/v1/admin/gifts/${editing.id}`, {
      title: titleEdit,
      description: descEdit || undefined,
      type: typeEdit,
      category: categoryEdit,
      karmaReward,
      maxClaims,
      location: locationEdit || undefined,
      isLocationRestricted,
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
    { value: "claimed", label: "Claimed" },
    { value: "expired", label: "Expired" },
    { value: "cancelled", label: "Cancelled" },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Gifts"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Gifts" }]}
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
              placeholder="Search gifts…"
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
            <div className="text-2xl font-bold text-gray-900">{stats.totalGifts}</div>
            <div className="text-sm text-gray-500">Total Gifts</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-green-600">{stats.activeGifts}</div>
            <div className="text-sm text-gray-500">Active</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-blue-600">{stats.claimedGifts}</div>
            <div className="text-sm text-gray-500">Claimed</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-red-600">{stats.expiredGifts}</div>
            <div className="text-sm text-gray-500">Expired</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-purple-600">{stats.totalClaims}</div>
            <div className="text-sm text-gray-500">Total Claims</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-orange-600">{stats.pendingRequests || 0}</div>
            <div className="text-sm text-gray-500">Pending Requests</div>
          </div>
        </div>
      )}

      {/* Enhanced Analytics Section */}
      {analytics && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Category Breakdown */}
          <div className="bg-white p-6 rounded-lg shadow border">
            <h3 className="text-lg font-semibold mb-4">Top Categories</h3>
            <div className="space-y-3">
              {analytics.topCategories.map((category, index) => (
                <div key={index} className="flex items-center justify-between">
                  <span className="text-gray-700">{category.category}</span>
                  <span className="font-medium">{category._count.category}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Key Metrics */}
          <div className="bg-white p-6 rounded-lg shadow border">
            <h3 className="text-lg font-semibold mb-4">Key Metrics</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-blue-50 p-4 rounded-lg">
                <div className="text-2xl font-bold text-blue-600">{analytics.recentGifts}</div>
                <div className="text-sm text-gray-600">Gifts (30d)</div>
              </div>
              <div className="bg-green-50 p-4 rounded-lg">
                <div className="text-2xl font-bold text-green-600">{analytics.recentClaims}</div>
                <div className="text-sm text-gray-600">Claims (30d)</div>
              </div>
              <div className="bg-purple-50 p-4 rounded-lg">
                <div className="text-2xl font-bold text-purple-600">{analytics.claimRate}%</div>
                <div className="text-sm text-gray-600">Claim Rate</div>
              </div>
              <div className="bg-orange-50 p-4 rounded-lg">
                <div className="text-2xl font-bold text-orange-600">{analytics.avgKarmaPerGift.toFixed(1)}</div>
                <div className="text-sm text-gray-600">Avg Karma</div>
              </div>
            </div>
          </div>

          {/* Expiring Gifts */}
          <div className="bg-white p-6 rounded-lg shadow border">
            <h3 className="text-lg font-semibold mb-4">Expiring Soon</h3>
            <div className="flex items-center justify-between p-4 bg-red-50 rounded-lg">
              <div>
                <div className="text-2xl font-bold text-red-600">{analytics.expiringGifts}</div>
                <div className="text-sm text-gray-600">Gifts expiring in 7 days</div>
              </div>
              <div className="text-red-500">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-8">
          <button
            onClick={() => setActiveTab('gifts')}
            className={`py-2 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'gifts'
                ? 'border-indigo-500 text-indigo-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            Gifts ({data.total})
          </button>
          <button
            onClick={() => setActiveTab('requests')}
            className={`py-2 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'requests'
                ? 'border-indigo-500 text-indigo-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            Requests ({requestsData.total})
          </button>
        </nav>
      </div>

      {activeTab === 'gifts' ? (
        <Table
          columns={columns}
          data={rows as any}
          loading={isLoading}
          error={isError && "Failed to load gifts"}
          emptyLabel="No gifts found"
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
      ) : (
        <div className="bg-white rounded-lg shadow">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Gift</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Requester</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Owner</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {requestsData.items.map((req) => (
                  <tr key={req.id}>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <div className="font-medium text-gray-900">{req.gift.title}</div>
                      <div className="text-gray-500">Karma: {req.gift.karmaReward}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {req.requester.profile?.displayName || req.requester.id}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {req.gift.giver?.profile?.displayName || '-'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 py-1 rounded text-xs font-medium ${
                        req.status === 'PENDING' ? 'bg-yellow-100 text-yellow-800' :
                        req.status === 'APPROVED' ? 'bg-green-100 text-green-800' :
                        req.status === 'DECLINED' ? 'bg-red-100 text-red-800' :
                        'bg-gray-100 text-gray-800'
                      }`}>
                        {req.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(req.createdAt).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {req.status === "PENDING" ? (
                        <ListingActionsMenu
                          actions={[
                            {
                              id: "approve",
                              label: "Approve request",
                              section: "primary",
                              tone: "success",
                              onClick: () => approveRequest(req.id),
                            },
                            {
                              id: "decline",
                              label: "Decline request",
                              section: "danger",
                              tone: "danger",
                              onClick: () => declineRequest(req.id),
                            },
                          ]}
                        />
                      ) : (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {requestsData.items.length === 0 && (
              <div className="text-center py-12 text-gray-500">No gift requests found</div>
            )}
          </div>
        </div>
      )}

      {editing && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-lg p-6">
            <h3 className="text-lg font-semibold mb-4">Edit Gift</h3>
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
                  <label className="block text-sm font-medium">Type</label>
                  <select className="mt-1 w-full border rounded px-3 py-2" value={typeEdit} onChange={(e) => setTypeEdit(e.target.value)}>
                    {['RANDOM','TARGETED'].map(opt => (<option key={opt} value={opt}>{opt}</option>))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium">Category</label>
                  <select className="mt-1 w-full border rounded px-3 py-2" value={categoryEdit} onChange={(e) => setCategoryEdit(e.target.value)}>
                    {['ELECTRONICS','BOOKS','CLOTHING','FASHION','HOME_GARDEN','SPORTS','TOOLS','AUTOMOTIVE','COLLECTIBLES','OTHERS'].map(opt => (<option key={opt} value={opt}>{opt.replace('_',' ')}</option>))}
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium">Karma Reward</label>
                  <input type="number" className="mt-1 w-full border rounded px-3 py-2" value={karmaReward} onChange={(e) => setKarmaReward(parseInt(e.target.value || '0', 10))} />
                </div>
                <div>
                  <label className="block text-sm font-medium">Max Claims</label>
                  <input type="number" className="mt-1 w-full border rounded px-3 py-2" value={maxClaims} onChange={(e) => setMaxClaims(parseInt(e.target.value || '1', 10))} />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium">Location</label>
                  <input className="mt-1 w-full border rounded px-3 py-2" value={locationEdit} onChange={(e) => setLocationEdit(e.target.value)} />
                </div>
                <label className="flex items-center gap-2"><input type="checkbox" checked={isLocationRestricted} onChange={(e) => setIsLocationRestricted(e.target.checked)} /> <span className="text-sm">Location Restricted</span></label>
              </div>
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