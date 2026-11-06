"use client";
import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import PageHeader from "@/app/components/page-header";
import Table, { Column } from "@/app/components/ui/table";
import useUrlState from "@/app/hooks/useUrlState";
import useDebounce from "@/app/hooks/useDebounce";
import axios from "axios";

interface Community {
  id: string;
  name: string;
  description: string;
  type: string;
  visibility?: string;
  requiresApproval?: boolean;
  memberCount: number;
  postCount: number;
  eventCount?: number;
  status: string;
  category: string;
  owner?: { email?: string; profile?: { displayName?: string } };
  createdAt: string;
  isVerified: boolean;
  isFeatured: boolean;
  center_latitude?: number;
  center_longitude?: number;
  rating?: number;
  _count?: {
    members: number;
    posts: number;
    events: number;
    goals?: number;
  };
}

interface CommunityMember {
  id: string;
  userId: string;
  role: string;
  status: string;
  joinedAt: string;
  user: {
    id: string;
    email: string;
    profile?: {
      displayName?: string;
      avatarKey?: string;
    };
  };
}

interface CommunityStats {
  totalCommunities: number;
  activeCommunities: number;
  suspendedCommunities?: number;
  privateCommunities: number;
  publicCommunities: number;
  totalMembers: number;
  totalPosts: number;
  totalEvents?: number;
  totalPolls?: number;
  totalReports?: number;
  typeBreakdown: Record<string, number>;
  categoryBreakdown: Record<string, number>;
}

