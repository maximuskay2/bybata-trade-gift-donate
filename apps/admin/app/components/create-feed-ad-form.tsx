"use client";

import React, { useEffect, useMemo, useState } from "react";
import axios from "axios";
import { api } from "@/lib/api";
import Link from "next/link";

type Placement = { id: string; key: string; title: string; active: boolean };
type AdPricing = {
  tradeBycPerDay: number;
  giftBycPerDay: number;
  donationBycPerDay: number;
  normalBycPerDay: number;
};

function dailyRateForKey(key: string, pricing: AdPricing): number {
  const k = key.toLowerCase();
  if (k.includes("trade")) return pricing.tradeBycPerDay;
  if (k.includes("gift")) return pricing.giftBycPerDay;
  if (k.includes("donation") || k.includes("campaign")) return pricing.donationBycPerDay;
  return pricing.normalBycPerDay;
}

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

export default function CreateFeedAdForm() {
  const [placements, setPlacements] = useState<Placement[]>([]);
  const [pricing, setPricing] = useState<AdPricing>({
    tradeBycPerDay: 2.5,
    giftBycPerDay: 2,
    donationBycPerDay: 2,
    normalBycPerDay: 3,
  });
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [destinationUrl, setDestinationUrl] = useState("");
  const [mediaMode, setMediaMode] = useState<"IMAGE" | "VIDEO">("IMAGE");
  const [imageFiles, setImageFiles] = useState<File[]>([]);
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [selectedPlacements, setSelectedPlacements] = useState<Set<string>>(new Set());
  const [durationDays, setDurationDays] = useState(7);
  const [scheduledStart, setScheduledStart] = useState(() => {
    const d = new Date(Date.now() + 30 * 60 * 1000);
    return d.toISOString().slice(0, 16);
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const [plRes, prRes] = await Promise.all([
          api.get<Placement[]>("/v1/admin/ad-placements"),
          api.get<AdPricing>("/v1/admin/settings/ad-pricing"),
        ]);
        setPlacements((plRes.data || []).filter((p) => p.active));
        setPricing(prRes.data);
      } catch (e: any) {
        setError(e?.response?.data?.message || e.message);
      }
    })();
  }, []);

  const total = useMemo(() => {
    if (selectedPlacements.size === 0) return 0;
    let sum = 0;
    for (const key of selectedPlacements) {
      sum += dailyRateForKey(key, pricing) * durationDays;
    }
    return sum;
  }, [selectedPlacements, pricing, durationDays]);

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
    if (mode === "IMAGE") setVideoFile(null);
    else setImageFiles([]);
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
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
    if (selectedPlacements.size === 0) {
      setError("Select at least one placement");
      return;
    }
    const start = new Date(scheduledStart);
    if (Number.isNaN(start.getTime()) || start.getTime() <= Date.now()) {
      setError("Start time must be in the future");
      return;
    }
    if (mediaMode === "VIDEO" && !videoFile) {
      setError("Upload a video for video ads");
      return;
    }
    if (mediaMode === "IMAGE" && imageFiles.length === 0) {
      setError("Add at least one image, or switch to video mode");
      return;
    }

    setLoading(true);
    try {
      let mediaKeys: string[] | undefined;
      let videoKey: string | undefined;
      if (mediaMode === "VIDEO" && videoFile) {
        videoKey = await uploadMediaFile(videoFile);
      } else {
        mediaKeys = [];
        for (const f of imageFiles.slice(0, 5)) {
          mediaKeys.push(await uploadMediaFile(f));
        }
      }

      const end = new Date(start.getTime() + durationDays * 24 * 60 * 60 * 1000);
      const keys = Array.from(selectedPlacements);
      const res = await api.post("/v1/admin/ads/schedules", {
        title: title.trim(),
        description: description.trim() || undefined,
        mediaType: mediaMode,
        mediaKeys,
        videoKey,
        placementKey: keys[0],
        placementKeys: keys,
        scheduledStart: start.toISOString(),
        scheduledEnd: end.toISOString(),
        amount: total,
        destinationUrl: destinationUrl.trim(),
        idempotencyKey: `admin-ad-${Date.now()}`,
      });

      setSuccess(
        `Ad submitted for review (ID: ${res.data?.adScheduleId ?? "—"}). Approve it on Ads Review.`,
      );
      setTitle("");
      setDescription("");
      setDestinationUrl("");
      setImageFiles([]);
      setVideoFile(null);
      setSelectedPlacements(new Set());
    } catch (e: any) {
      setError(e?.response?.data?.message || e.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-6 max-w-3xl">
      <p className="text-sm text-gray-600">
        Creates a sponsored feed ad using your admin wallet balance. The ad enters{" "}
        <strong>PENDING_REVIEW</strong> — approve it on{" "}
        <Link href="/ads-review" className="text-indigo-600 underline">
          Ads Review
        </Link>{" "}
        (same queue as mobile user ads).
      </p>

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

      <Section label="Media (images OR video — not both)">
        <div className="flex gap-2 mb-3">
          <button
            type="button"
            onClick={() => onMediaModeChange("IMAGE")}
            className={`px-3 py-1.5 rounded text-sm ${mediaMode === "IMAGE" ? "bg-indigo-600 text-white" : "border"}`}
          >
            Images (up to 5)
          </button>
          <button
            type="button"
            onClick={() => onMediaModeChange("VIDEO")}
            className={`px-3 py-1.5 rounded text-sm ${mediaMode === "VIDEO" ? "bg-indigo-600 text-white" : "border"}`}
          >
            Video (one file)
          </button>
        </div>
        {mediaMode === "IMAGE" ? (
          <div>
            <input
              type="file"
              accept="image/*"
              multiple
              onChange={(e) => {
                const picked = Array.from(e.target.files || []);
                setImageFiles((prev) => [...prev, ...picked].slice(0, 5));
                e.target.value = "";
              }}
            />
            {imageFiles.length > 0 && (
              <ul className="mt-2 text-xs text-gray-600">
                {imageFiles.map((f, i) => (
                  <li key={i} className="flex justify-between gap-2">
                    <span>{f.name}</span>
                    <button
                      type="button"
                      className="text-red-600"
                      onClick={() => setImageFiles((prev) => prev.filter((_, j) => j !== i))}
                    >
                      Remove
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        ) : (
          <div>
            <input
              type="file"
              accept="video/mp4,video/quicktime,.mp4,.mov"
              onChange={(e) => setVideoFile(e.target.files?.[0] ?? null)}
            />
            {videoFile && (
              <p className="mt-2 text-xs text-gray-600 flex justify-between">
                <span>{videoFile.name}</span>
                <button type="button" className="text-red-600" onClick={() => setVideoFile(null)}>
                  Remove
                </button>
              </p>
            )}
          </div>
        )}
      </Section>

      <Section label="Placements">
        <div className="flex flex-wrap gap-2">
          {placements.map((p) => {
            const selected = selectedPlacements.has(p.key);
            const rate = dailyRateForKey(p.key, pricing);
            return (
              <button
                key={p.id}
                type="button"
                onClick={() => togglePlacement(p.key)}
                className={`px-3 py-2 rounded-lg border text-sm ${
                  selected ? "bg-indigo-100 border-indigo-400 text-indigo-900" : "bg-white border-gray-200"
                }`}
              >
                {p.title} ({rate} BYC/day)
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

      <div className="rounded-lg bg-gray-50 border p-4">
        <p className="font-semibold">Total: {total.toFixed(1)} BYC</p>
        <p className="text-xs text-gray-500 mt-1">Debited from the logged-in admin&apos;s wallet</p>
      </div>

      {error && <p className="text-red-600 text-sm">{error}</p>}
      {success && <p className="text-green-700 text-sm">{success}</p>}

      <button
        type="submit"
        disabled={loading || total <= 0}
        className="bg-indigo-600 text-white px-6 py-2 rounded-lg disabled:opacity-50"
      >
        {loading ? "Submitting…" : `Submit for review (${total.toFixed(1)} BYC)`}
      </button>
    </form>
  );
}

