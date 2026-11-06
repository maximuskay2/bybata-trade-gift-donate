"use client";
import React from "react";
import Link from "next/link";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import axios from "axios";
import PageHeader from "@/app/components/page-header";
import Button from "@/app/components/ui/button";
import { useToast } from "@/app/components/ui/toast";
import Badge from "@/app/components/ui/badge";
import { useParams } from "next/navigation";

export default function UserDetail() {
  const params = useParams<{ id: string }>();
  const id = (params?.id as string) || "";
  const qc = useQueryClient();
  const { push } = useToast();
  const [localPreview, setLocalPreview] = React.useState<string | null>(null);
  const { data, isLoading } = useQuery({
    queryKey: ["user", id],
    queryFn: async () => {
      if (!id) return null;
      try {
        const res = await api.get(`/v1/admin/users/${id}`);
        return res.data as any;
      } catch {
        return null;
      }
    },
    enabled: !!id,
  });

  const mutation = useMutation({
    mutationFn: async (payload: any) => {
      const res = await api.patch(`/v1/admin/users/${id}`, payload);
      return res.data;
    },
    onSuccess: async () => {
      await qc.invalidateQueries({ queryKey: ["user", id] });
      push({ title: "Saved", variant: "success" });
    },
    onError: () => {
      push({ title: "Update failed", variant: "error" });
    },
  });

  return (
    <div className="space-y-4">
      <PageHeader
        title="User details"
        breadcrumb={[{ label: "Users", href: "/users" }, { label: id }]}
      />

      {isLoading && <div>Loading…</div>}
      {!isLoading && !data && (
        <div className="p-4 bg-white rounded border text-gray-500">User not found or endpoint not yet available.</div>
      )}
      {data && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div className="p-4 bg-white rounded border space-y-2">
            <h2 className="font-semibold">Profile</h2>
            {/* Activity stats */}
            <div className="grid grid-cols-2 gap-2 py-2 border-t border-b">
              <div className="text-sm">
                <span className="text-gray-500">Trades:</span>{" "}
                <span className="font-medium">{data._count?.trades ?? 0}</span>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Gifts:</span>{" "}
                <span className="font-medium">{data._count?.giftsGiven ?? 0}</span>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Campaigns:</span>{" "}
                <span className="font-medium">{data._count?.campaignsFounded ?? 0}</span>
              </div>
              <div className="text-sm">
                <span className="text-gray-500">Donations:</span>{" "}
                <span className="font-medium">{data._count?.donations ?? 0}</span>
              </div>
            </div>
            {localPreview ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={localPreview} alt="avatar" className="w-20 h-20 rounded-full object-cover border" />
            ) : data.profile?.avatarKey ? (
              <AvatarPreview avatarKey={data.profile.avatarKey} />
            ) : (
              <div className="text-xs text-gray-500">No avatar</div>
            )}
            <div className="text-sm flex items-center gap-2">Email: {data.email} {data.emailVerifiedAt ? <Badge color="green">Verified</Badge> : <Badge color="red">Unverified</Badge>}</div>
            <div className="text-sm">Role: {data.role}</div>
            <div className="text-sm">Display name: {data.profile?.displayName ?? "-"}</div>
            {data.communityMemberships && data.communityMemberships.length > 0 && (
              <div className="pt-2 border-t">
                <h3 className="text-sm font-medium text-gray-600 mb-1">Communities ({data.communityMemberships.length})</h3>
                <ul className="text-sm space-y-1">
                  {data.communityMemberships.map((m: { community: { id: string; name: string } }) => (
                    <li key={m.community.id}>
                      <Link
                        href={`/communities?q=${encodeURIComponent(m.community.name)}`}
                        className="text-indigo-600 hover:underline"
                      >
                        {m.community.name}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
          <div className="p-4 bg-white rounded border space-y-4 lg:col-span-2">
            <h2 className="font-semibold">Admin actions</h2>

            <div className="space-y-2">
              <label className="text-sm text-gray-600">Avatar</label>
              <div className="flex items-center gap-2">
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    try {
                      // client-side preview
                      const url = URL.createObjectURL(file);
                      setLocalPreview((prev) => {
                        if (prev) URL.revokeObjectURL(prev);
                        return url;
                      });
                      // infer ext and content type
                      const name = file.name.toLowerCase();
                      const ext = name.endsWith('.png') ? 'png' : name.endsWith('.jpeg') || name.endsWith('.jpg') ? 'jpg' : 'jpg';
                      const contentType = file.type || (ext === 'png' ? 'image/png' : 'image/jpeg');

                      let key: string | null = null;
                      const preferServerUpload = process.env.NODE_ENV !== 'production';
                      if (preferServerUpload) {
                        // In development, avoid browser CORS issues by using server-side upload first
                        const form = new FormData();
                        form.append('file', file);
                        form.append('domain', 'profiles');
                        const resp = await api.post('/v1/storage/upload', form, { headers: { 'Content-Type': 'multipart/form-data' } });
                        key = (resp.data as any)?.key as string;
                      } else {
                        // In production, try presigned upload first, then fall back to server-side if needed
                        try {
                          const up = await api.post('/v1/storage/upload-url', { domain: 'profiles', ext, contentType });
                          const { key: k, uploadUrl } = up.data as { key: string; uploadUrl: string };
                          await axios.put(uploadUrl, file, { headers: { 'Content-Type': contentType } });
                          key = k;
                        } catch (_) {
                          const form = new FormData();
                          form.append('file', file);
                          form.append('domain', 'profiles');
                          const resp = await api.post('/v1/storage/upload', form, { headers: { 'Content-Type': 'multipart/form-data' } });
                          key = (resp.data as any)?.key as string;
                        }
                      }

                      if (key) {
                        await api.patch(`/v1/admin/users/${id}`, { avatarKey: key });
                        await qc.invalidateQueries({ queryKey: ["user", id] });
                      }
                    } catch (err) {
                      // ignore
                    } finally {
                      if (e.target) e.target.value = '';
                    }
                  }}
                />
                <Button
                  variant="secondary"
                  onClick={async () => {
                    try {
                      await api.patch(`/v1/admin/users/${id}`, { avatarKey: null });
                      await qc.invalidateQueries({ queryKey: ["user", id] });
                    } catch {}
                  }}
                >Remove</Button>
              </div>
            </div>

            {/* Quick actions */}
            <div className="flex items-center gap-2 flex-wrap">
              <Link href={`/notifications/new?userId=${id}`}>
                <Button variant="secondary">Send notification</Button>
              </Link>
              <Link href={`/chat?userId=${id}`}>
                <Button variant="secondary">View chat</Button>
              </Link>
              <Button
                variant="secondary"
                onClick={async () => {
                  try {
                    await api.post('/v1/auth/verify-request', { email: data.email });
                    push({ title: 'Verification email sent', variant: 'success' });
                  } catch {
                    push({ title: 'Failed to send verification email', variant: 'error' });
                  }
                }}
              >Send verification email</Button>
              <Button
                variant="secondary"
                onClick={async () => {
                  try {
                    await api.post('/v1/auth/forgot', { email: data.email });
                    push({ title: 'Password reset email sent', variant: 'success' });
                  } catch {
                    push({ title: 'Failed to send reset email', variant: 'error' });
                  }
                }}
              >Send reset email</Button>
              {data.emailVerifiedAt ? (
                <Button
                  variant="secondary"
                  onClick={async () => {
                    try {
                      await api.patch(`/v1/admin/users/${id}`, { verifyEmail: false });
                      await qc.invalidateQueries({ queryKey: ["user", id] });
                      push({ title: 'Email marked unverified', variant: 'success' });
                    } catch {
                      push({ title: 'Failed to unverify email', variant: 'error' });
                    }
                  }}
                >Mark unverified</Button>
              ) : (
                <Button
                  variant="secondary"
                  onClick={async () => {
                    try {
                      await api.patch(`/v1/admin/users/${id}`, { verifyEmail: true });
                      await qc.invalidateQueries({ queryKey: ["user", id] });
                      push({ title: 'Email marked verified', variant: 'success' });
                    } catch {
                      push({ title: 'Failed to verify email', variant: 'error' });
                    }
                  }}
                >Mark verified</Button>
              )}
            </div>

            <form
              className="grid grid-cols-1 md:grid-cols-2 gap-4"
              onSubmit={(e) => {
                e.preventDefault();
                const fd = new FormData(e.currentTarget as HTMLFormElement);
                const payload: any = {};
                const role = fd.get("role") as string;
                const kycStatus = fd.get("kycStatus") as string;
                const kycNote = (fd.get("kycNote") as string) ?? undefined;
                const ban = fd.get("ban") === "on";
                if (role) payload.role = role;
                if (kycStatus) payload.kycStatus = kycStatus;
                payload.kycNote = kycNote;
                payload.ban = ban;
                mutation.mutate(payload);
              }}
            >
              <div className="space-y-1">
                <label className="text-sm text-gray-600">Role</label>
                <select name="role" defaultValue={data.role} className="rounded border px-2 py-2 text-sm">
                  <option value="USER">USER</option>
                  <option value="MODERATOR">MODERATOR</option>
                  <option value="ADMIN">ADMIN</option>
                </select>
              </div>
              <div className="space-y-1">
                <label className="text-sm text-gray-600">KYC status</label>
                <select name="kycStatus" defaultValue={data.profile?.kycStatus ?? "NOT_VERIFIED"} className="rounded border px-2 py-2 text-sm">
                  <option value="NOT_VERIFIED">NOT_VERIFIED</option>
                  <option value="PENDING">PENDING</option>
                  <option value="VERIFIED">VERIFIED</option>
                  <option value="REJECTED">REJECTED</option>
                </select>
              </div>
              <div className="md:col-span-2 space-y-1">
                <label className="text-sm text-gray-600">KYC note</label>
                <textarea name="kycNote" defaultValue={data.profile?.kycNote ?? ""} className="rounded border px-2 py-2 text-sm w-full min-h-[80px]" />
              </div>
              <div className="flex items-center gap-2">
                <input id="ban" name="ban" type="checkbox" defaultChecked={!!data.banned} />
                <label htmlFor="ban" className="text-sm text-gray-700">Banned</label>
              </div>
              <div className="md:col-span-2 flex items-center gap-2">
                <Button type="submit" disabled={mutation.isPending}>
                  {mutation.isPending ? "Saving…" : "Save changes"}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function AvatarPreview({ avatarKey }: { avatarKey: string }) {
  const [url, setUrl] = React.useState<string | null>(null);
  React.useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await api.get('/v1/storage/download-url', { params: { key: avatarKey } });
        if (!cancelled) setUrl(res.data?.url);
      } catch {}
    })();
    return () => { cancelled = true; };
  }, [avatarKey]);
  return (
    <div className="my-2">
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt="avatar" className="w-20 h-20 rounded-full object-cover border" />
      ) : (
        <div className="w-20 h-20 rounded-full bg-gray-100 border" />
      )}
    </div>
  );
}
