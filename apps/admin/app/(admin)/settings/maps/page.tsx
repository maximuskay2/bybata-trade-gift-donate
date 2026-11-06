"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Card } from "@/app/components/ui/card";
import { Input } from "@/app/components/ui/input";
import { Button } from "@/app/components/ui/button";
import { useToast } from "@/app/components/ui/use-toast";
import PageHeader from "@/app/components/page-header";

export default function MapsSettingsPage() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [currentKey, setCurrentKey] = useState<string>("");
  const [newKey, setNewKey] = useState<string>("");

  useEffect(() => {
    (async () => {
      try {
        const res = await api.get("/v1/settings/maps");
        setCurrentKey(res.data?.googleMapsApiKey || "");
      } catch (_) {
        try {
          const resAdmin = await api.get("/v1/admin/settings/maps");
          setCurrentKey(resAdmin.data?.googleMapsApiKey || "");
        } catch (e: any) {
          const msg = e?.response?.data?.message || "Could not fetch current maps key";
          toast({ title: "Failed to load", description: msg, variant: "destructive" });
        }
      }
    })();
  }, [toast]);

  async function save() {
    setLoading(true);
    try {
      const res = await api.post("/v1/admin/settings/maps/upsert", { apiKey: newKey.trim() });
      setCurrentKey(res.data?.googleMapsApiKey || newKey.trim());
      setNewKey("");
      toast({ title: "Saved", description: "Google Maps API key updated" });
    } catch (e: any) {
      const status = e?.response?.status;
      const msg = status === 401
        ? "You must be logged in as admin to update the key."
        : e?.response?.data?.message || "Update failed";
      toast({ title: "Error", description: msg, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader title="Maps Settings" subtitle="Manage Google Maps API key for mobile and web clients" />
      <Card className="p-4 space-y-4">
        <div>
          <div className="text-sm text-muted-foreground">Current Key</div>
          <div className="font-mono break-all text-sm mt-1">{currentKey ? mask(currentKey) : "(not set)"}</div>
        </div>
        <div className="space-y-2">
          <div className="text-sm">New Google Maps API Key</div>
          <Input value={newKey} onChange={(e) => setNewKey(e.target.value)} placeholder="AIza..." />
          <Button disabled={loading || !newKey.trim()} onClick={save}>{loading ? "Saving..." : "Save"}</Button>
        </div>
        <div className="text-xs text-muted-foreground">
          Note: Mobile apps require platform configuration. Android uses a manifest placeholder (GOOGLE_MAPS_API_KEY). iOS reads Info.plist (GMSApiKey). Update CI/build env to inject keys.
        </div>
      </Card>
    </div>
  );
}

function mask(s: string) {
  if (s.length < 10) return s;
  return s.slice(0, 6) + "••••" + s.slice(-4);
}
