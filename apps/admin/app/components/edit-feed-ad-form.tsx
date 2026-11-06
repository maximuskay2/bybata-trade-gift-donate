"use client";

import React, { useEffect, useMemo, useState } from "react";
import axios from "axios";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";

type Placement = { id: string; key: string; title: string; active: boolean };

type AdDetail = {
  id: string;
  title: string;
  description?: string | null;
  status: string;
  mediaType?: string;
  mediaKeys?: string[];
  videoKey?: string | null;
  placementKey?: string | null;
  placementKeys?: string[];
  destinationUrl?: string | null;
  scheduledStart: string;
  scheduledEnd?: string | null;
};

const EDITABLE = new Set([
  "PENDING_REVIEW",
  "REJECTED",
  "SCHEDULED",
  "PAUSED",
  "ACTIVE",
]);

async function uploadMediaFile(file: File): Promise<string> {
  const name = file.name.toLowerCase();
  let ext = "bin";
  let contentType = file.type || "application/octet-stream";
  if (name.endsWith(".png")) {
    ext = "png";
    contentType = "image/png";
  } else if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
    ext = "jpg";
    contentType = "image/jpeg";
  } else if (name.endsWith(".mp4")) {
    ext = "mp4";
    contentType = "video/mp4";
  } else if (name.endsWith(".mov")) {
    ext = "mov";
    contentType = "video/quicktime";
  }
  const up = await api.post("/v1/storage/upload-url", { domain: "ads", ext, contentType });
  const { uploadUrl, key } = up.data as { uploadUrl: string; key: string };
  await axios.put(uploadUrl, file, { headers: { "Content-Type": contentType } });
  return key;
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-sm font-semibold text-gray-800 mb-2">{label}</h2>
      {children}
    </div>
  );
}

