"use client";

import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/app/components/ui/dialog";
import { api } from "@/lib/api";

export type ListingKind = "trade" | "gift" | "campaign";
export type ModerationAction = "PAUSE" | "BAN" | "DELETE" | "RESTORE";

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  listingKind: ListingKind;
  listingId: string;
  listingTitle: string;
  action: ModerationAction;
  onComplete?: () => void;
};

const actionCopy: Record<
  ModerationAction,
  { title: string; description: string; confirm: string; tone: string }
> = {
  PAUSE: {
    title: "Pause listing",
    description: "The listing will be hidden from browse/feed until restored.",
    confirm: "Pause listing",
    tone: "bg-amber-600 hover:bg-amber-700",
  },
  BAN: {
    title: "Ban listing",
    description: "The listing will be removed from public view and marked as banned.",
    confirm: "Ban listing",
    tone: "bg-red-600 hover:bg-red-700",
  },
  DELETE: {
    title: "Delete listing",
    description: "Permanently deletes this listing. This cannot be undone.",
    confirm: "Delete permanently",
    tone: "bg-red-700 hover:bg-red-800",
  },
  RESTORE: {
    title: "Restore listing",
    description: "Clears admin moderation and reactivates the listing.",
    confirm: "Restore listing",
    tone: "bg-green-600 hover:bg-green-700",
  },
};

export default function ListingModerationDialog({
  open,
  onOpenChange,
  listingKind,
  listingId,
  listingTitle,
  action,
  onComplete,
}: Props) {
  const [reason, setReason] = useState("");
  const [notifyOwner, setNotifyOwner] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const copy = actionCopy[action];
  const endpoint =
    listingKind === "trade"
      ? `/v1/admin/trades/${listingId}/moderate`
      : listingKind === "gift"
        ? `/v1/admin/gifts/${listingId}/moderate`
        : `/v1/admin/campaigns/${listingId}/moderate`;

  async function submit() {
    const trimmed = reason.trim();
    if (trimmed.length < 3) {
      setError("Please enter a reason (at least 3 characters).");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await api.post(endpoint, {
        action,
        reason: trimmed,
        notifyOwner,
      });
      setReason("");
      onOpenChange(false);
      onComplete?.();
    } catch (e: any) {
      setError(
        e?.response?.data?.message ||
          e?.message ||
          "Moderation action failed. Try again.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{copy.title}</DialogTitle>
          <DialogDescription>
            {copy.description}
            <span className="mt-2 block font-medium text-gray-900">
              {listingTitle}
            </span>
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3">
          <label className="block text-sm font-medium text-gray-700">
            Reason (required — internal record for admin)
          </label>
          <textarea
            className="w-full min-h-[96px] rounded-md border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
            placeholder="e.g. Policy violation, misleading description, prohibited item…"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
          <label className="flex items-center gap-2 text-sm text-gray-600">
            <input
              type="checkbox"
              checked={notifyOwner}
              onChange={(e) => setNotifyOwner(e.target.checked)}
            />
            Flag to notify owner (logged in audit; email coming soon)
          </label>
          {error && <p className="text-sm text-red-600">{error}</p>}
        </div>

        <DialogFooter>
          <button
            type="button"
            className="rounded-md border px-4 py-2 text-sm"
            onClick={() => onOpenChange(false)}
            disabled={submitting}
          >
            Cancel
          </button>
          <button
            type="button"
            className={`rounded-md px-4 py-2 text-sm font-medium text-white ${copy.tone}`}
            onClick={submit}
            disabled={submitting}
          >
            {submitting ? "Saving…" : copy.confirm}
          </button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
