"use client";

import { useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/app/lib/api";

/**
 * Legacy document-id route → redirect to the user submission review page.
 */
export default function LegacyVerificationDocumentRedirect() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;

  const { data, isError } = useQuery({
    queryKey: ["verification-document-redirect", id],
    queryFn: async () => {
      const res = await api.get<{ userId: string }>(
        `/v1/admin/verification/documents/${id}`,
      );
      return res.data;
    },
    enabled: !!id,
    retry: false,
  });

  useEffect(() => {
    if (data?.userId) {
      router.replace(`/verification/users/${data.userId}`);
    }
  }, [data?.userId, router]);

  useEffect(() => {
    if (isError) {
      router.replace("/verification");
    }
  }, [isError, router]);

  return (
    <div className="flex h-64 items-center justify-center text-slate-500">
      Opening user submission…
    </div>
  );
}
