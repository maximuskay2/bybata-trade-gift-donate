"use client";
import useSWR from "swr";
import { api } from '@/lib/api';
import { Card } from "@/app/components/ui/card";
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { useState, useEffect } from "react";
import { useToast } from '@/app/components/ui/use-toast';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

export default function CommunitySettingsPage() {
  const { data, mutate, isLoading } = useSWR("/v1/admin/settings/communities", fetcher);
  const { toast } = useToast();
  const [joinDistanceKm, setJoinDistanceKm] = useState<number>(100);
  const [isSaving, setIsSaving] = useState(false);

  // Update local state when data loads
  useEffect(() => {
    if (data?.joinDistanceKm) {
      setJoinDistanceKm(data.joinDistanceKm);
    }
  }, [data?.joinDistanceKm]);

  const save = async () => {
    try {
      // Validation
      if (!joinDistanceKm || joinDistanceKm < 1 || joinDistanceKm > 1000) {
        toast({ 
          title: "Invalid distance", 
          description: "Join distance must be between 1 and 1000 km", 
          variant: "destructive" 
        });
        return;
      }

      setIsSaving(true);
      await api.post("/v1/admin/settings/communities/upsert", {
        joinDistanceKm: Math.round(joinDistanceKm),
      });
      toast({ 
        title: "Saved", 
        description: `Community join distance set to ${Math.round(joinDistanceKm)} km` 
      });
      mutate();
    } catch (e: any) {
      const errorMessage = e?.response?.data?.message || e?.message || 'Unknown error occurred';
      toast({ 
        title: "Save failed", 
        description: errorMessage, 
        variant: "destructive" 
      });
      console.error('Community settings save error:', e?.response?.data || e);
    } finally {
      setIsSaving(false);
    }
  };

  const currentDistance = data?.joinDistanceKm ?? 100;
  const currentDistanceMeters = data?.joinDistanceMeters ?? 100000;

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Community Settings</h1>
        <p className="text-muted-foreground mt-2">
          Configure community-related settings and restrictions
        </p>
      </div>

      <Card className="p-6">
        <div className="space-y-4">
          <div>
            <h2 className="text-xl font-semibold mb-4">Join Distance Requirements</h2>
            <p className="text-sm text-muted-foreground mb-4">
              Set the maximum distance (in kilometers) that users must be within to join a community.
              Users outside this radius will not be able to join communities.
            </p>
          </div>

          <div className="space-y-2">
            <label htmlFor="joinDistance" className="text-sm font-medium">Maximum Join Distance (km)</label>
            <div className="flex items-center gap-4">
              <Input
                id="joinDistance"
                type="number"
                min="1"
                max="1000"
                step="1"
                value={joinDistanceKm}
                onChange={(e) => {
                  const value = parseFloat(e.target.value);
                  if (!isNaN(value)) {
                    setJoinDistanceKm(value);
                  }
                }}
                className="w-48"
                placeholder="100"
                disabled={isLoading || isSaving}
              />
              <span className="text-sm text-muted-foreground">
                ({currentDistanceMeters.toLocaleString()} meters)
              </span>
            </div>
            <p className="text-xs text-muted-foreground">
              Current setting: <strong>{currentDistance} km</strong> ({currentDistanceMeters.toLocaleString()} meters)
            </p>
            <p className="text-xs text-muted-foreground">
              Range: 1 km to 1000 km (default: 100 km)
            </p>
          </div>

          <div className="pt-4">
            <Button 
              onClick={save} 
              disabled={isLoading || isSaving}
              className="min-w-[120px]"
            >
              {isSaving ? "Saving..." : "Save Settings"}
            </Button>
          </div>
        </div>
      </Card>

      <Card className="p-6 bg-muted/50">
        <div className="space-y-2">
          <h3 className="font-semibold">How it works</h3>
          <ul className="text-sm text-muted-foreground space-y-1 list-disc list-inside">
            <li>Users must be within the specified distance from a community's center to join</li>
            <li>The distance is calculated using GPS coordinates (latitude/longitude)</li>
            <li>Community owners/creators can always join their own communities regardless of distance</li>
            <li>Existing members retain access even if they move outside the radius</li>
            <li>This setting applies globally to all communities in the system</li>
          </ul>
        </div>
      </Card>
    </div>
  );
}

