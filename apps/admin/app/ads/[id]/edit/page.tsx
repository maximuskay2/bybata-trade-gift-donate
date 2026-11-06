"use client";

import AdminGuard from "@/app/components/admin-guard";
import EditFeedAdForm from "@/app/components/edit-feed-ad-form";
import { use } from "react";

export default function EditAdPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);

  return (
    <AdminGuard>
      <main className="p-6 max-w-4xl mx-auto">
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Edit feed ad</h1>
        <p className="text-sm text-gray-500 mb-6">
          Update creative, placements, or schedule. Live ads may require re-approval after save.
        </p>
        <EditFeedAdForm adId={id} />
      </main>
    </AdminGuard>
  );
}
