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

interface TradeItem {
  id: string;
  title: string;
  status: string;
  adminModerationReason?: string | null;
  owner?: { email?: string; profile?: { displayName?: string } };
  createdAt: string;
}

export default function TradesPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);

  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["admin-trades", page, pageSize, q, sortKey, sortDir],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        const res = await api.get<{ items: TradeItem[]; total: number }>(`/v1/admin/trades?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: TradeItem[]; total: number };
      }
    },
  });

  const columns = useMemo<Column<TradeItem>[]>(
    () => [
      { key: "title", header: "Title", sortable: true },
      { key: "status", header: "Status", sortable: true, render: (t) => (
        <div>
          <span>{t.status}</span>
          {t.adminModerationReason && (
            <p className="text-[10px] text-amber-700 max-w-[140px] truncate" title={t.adminModerationReason}>
              {t.adminModerationReason}
            </p>
          )}
        </div>
      ) },
      { key: "ownerEmail", header: "Owner", render: (t) => t.owner?.profile?.displayName || t.owner?.email || "-", sortable: true },
      { key: "createdAt", header: "Created", sortable: true },
      {
        key: "actions",
        header: "Actions",
        render: (t) => (
          <ListingActionsMenu
            moderation={{
              listingKind: "trade",
              listingId: t.id,
              listingTitle: t.title,
              status: t.status,
              onComplete: () => refetch(),
            }}
            actions={[
              {
                id: "edit",
                label: "Edit details",
                section: "primary",
                onClick: () => openEdit(t),
              },
              {
                id: "close",
                label: "Mark closed",
                section: "status",
                hidden: t.status === "CLOSED",
                onClick: () => forceClose(t.id),
              },
              {
                id: "cancel",
                label: "Cancel listing",
                section: "status",
                tone: "warning",
                hidden: t.status === "CANCELLED" || t.status === "BANNED",
                onClick: () => forceCancel(t.id),
              },
              {
                id: "reopen",
                label: "Reopen listing",
                section: "status",
                tone: "success",
                hidden: t.status === "OPEN",
                onClick: () => forceOpen(t.id),
              },
            ]}
          />
        ),
      },
    ],
    []
  );

  const rows = useMemo(
    () => data.items.map((t) => ({ ...t, ownerEmail: t.owner?.email ?? "" })),
    [data]
  );

  // Action handlers
  async function forceClose(id: string) {
    await api.post(`/v1/admin/trades/${id}/force-close`);
    await refetch();
  }
  async function forceCancel(id: string) {
    await api.post(`/v1/admin/trades/${id}/force-cancel`);
    await refetch();
  }
  async function forceOpen(id: string) {
    await api.post(`/v1/admin/trades/${id}/force-open`);
    await refetch();
  }

  // Edit modal state
  const [editing, setEditing] = useState<TradeItem | null>(null);
  const [titleEdit, setTitleEdit] = useState<string>("");
  const [descEdit, setDescEdit] = useState<string>("");
  const [files, setFiles] = useState<FileList | null>(null);
  const [existingMedia, setExistingMedia] = useState<{ key: string; url: string }[]>([]);
  const [loadingMedia, setLoadingMedia] = useState<boolean>(false);
  const [category, setCategory] = useState<string>('OTHERS');
  const [isNegotiable, setIsNegotiable] = useState<boolean>(true);
  const [requiresPickup, setRequiresPickup] = useState<boolean>(true);
  const [allowDelivery, setAllowDelivery] = useState<boolean>(false);
  const [allowShipping, setAllowShipping] = useState<boolean>(false);
  const [enableBYCPromotion, setEnableBYCPromotion] = useState<boolean>(false);

  function openEdit(t: TradeItem) {
    setEditing(t);
    setTitleEdit(t.title || "");
    setDescEdit("");
    setFiles(null);
    // Fetch trade details to load existing media keys
    loadTradeDetails(t.id);
  }

  async function loadTradeDetails(id: string) {
    try {
      setLoadingMedia(true);
      const res = await api.get<any>(`/v1/trades/${id}`);
      const keys: string[] = Array.isArray(res.data?.mediaKeys) ? res.data.mediaKeys : [];
      setCategory((res.data?.category as string) || 'OTHERS');
      setIsNegotiable(Boolean(res.data?.isNegotiable));
      setRequiresPickup(Boolean(res.data?.requiresPickup));
      setAllowDelivery(Boolean(res.data?.allowDelivery));
      setAllowShipping(Boolean(res.data?.allowShipping));
      setEnableBYCPromotion(Boolean(res.data?.enableBYCPromotion));
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
        const up = await api.post('/v1/storage/upload-url', { domain: 'trades', ext, contentType });
        const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
        await axios.put(uploadUrl, f, { headers: { 'Content-Type': contentType } });
        mediaKeys.push(key);
      }
    }
    await api.patch(`/v1/admin/trades/${editing.id}`, {
      title: titleEdit,
      description: descEdit || undefined,
      mediaKeys: mediaKeys.length > 0 ? mediaKeys : undefined,
      category,
      isNegotiable,
      requiresPickup,
      allowDelivery,
      allowShipping,
      enableBYCPromotion,
    });
    setEditing(null);
    await refetch();
  }

  function cancelEdit() {
    setEditing(null);
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Trades"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Trades" }]}
        actions={
          <div className="flex items-center gap-2">
            <input
              value={qLocal}
              onChange={(e) => setQLocal(e.target.value)}
              onBlur={() => setUrlState({ q: qLocal, page: 1 })}
              placeholder="Search trades…"
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <button className="px-3 py-2 text-sm rounded border" onClick={() => refetch()}>Refresh</button>
          </div>
        }
      />
      <Table
        columns={columns}
        data={rows as any}
        loading={isLoading}
        error={isError && "Failed to load trades"}
        emptyLabel="No trades found"
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
            <h3 className="text-lg font-semibold mb-4">Edit Trade</h3>
            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium">Title</label>
                <input className="mt-1 w-full border rounded px-3 py-2" value={titleEdit} onChange={(e) => setTitleEdit(e.target.value)} />
              </div>
              <div>
                <label className="block text-sm font-medium">Description</label>
                <textarea className="mt-1 w-full border rounded px-3 py-2" rows={3} value={descEdit} onChange={(e) => setDescEdit(e.target.value)} />
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
              <div>
                <label className="block text-sm font-medium">Category</label>
                <select className="mt-1 w-full border rounded px-3 py-2" value={category} onChange={(e) => setCategory(e.target.value)}>
                  {['ELECTRONICS','BOOKS','CLOTHING','FASHION','HOME_GARDEN','SPORTS','TOOLS','AUTOMOTIVE','COLLECTIBLES','OTHERS'].map(opt => (
                    <option key={opt} value={opt}>{opt.replace('_',' ')}</option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <label className="flex items-center gap-2"><input type="checkbox" checked={isNegotiable} onChange={(e) => setIsNegotiable(e.target.checked)} /> <span className="text-sm">Negotiable</span></label>
                <label className="flex items-center gap-2"><input type="checkbox" checked={requiresPickup} onChange={(e) => setRequiresPickup(e.target.checked)} /> <span className="text-sm">Pickup</span></label>
                <label className="flex items-center gap-2"><input type="checkbox" checked={allowDelivery} onChange={(e) => setAllowDelivery(e.target.checked)} /> <span className="text-sm">Delivery</span></label>
                <label className="flex items-center gap-2"><input type="checkbox" checked={allowShipping} onChange={(e) => setAllowShipping(e.target.checked)} /> <span className="text-sm">Shipping</span></label>
                <label className="flex items-center gap-2"><input type="checkbox" checked={enableBYCPromotion} onChange={(e) => setEnableBYCPromotion(e.target.checked)} /> <span className="text-sm">BYC Promotion</span></label>
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