export default function EditFeedAdForm({ adId }: { adId: string }) {
  const router = useRouter();
  const [ad, setAd] = useState<AdDetail | null>(null);
  const [placements, setPlacements] = useState<Placement[]>([]);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [destinationUrl, setDestinationUrl] = useState("");
  const [mediaMode, setMediaMode] = useState<"IMAGE" | "VIDEO">("IMAGE");
  const [existingMediaKeys, setExistingMediaKeys] = useState<string[]>([]);
  const [existingVideoKey, setExistingVideoKey] = useState<string | null>(null);
  const [newImageFiles, setNewImageFiles] = useState<File[]>([]);
  const [newVideoFile, setNewVideoFile] = useState<File | null>(null);
  const [selectedPlacements, setSelectedPlacements] = useState<Set<string>>(new Set());
  const [scheduledStart, setScheduledStart] = useState("");
  const [durationDays, setDurationDays] = useState(7);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const locksSchedule = ad?.status === "ACTIVE" || ad?.status === "PAUSED";
  const needsReReview =
    ad?.status === "REJECTED" ||
    ad?.status === "ACTIVE" ||
    ad?.status === "PAUSED" ||
    ad?.status === "SCHEDULED";

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        setError(null);
        const [adRes, plRes] = await Promise.all([
          api.get<AdDetail>(`/v1/admin/ads/schedules/${adId}`),
          api.get<Placement[]>("/v1/admin/ad-placements"),
        ]);
        const row = adRes.data;
        if (!EDITABLE.has(row.status)) {
          setError(`This ad cannot be edited (status: ${row.status})`);
          setAd(row);
          return;
        }
        setAd(row);
        setTitle(row.title);
        setDescription(row.description ?? "");
        setDestinationUrl(row.destinationUrl ?? "");
        setMediaMode((row.mediaType === "VIDEO" ? "VIDEO" : "IMAGE") as "IMAGE" | "VIDEO");
        setExistingMediaKeys(row.mediaKeys ?? []);
        setExistingVideoKey(row.videoKey ?? null);
        const keys = row.placementKeys?.length
          ? row.placementKeys
          : row.placementKey
            ? [row.placementKey]
            : [];
        setSelectedPlacements(new Set(keys));
        const start = new Date(row.scheduledStart);
        setScheduledStart(start.toISOString().slice(0, 16));
        if (row.scheduledEnd) {
          const end = new Date(row.scheduledEnd);
          const days = Math.max(
            1,
            Math.round((end.getTime() - start.getTime()) / (24 * 60 * 60 * 1000)),
          );
          setDurationDays(days);
        }
        setPlacements((plRes.data || []).filter((p) => p.active));
      } catch (e: any) {
        setError(e?.response?.data?.message || e.message);
      } finally {
        setLoading(false);
      }
    })();
  }, [adId]);

  const banner = useMemo(() => {
    if (!ad) return null;
    if (locksSchedule) {
      return "Live or paused — edit copy, link, and media only. Schedule and placements are locked.";
    }
    if (needsReReview) {
      return "Saving sends this ad back to Ads Review before it can run again.";
    }
    return null;
  }, [ad, locksSchedule, needsReReview]);

  function togglePlacement(key: string) {
    setSelectedPlacements((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  function onMediaModeChange(mode: "IMAGE" | "VIDEO") {
    setMediaMode(mode);
    if (mode === "IMAGE") {
      setNewVideoFile(null);
      setExistingVideoKey(null);
    } else {
      setNewImageFiles([]);
      setExistingMediaKeys([]);
    }
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!ad) return;
    setError(null);
    setSuccess(null);

    if (!title.trim()) {
      setError("Title is required");
      return;
    }
    if (!destinationUrl.trim().match(/^https?:\/\//i)) {
      setError("Destination URL must start with http:// or https://");
      return;
    }
    if (!locksSchedule && selectedPlacements.size === 0) {
      setError("Select at least one placement");
      return;
    }

    if (mediaMode === "VIDEO") {
      const hasVideo = newVideoFile || existingVideoKey;
      if (!hasVideo) {
        setError("A video is required for video ads");
        return;
      }
    } else {
      const total = existingMediaKeys.length + newImageFiles.length;
      if (total === 0) {
        setError("At least one image is required");
        return;
      }
    }

    setSaving(true);
    try {
      let mediaKeys: string[] | undefined;
      let videoKey: string | null | undefined;

      if (mediaMode === "VIDEO") {
        if (newVideoFile) {
          videoKey = await uploadMediaFile(newVideoFile);
        } else {
          videoKey = existingVideoKey;
        }
        mediaKeys = [];
      } else {
        videoKey = null;
        const uploaded: string[] = [];
        for (const f of newImageFiles.slice(0, 5 - existingMediaKeys.length)) {
          uploaded.push(await uploadMediaFile(f));
        }
        mediaKeys = [...existingMediaKeys, ...uploaded];
      }

      const body: Record<string, unknown> = {
        title: title.trim(),
        description: description.trim() || undefined,
        mediaType: mediaMode,
        mediaKeys,
        videoKey,
        destinationUrl: destinationUrl.trim(),
      };

      if (!locksSchedule) {
        const start = new Date(scheduledStart);
        if (Number.isNaN(start.getTime())) {
          setError("Invalid start date");
          return;
        }
        const end = new Date(start.getTime() + durationDays * 24 * 60 * 60 * 1000);
        body.placementKeys = Array.from(selectedPlacements);
        body.scheduledStart = start.toISOString();
        body.scheduledEnd = end.toISOString();
      }

      const res = await api.patch(`/v1/admin/ads/schedules/${adId}`, body);
      setSuccess(
        `Ad updated (status: ${res.data?.status ?? "saved"}).${
          res.data?.status === "PENDING_REVIEW" ? " Review it on Ads Review." : ""
        }`,
      );
      setTimeout(() => router.push("/ads"), 1200);
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return <p className="text-gray-500 text-sm py-8">Loading ad…</p>;
  }

  if (!ad) {
    return (
      <p className="text-red-600 text-sm">
        {error || "Ad not found"}
        <Link href="/ads" className="block mt-4 text-indigo-600 underline">
          ← Back to all ads
        </Link>
      </p>
    );
  }

  if (!EDITABLE.has(ad.status)) {
    return (
      <div>
        <p className="text-red-600 text-sm mb-4">
          Cannot edit ads with status <strong>{ad.status}</strong>.
        </p>
        <Link href="/ads" className="text-indigo-600 underline text-sm">
          ← Back to all ads
        </Link>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="space-y-6 max-w-3xl">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <Link href="/ads" className="text-indigo-600 underline">
          ← All ads
        </Link>
        <span className="text-gray-400">·</span>
        <span className="font-mono text-xs text-gray-500">{ad.id}</span>
        <span className="px-2 py-0.5 rounded bg-gray-100 text-xs font-semibold">{ad.status}</span>
      </div>

      {banner && (
        <p className="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-lg px-4 py-3">
          {banner}
        </p>
      )}

      <Section label="Creative">
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Ad title"
          className="w-full border px-3 py-2 rounded"
          maxLength={80}
        />
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Description (optional)"
          className="w-full border px-3 py-2 rounded mt-2"
          rows={3}
          maxLength={200}
        />
        <input
          value={destinationUrl}
          onChange={(e) => setDestinationUrl(e.target.value)}
          placeholder="https://destination-url.com"
          className="w-full border px-3 py-2 rounded mt-2"
        />
      </Section>

      <Section label="Media (images OR video)">
        <div className="flex gap-2 mb-3">
          <button
            type="button"
            onClick={() => onMediaModeChange("IMAGE")}
            className={`px-3 py-1.5 rounded text-sm ${mediaMode === "IMAGE" ? "bg-indigo-600 text-white" : "border"}`}
          >
            Images
          </button>
          <button
            type="button"
            onClick={() => onMediaModeChange("VIDEO")}
            className={`px-3 py-1.5 rounded text-sm ${mediaMode === "VIDEO" ? "bg-indigo-600 text-white" : "border"}`}
          >
            Video
          </button>
        </div>
        {mediaMode === "IMAGE" ? (
          <div className="space-y-2">
            {existingMediaKeys.length > 0 && (
              <ul className="text-xs text-gray-600 border rounded p-2 bg-gray-50">
                {existingMediaKeys.map((k, i) => (
                  <li key={k} className="flex justify-between gap-2 py-1">
                    <span className="truncate font-mono">{k}</span>
                    <button
                      type="button"
                      className="text-red-600 shrink-0"
                      onClick={() =>
                        setExistingMediaKeys((prev) => prev.filter((_, j) => j !== i))
                      }
                    >
                      Remove
                    </button>
                  </li>
                ))}
              </ul>
            )}
            <input
              type="file"
              accept="image/*"
              multiple
              onChange={(e) => {
                const picked = Array.from(e.target.files || []);
                const max = 5 - existingMediaKeys.length;
                setNewImageFiles((prev) => [...prev, ...picked].slice(0, max));
                e.target.value = "";
              }}
            />
            {newImageFiles.length > 0 && (
              <ul className="text-xs text-gray-600">
                {newImageFiles.map((f, i) => (
                  <li key={i} className="flex justify-between">
                    <span>{f.name} (new)</span>
                    <button
                      type="button"
                      className="text-red-600"
                      onClick={() => setNewImageFiles((prev) => prev.filter((_, j) => j !== i))}
                    >
                      Remove
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        ) : (
          <div className="space-y-2">
            {existingVideoKey && !newVideoFile && (
              <p className="text-xs text-gray-600 flex justify-between border rounded p-2 bg-gray-50">
                <span className="font-mono truncate">{existingVideoKey}</span>
                <button type="button" className="text-red-600" onClick={() => setExistingVideoKey(null)}>
                  Remove
                </button>
              </p>
            )}
            <input
              type="file"
              accept="video/mp4,video/quicktime,.mp4,.mov"
              onChange={(e) => {
                setNewVideoFile(e.target.files?.[0] ?? null);
                if (e.target.files?.[0]) setExistingVideoKey(null);
              }}
            />
            {newVideoFile && (
              <p className="text-xs text-gray-600">
                New: {newVideoFile.name}{" "}
                <button type="button" className="text-red-600 ml-2" onClick={() => setNewVideoFile(null)}>
                  Remove
                </button>
              </p>
            )}
          </div>
        )}
      </Section>

      {!locksSchedule && (
        <>
          <Section label="Placements">
            <div className="flex flex-wrap gap-2">
              {placements.map((p) => {
                const selected = selectedPlacements.has(p.key);
                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => togglePlacement(p.key)}
                    className={`px-3 py-2 rounded-lg border text-sm ${
                      selected ? "bg-indigo-100 border-indigo-400 text-indigo-900" : "bg-white border-gray-200"
                    }`}
                  >
                    {p.title}
                  </button>
                );
              })}
            </div>
          </Section>

          <Section label="Schedule">
            <div className="flex flex-wrap gap-4">
              <label className="text-sm">
                Start
                <input
                  type="datetime-local"
                  value={scheduledStart}
                  onChange={(e) => setScheduledStart(e.target.value)}
                  className="block border px-3 py-2 rounded mt-1"
                />
              </label>
              <label className="text-sm">
                Duration (days)
                <select
                  value={durationDays}
                  onChange={(e) => setDurationDays(Number(e.target.value))}
                  className="block border px-3 py-2 rounded mt-1"
                >
                  <option value={3}>3</option>
                  <option value={7}>7</option>
                  <option value={14}>14</option>
                  <option value={30}>30</option>
                </select>
              </label>
            </div>
          </Section>
        </>
      )}

      {error && <p className="text-red-600 text-sm">{error}</p>}
      {success && <p className="text-green-700 text-sm">{success}</p>}

      <div className="flex gap-3">
        <button
          type="submit"
          disabled={saving}
          className="bg-indigo-600 text-white px-6 py-2 rounded-lg disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
        <Link href="/ads" className="px-6 py-2 rounded-lg border text-gray-700 text-sm font-medium">
          Cancel
        </Link>
      </div>
    </form>
  );
}


