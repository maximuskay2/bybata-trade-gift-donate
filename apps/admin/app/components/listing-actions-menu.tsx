"use client";

import { useEffect, useRef, useState } from "react";
import { ChevronDown, MoreHorizontal } from "lucide-react";
import { clsx } from "clsx";
import ListingModerationDialog, {
  type ListingKind,
  type ModerationAction,
} from "@/app/components/listing-moderation-dialog";

export type ActionTone = "default" | "warning" | "danger" | "success";

export type ListingMenuAction = {
  id: string;
  label: string;
  onClick: () => void;
  tone?: ActionTone;
  hidden?: boolean;
  section?: "primary" | "status" | "moderation" | "danger";
};

const toneClass: Record<ActionTone, string> = {
  default: "text-gray-700 hover:bg-gray-50",
  warning: "text-amber-700 hover:bg-amber-50",
  danger: "text-red-700 hover:bg-red-50",
  success: "text-emerald-700 hover:bg-emerald-50",
};

type ModerationProps = {
  listingKind: ListingKind;
  listingId: string;
  listingTitle: string;
  status: string;
  onComplete: () => void;
};

type Props = {
  actions: ListingMenuAction[];
  moderation?: ModerationProps;
  align?: "left" | "right";
};

export default function ListingActionsMenu({
  actions,
  moderation,
  align = "right",
}: Props) {
  const [open, setOpen] = useState(false);
  const [modDialog, setModDialog] = useState<{
    action: ModerationAction;
    open: boolean;
  }>({ action: "PAUSE", open: false });
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const visible = actions.filter((a) => !a.hidden);
  const primary = visible.filter((a) => !a.section || a.section === "primary");
  const status = visible.filter((a) => a.section === "status");
  const danger = visible.filter((a) => a.section === "danger");

  const modStatus = moderation?.status || "";
  const isPaused = modStatus === "PAUSED";
  const isBanned = modStatus === "BANNED";

  function run(action: ListingMenuAction) {
    setOpen(false);
    action.onClick();
  }

  function openModeration(action: ModerationAction) {
    setOpen(false);
    setModDialog({ action, open: true });
  }

  function renderItem(action: ListingMenuAction) {
    return (
      <button
        key={action.id}
        type="button"
        className={clsx(
          "w-full text-left px-3 py-2 text-sm rounded-md transition-colors",
          toneClass[action.tone || "default"]
        )}
        onClick={() => run(action)}
      >
        {action.label}
      </button>
    );
  }

  function renderSection(title: string, items: ListingMenuAction[]) {
    if (items.length === 0) return null;
    return (
      <div className="py-1">
        <p className="px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wide text-gray-400">
          {title}
        </p>
        {items.map(renderItem)}
      </div>
    );
  }

  return (
    <div ref={rootRef} className="relative inline-block text-left">
      <button
        type="button"
        aria-expanded={open}
        aria-haspopup="menu"
        onClick={() => setOpen((v) => !v)}
        className="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-2.5 py-1.5 text-xs font-medium text-gray-700 shadow-sm hover:bg-gray-50 hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-indigo-500/40"
      >
        <MoreHorizontal className="h-3.5 w-3.5 text-gray-500" />
        Actions
        <ChevronDown
          className={clsx(
            "h-3.5 w-3.5 text-gray-400 transition-transform",
            open && "rotate-180"
          )}
        />
      </button>

      {open && (
        <div
          role="menu"
          className={clsx(
            "absolute z-50 mt-1 min-w-[200px] rounded-xl border border-gray-200 bg-white py-1 shadow-lg ring-1 ring-black/5",
            align === "right" ? "right-0" : "left-0"
          )}
        >
          {renderSection("General", primary)}
          {renderSection("Status", status)}

          {moderation && (
            <div className="py-1 border-t border-gray-100">
              <p className="px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wide text-gray-400">
                Moderation
              </p>
              {!isPaused && !isBanned && (
                <button
                  type="button"
                  className={clsx(
                    "w-full text-left px-3 py-2 text-sm rounded-md",
                    toneClass.warning
                  )}
                  onClick={() => openModeration("PAUSE")}
                >
                  Pause listing
                </button>
              )}
              {!isBanned && (
                <button
                  type="button"
                  className={clsx(
                    "w-full text-left px-3 py-2 text-sm rounded-md",
                    toneClass.danger
                  )}
                  onClick={() => openModeration("BAN")}
                >
                  Ban listing
                </button>
              )}
              {(isPaused || isBanned) && (
                <button
                  type="button"
                  className={clsx(
                    "w-full text-left px-3 py-2 text-sm rounded-md",
                    toneClass.success
                  )}
                  onClick={() => openModeration("RESTORE")}
                >
                  Restore listing
                </button>
              )}
              <button
                type="button"
                className={clsx(
                  "w-full text-left px-3 py-2 text-sm rounded-md",
                  toneClass.danger
                )}
                onClick={() => openModeration("DELETE")}
              >
                Delete permanently
              </button>
            </div>
          )}

          {renderSection("Danger", danger)}
        </div>
      )}

      {moderation && (
        <ListingModerationDialog
          open={modDialog.open}
          onOpenChange={(open) => setModDialog((d) => ({ ...d, open }))}
          listingKind={moderation.listingKind}
          listingId={moderation.listingId}
          listingTitle={moderation.listingTitle}
          action={modDialog.action}
          onComplete={moderation.onComplete}
        />
      )}
    </div>
  );
}