export default function CommunitiesPage() {
  const [urlState, setUrlState] = useUrlState({ page: 1, size: 20, q: "", sort: "createdAt", dir: "desc" });
  const [qLocal, setQLocal] = useState<string>((urlState.q as any) || "");
  const q = useDebounce(qLocal, 400);
  const [selectedType, setSelectedType] = useState<string>("all");

  const page = Number(urlState.page) || 1;
  const pageSize = Number(urlState.size) || 20;
  const sortKey = (urlState.sort as string) || "createdAt";
  const sortDir = (urlState.dir as 'asc' | 'desc') || "desc";

  const { data: stats } = useQuery({
    queryKey: ["admin-communities-stats"],
    queryFn: async () => {
      try {
        const res = await api.get<CommunityStats>(`/v1/admin/communities/stats`);
        return res.data;
      } catch {
        return null;
      }
    },
  });

  const { data = { items: [], total: 0 }, isLoading, isError, refetch } = useQuery({
    queryKey: ["admin-communities", page, pageSize, q, sortKey, sortDir, selectedType],
    queryFn: async () => {
      try {
        const params = new URLSearchParams({ page: String(page), size: String(pageSize), sort: sortKey, dir: sortDir });
        if (q) params.set("query", q);
        if (selectedType !== "all") params.set("type", selectedType.toUpperCase());
        const res = await api.get<{ items: Community[]; total: number }>(`/v1/admin/communities?${params.toString()}`);
        return res.data;
      } catch {
        return { items: [], total: 0 } as { items: Community[]; total: number };
      }
    },
  });

  const columns = useMemo<Column<Community>[]>(
    () => [
      { 
        key: "name", 
        header: "Name", 
        sortable: true,
        render: (community) => (
          <div className="flex items-center gap-2">
            <span>{community.name}</span>
            {community.isVerified && (
              <span className="text-blue-500">✓</span>
            )}
          </div>
        )
      },
      { key: "category", header: "Category", sortable: true },
      { 
        key: "type", 
        header: "Type", 
        sortable: true,
        render: (community) => (
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            community.type === 'PUBLIC' ? 'bg-green-100 text-green-800' :
            community.type === 'PRIVATE' ? 'bg-red-100 text-red-800' :
            'bg-yellow-100 text-yellow-800'
          }`}>
            {community.type.replace('_', ' ').toLowerCase()}
          </span>
        )
      },
      { 
        key: "visibility", 
        header: "Visibility", 
        sortable: true,
        render: (community) => (
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            community.visibility === 'OPEN' ? 'bg-blue-100 text-blue-800' :
            community.visibility === 'CLOSED' ? 'bg-orange-100 text-orange-800' :
            'bg-gray-100 text-gray-800'
          }`}>
            {community.visibility?.toLowerCase() || 'open'}
          </span>
        )
      },
      { 
        key: "status", 
        header: "Status", 
        sortable: true,
        render: (community) => (
          <span className={`px-2 py-1 rounded text-xs font-medium ${
            community.status === 'ACTIVE' ? 'bg-green-100 text-green-800' :
            community.status === 'SUSPENDED' ? 'bg-red-100 text-red-800' :
            'bg-gray-100 text-gray-800'
          }`}>
            {community.status.toLowerCase()}
          </span>
        )
      },
      { key: "memberCount", header: "Members", sortable: true },
      { key: "postCount", header: "Posts", sortable: true },
      { key: "eventCount", header: "Events", render: (c) => c.eventCount || c._count?.events || 0, sortable: true },
      { key: "ownerEmail", header: "Owner", render: (c) => c.owner?.profile?.displayName || c.owner?.email || "-", sortable: true },
      { 
        key: "createdAt", 
        header: "Created", 
        sortable: true,
        render: (community) => new Date(community.createdAt).toLocaleDateString()
      },
      {
        key: "actions",
        header: "Actions",
        render: (c) => (
          <div className="flex flex-wrap items-center gap-2">
            <button className="px-2 py-1 text-xs rounded border" onClick={() => openEdit(c)}>Edit</button>
            <button className="px-2 py-1 text-xs rounded border" onClick={() => featureCommunity(c.id, !c.isVerified)}>Toggle Feature</button>
            <button className="px-2 py-1 text-xs rounded border" onClick={() => verifyCommunity(c.id, !c.isVerified)}>Toggle Verify</button>
            <button className="px-2 py-1 text-xs rounded border" onClick={() => loadCommunityMembers(c)}>Manage Members</button>
            {c.status === 'SUSPENDED' ? (
              <button className="px-2 py-1 text-xs rounded border border-green-500 text-green-600" onClick={() => unbanCommunity(c.id)}>Unban</button>
            ) : (
              <button className="px-2 py-1 text-xs rounded border border-red-500 text-red-600" onClick={() => openBanCommunityModal(c)}>Ban</button>
            )}
            <button className="px-2 py-1 text-xs rounded border border-red-500 text-red-600" onClick={() => forceDelete(c.id)}>Delete</button>
          </div>
        )
      },
    ],
    []
  );

  const rows = useMemo(
    () => data.items.map((c) => ({ ...c, ownerEmail: c.owner?.email ?? "" })),
    [data]
  );

  async function featureCommunity(id: string, featured: boolean) {
    await api.put(`/v1/admin/communities/${id}/feature`, { featured });
    await refetch();
  }
  async function verifyCommunity(id: string, verified: boolean) {
    await api.put(`/v1/admin/communities/${id}/verify`, { verified });
    await refetch();
  }
  async function forceDelete(id: string) {
    if (!confirm("Delete this community? This cannot be undone.")) return;
    await api.delete(`/v1/admin/communities/${id}`);
    await refetch();
  }

  // State for managing community members
  const [managingMembers, setManagingMembers] = useState<Community | null>(null);
  const [members, setMembers] = useState<CommunityMember[]>([]);
  const [membersLoading, setMembersLoading] = useState(false);
  const [banReason, setBanReason] = useState("");
  const [showBanModal, setShowBanModal] = useState(false);
  const [communityToBan, setCommunityToBan] = useState<Community | null>(null);

  // Edit modal state
  const [editing, setEditing] = useState<Community | null>(null);
  const [nameEdit, setNameEdit] = useState<string>("");
  const [descEdit, setDescEdit] = useState<string>("");
  const [categoryEdit, setCategoryEdit] = useState<string>("GENERAL");
  const [typeEdit, setTypeEdit] = useState<string>("PUBLIC");
  const [locationEdit, setLocationEdit] = useState<string>("");
  const [files, setFiles] = useState<FileList | null>(null);
  const [existingMedia, setExistingMedia] = useState<{ key: string; url: string }[]>([]);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [bannerFile, setBannerFile] = useState<File | null>(null);
  const [loadingMedia, setLoadingMedia] = useState<boolean>(false);

  function openEdit(c: Community) {
    setEditing(c);
    setNameEdit(c.name || "");
    setDescEdit(c.description || "");
    setCategoryEdit(c.category || "GENERAL");
    setTypeEdit(c.type || "PUBLIC");
    setVisibilityEdit(c.visibility || "OPEN");
    setRequiresApprovalEdit(c.requiresApproval || false);
    setLocationEdit("");
    loadCommunityDetails(c.id);
  }

  async function loadCommunityDetails(id: string) {
    try {
      setLoadingMedia(true);
      const res = await api.get<any>(`/v1/communities/${id}`);
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
    // Upload avatar/banner if provided
    let avatarKey: string | undefined = undefined;
    let bannerKey: string | undefined = undefined;
    if (avatarFile) {
      const name = avatarFile.name.toLowerCase();
      const ext = name.endsWith('.png') ? 'png' : (name.endsWith('.jpg') || name.endsWith('.jpeg')) ? 'jpg' : 'bin';
      const contentType = ext === 'png' ? 'image/png' : ext === 'jpg' ? 'image/jpeg' : avatarFile.type || 'application/octet-stream';
      const up = await api.post('/v1/storage/upload-url', { domain: 'communities', ext, contentType });
      const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
      await axios.put(uploadUrl, avatarFile, { headers: { 'Content-Type': contentType } });
      avatarKey = key;
    }
    if (bannerFile) {
      const name = bannerFile.name.toLowerCase();
      const ext = name.endsWith('.png') ? 'png' : (name.endsWith('.jpg') || name.endsWith('.jpeg')) ? 'jpg' : 'bin';
      const contentType = ext === 'png' ? 'image/png' : ext === 'jpg' ? 'image/jpeg' : bannerFile.type || 'application/octet-stream';
      const up = await api.post('/v1/storage/upload-url', { domain: 'communities', ext, contentType });
      const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
      await axios.put(uploadUrl, bannerFile, { headers: { 'Content-Type': contentType } });
      bannerKey = key;
    }
    // Upload additional media
    if (files && files.length > 0) {
      for (let i = 0; i < files.length; i++) {
        const f = files[i];
        const name = f.name.toLowerCase();
        const ext = name.endsWith('.png') ? 'png' : (name.endsWith('.jpg') || name.endsWith('.jpeg')) ? 'jpg' : 'bin';
        const contentType = ext === 'png' ? 'image/png' : ext === 'jpg' ? 'image/jpeg' : f.type || 'application/octet-stream';
        const up = await api.post('/v1/storage/upload-url', { domain: 'communities', ext, contentType });
        const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
        await axios.put(uploadUrl, f, { headers: { 'Content-Type': contentType } });
        mediaKeys.push(key);
      }
    }
    await api.patch(`/v1/admin/communities/${editing.id}`, {
      name: nameEdit,
      description: descEdit || undefined,
      category: categoryEdit,
      type: typeEdit,
      visibility: visibilityEdit,
      requiresApproval: requiresApprovalEdit,
      location: locationEdit || undefined,
      mediaKeys: mediaKeys.length > 0 ? mediaKeys : undefined,
      avatarKey: avatarKey,
      bannerKey: bannerKey,
    });
    setEditing(null);
    await refetch();
  }

  function cancelEdit() {
    setEditing(null);
  }

  const typeOptions = [
    { value: "all", label: "All Types" },
    { value: "public", label: "Public" },
    { value: "private", label: "Private" },
    { value: "restricted", label: "Restricted" },
  ];

  // Load community members
  async function loadCommunityMembers(community: Community) {
    try {
      setMembersLoading(true);
      setManagingMembers(community);
      const res = await api.get<{ items: CommunityMember[] }>(`/v1/admin/communities/${community.id}/members`);
      setMembers(res.data.items);
    } catch (error) {
      console.error("Failed to load community members:", error);
    } finally {
      setMembersLoading(false);
    }
  }

  // Close members modal
  function closeMembersModal() {
    setManagingMembers(null);
    setMembers([]);
  }

  // Ban a community
  function openBanCommunityModal(community: Community) {
    setCommunityToBan(community);
    setBanReason("");
    setShowBanModal(true);
  }

  async function banCommunity() {
    if (!communityToBan) return;
    try {
      await api.put(`/v1/admin/communities/${communityToBan.id}/ban`, { reason: banReason });
      await refetch();
      setShowBanModal(false);
      setCommunityToBan(null);
    } catch (error) {
      console.error("Failed to ban community:", error);
    }
  }

  // Unban a community
  async function unbanCommunity(communityId: string) {
    try {
      await api.put(`/v1/admin/communities/${communityId}/unban`);
      await refetch();
    } catch (error) {
      console.error("Failed to unban community:", error);
    }
  }

  // Ban a member from a community
  async function banMember(communityId: string, memberId: string) {
    const reason = prompt("Enter reason for banning this member:");
    if (!reason) return;
    
    try {
      await api.post(`/v1/admin/communities/${communityId}/members/${memberId}/ban`, { reason });
      // Reload members
      if (managingMembers) {
        loadCommunityMembers(managingMembers);
      }
    } catch (error) {
      console.error("Failed to ban member:", error);
    }
  }

  // Unban a member from a community
  async function unbanMember(communityId: string, memberId: string) {
    try {
      await api.post(`/v1/admin/communities/${communityId}/members/${memberId}/unban`);
      // Reload members
      if (managingMembers) {
        loadCommunityMembers(managingMembers);
      }
    } catch (error) {
      console.error("Failed to unban member:", error);
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Communities"
        breadcrumb={[{ label: "Home", href: "/dashboard" }, { label: "Communities" }]}
        actions={
          <div className="flex items-center gap-2">
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="px-3 py-2 text-sm rounded border focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              {typeOptions.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
            <input
              value={qLocal}
              onChange={(e) => setQLocal(e.target.value)}
              onBlur={() => setUrlState({ q: qLocal, page: 1 })}
              placeholder="Search communities…"
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
            <div className="text-2xl font-bold text-gray-900">{stats.totalCommunities}</div>
            <div className="text-sm text-gray-500">Total Communities</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-green-600">{stats.activeCommunities}</div>
            <div className="text-sm text-gray-500">Active</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-blue-600">{stats.publicCommunities}</div>
            <div className="text-sm text-gray-500">Public</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-red-600">{stats.privateCommunities}</div>
            <div className="text-sm text-gray-500">Private</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-purple-600">{stats.totalMembers.toLocaleString()}</div>
            <div className="text-sm text-gray-500">Total Members</div>
          </div>
          <div className="bg-white p-4 rounded-lg shadow border">
            <div className="text-2xl font-bold text-indigo-600">{stats.totalPosts.toLocaleString()}</div>
            <div className="text-sm text-gray-500">Total Posts</div>
          </div>
          {stats.totalEvents !== undefined && (
            <div className="bg-white p-4 rounded-lg shadow border">
              <div className="text-2xl font-bold text-teal-600">{stats.totalEvents.toLocaleString()}</div>
              <div className="text-sm text-gray-500">Total Events</div>
            </div>
          )}
          {stats.totalPolls !== undefined && (
            <div className="bg-white p-4 rounded-lg shadow border">
              <div className="text-2xl font-bold text-purple-600">{stats.totalPolls.toLocaleString()}</div>
              <div className="text-sm text-gray-500">Total Polls</div>
            </div>
          )}
          {stats.totalReports !== undefined && (
            <div className="bg-white p-4 rounded-lg shadow border">
              <div className="text-2xl font-bold text-red-600">{stats.totalReports.toLocaleString()}</div>
              <div className="text-sm text-gray-500">Pending Reports</div>
            </div>
          )}
        </div>
      )}

      <Table
        columns={columns}
        data={rows as any}
        loading={isLoading}
        error={isError && "Failed to load communities"}
        emptyLabel="No communities found"
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
            <h3 className="text-lg font-semibold mb-4">Edit Community</h3>
            <div className="space-y-3">
              <div>
                <label className="block text-sm font-medium">Name</label>
                <input className="mt-1 w-full border rounded px-3 py-2" value={nameEdit} onChange={(e) => setNameEdit(e.target.value)} />
              </div>
              <div>
                <label className="block text-sm font-medium">Description</label>
                <textarea className="mt-1 w-full border rounded px-3 py-2" rows={3} value={descEdit} onChange={(e) => setDescEdit(e.target.value)} />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium">Category</label>
                  <select className="mt-1 w-full border rounded px-3 py-2" value={categoryEdit} onChange={(e) => setCategoryEdit(e.target.value)}>
                    {['GENERAL','TECHNOLOGY','BUSINESS','ARTS','SPORTS','EDUCATION','HEALTH','TRAVEL','FOOD','GAMING','MUSIC','BOOKS','SCIENCE','SOCIAL_IMPACT','ENVIRONMENT','OTHERS'].map(opt => (<option key={opt} value={opt}>{opt.replace('_',' ')}</option>))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium">Type</label>
                  <select className="mt-1 w-full border rounded px-3 py-2" value={typeEdit} onChange={(e) => setTypeEdit(e.target.value)}>
                    {['PUBLIC','PRIVATE','REGIONAL','INTEREST_BASED','SKILL_SHARING','IMPACT_FOCUSED','INVITE_ONLY'].map(opt => (<option key={opt} value={opt}>{opt.replace('_',' ')}</option>))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium">Visibility</label>
                  <select className="mt-1 w-full border rounded px-3 py-2" value={visibilityEdit} onChange={(e) => setVisibilityEdit(e.target.value)}>
                    {['OPEN','CLOSED','SECRET'].map(opt => (<option key={opt} value={opt}>{opt}</option>))}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium">
                  <input type="checkbox" checked={requiresApprovalEdit} onChange={(e) => setRequiresApprovalEdit(e.target.checked)} className="mr-2" />
                  Requires Approval
                </label>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-sm font-medium">Location</label>
                  <input className="mt-1 w-full border rounded px-3 py-2" value={locationEdit} onChange={(e) => setLocationEdit(e.target.value)} />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium">Avatar</label>
                <input type="file" accept="image/*" onChange={(e) => setAvatarFile(e.target.files?.[0] || null)} />
              </div>
              <div>
                <label className="block text-sm font-medium">Banner</label>
                <input type="file" accept="image/*" onChange={(e) => setBannerFile(e.target.files?.[0] || null)} />
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

      {/* Ban Community Modal */}
      {showBanModal && communityToBan && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-md p-6">
            <h3 className="text-lg font-semibold mb-4">Ban Community</h3>
            <p className="mb-4">Are you sure you want to ban the community "{communityToBan.name}"?</p>
            <div className="mb-4">
              <label className="block text-sm font-medium mb-1">Reason for banning</label>
              <textarea
                className="w-full border rounded px-3 py-2"
                rows={3}
                value={banReason}
                onChange={(e) => setBanReason(e.target.value)}
                placeholder="Enter reason for banning this community..."
              />
            </div>
            <div className="flex items-center justify-end gap-2">
              <button 
                className="px-3 py-2 text-sm rounded border" 
                onClick={() => setShowBanModal(false)}
              >
                Cancel
              </button>
              <button 
                className="px-3 py-2 text-sm rounded bg-red-600 text-white" 
                onClick={banCommunity}
                disabled={!banReason.trim()}
              >
                Ban Community
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Manage Members Modal */}
      {managingMembers && (
        <div className="fixed inset-0 bg-black/30 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-4xl h-[80vh] flex flex-col">
            <div className="p-6 border-b">
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-semibold">
                  Manage Members: {managingMembers.name}
                </h3>
                <button 
                  className="text-gray-500 hover:text-gray-700"
                  onClick={closeMembersModal}
                >
                  ✕
                </button>
              </div>
            </div>
            
            <div className="flex-1 overflow-auto p-6">
              {membersLoading ? (
                <div className="flex justify-center items-center h-32">
                  <p>Loading members...</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Joined</th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {members.map((member) => (
                        <tr key={member.id}>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="flex-shrink-0 h-10 w-10">
                                <div className="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center">
                                  <span className="text-gray-600">
                                    {(member.user.profile?.displayName || member.user.email || "?")[0].toUpperCase()}
                                  </span>
                                </div>
                              </div>
                              <div className="ml-4">
                                <div className="text-sm font-medium text-gray-900">
                                  {member.user.profile?.displayName || "Unknown User"}
                                </div>
                                <div className="text-sm text-gray-500">
                                  {member.user.email}
                                </div>
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              member.role === 'OWNER' ? 'bg-purple-100 text-purple-800' :
                              member.role === 'ADMIN' ? 'bg-blue-100 text-blue-800' :
                              member.role === 'MODERATOR' ? 'bg-yellow-100 text-yellow-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {member.role}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                              member.status === 'ACTIVE' ? 'bg-green-100 text-green-800' :
                              member.status === 'BANNED' ? 'bg-red-100 text-red-800' :
                              'bg-gray-100 text-gray-800'
                            }`}>
                              {member.status}
                            </span>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {new Date(member.joinedAt).toLocaleDateString()}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                            {member.status === 'BANNED' ? (
                              <button
                                onClick={() => unbanMember(managingMembers.id, member.id)}
                                className="text-green-600 hover:text-green-900"
                              >
                                Unban
                              </button>
                            ) : (
                              <button
                                onClick={() => banMember(managingMembers.id, member.id)}
                                className="text-red-600 hover:text-red-900"
                              >
                                Ban
                              </button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  
                  {members.length === 0 && (
                    <div className="text-center py-8 text-gray-500">
                      No members found in this community.
                    </div>
                  )}
                </div>
              )}
            </div>
            
            <div className="p-6 border-t flex justify-end">
              <button 
                className="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
                onClick={closeMembersModal}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
