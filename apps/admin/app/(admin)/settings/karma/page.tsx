"use client";
import useSWR from "swr";
import { api } from '@/lib/api';
import { Card } from "@/app/components/ui/card";
import { Input } from '@/app/components/ui/input';
import { Button } from '@/app/components/ui/button';
import { useState, useEffect, useMemo } from "react";
import { useToast } from '@/app/components/ui/use-toast';

const fetcher = (url: string) => api.get(url).then((r) => r.data);

type KarmaPoints = Record<string, number>;

type FieldMeta = {
  key: string;
  label: string;
  description: string;
  group: 'core' | 'social' | 'referrals' | 'other';
  min: number;
  max: number;
  step?: number;
  unit?: 'points' | 'percent';
};

const GROUP_LABELS: Record<string, string> = {
  core: 'Trade, gift & donation',
  social: 'Social & reviews',
  referrals: 'Referral bonuses',
  other: 'Other earn actions',
};

export default function KarmaSettingsPage() {
  const { data, mutate, isLoading } = useSWR("/v1/admin/settings/karma", fetcher);
  const { toast } = useToast();
  const [minThreshold, setMinThreshold] = useState<number>(500);
  const [karmaToBycRate, setKarmaToBycRate] = useState<number>(100);
  const [points, setPoints] = useState<KarmaPoints>({});
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (data?.minWithdrawalThreshold != null) {
      setMinThreshold(data.minWithdrawalThreshold);
    }
    if (data?.karmaToBycRate != null) {
      setKarmaToBycRate(data.karmaToBycRate);
    }
    if (data?.points) {
      setPoints(data.points);
    }
  }, [data]);

  const fields: FieldMeta[] = data?.fields ?? [];
  const defaults: KarmaPoints = data?.defaults ?? {};
  const legacy: KarmaPoints = data?.legacy ?? {};

  const groupedFields = useMemo(() => {
    const groups: Record<string, FieldMeta[]> = {};
    for (const f of fields) {
      if (!groups[f.group]) groups[f.group] = [];
      groups[f.group].push(f);
    }
    return groups;
  }, [fields]);

  const setPoint = (key: string, value: number) => {
    setPoints((prev) => ({ ...prev, [key]: value }));
  };

  const save = async () => {
    try {
      if (minThreshold < 1 || minThreshold > 1000000) {
        toast({ title: "Invalid threshold", description: "Min withdrawal must be 1–1,000,000", variant: "destructive" });
        return;
      }
      if (karmaToBycRate < 1 || karmaToBycRate > 10000) {
        toast({ title: "Invalid rate", description: "Karma-to-BYC rate must be 1–10,000", variant: "destructive" });
        return;
      }
      setIsSaving(true);
      await api.post("/v1/admin/settings/karma/upsert", {
        minWithdrawalThreshold: Math.round(minThreshold),
        karmaToBycRate: parseFloat(karmaToBycRate.toFixed(2)),
        points,
      });
      toast({ title: "Saved", description: "Karma settings updated" });
      mutate();
    } catch (e: any) {
      const msg = e?.response?.data?.message || e?.message || 'Unknown error';
      toast({ title: "Save failed", description: msg, variant: "destructive" });
    } finally {
      setIsSaving(false);
    }
  };

  const resetToDefaults = () => {
    if (data?.defaults) {
      setPoints({ ...data.defaults });
      toast({ title: "Reset locally", description: "Form set to built-in defaults — click Save to apply" });
    }
  };

  const bycPerMin = minThreshold / (karmaToBycRate || 100);

  return (
    <div className="container mx-auto p-6 space-y-6 max-w-5xl">
      <div>
        <h1 className="text-3xl font-bold">Karma Settings</h1>
        <p className="text-muted-foreground mt-2">
          Control how much KARMA users earn and when they can convert it to BYC wallet balance.
        </p>
      </div>

      <Card className="p-6">
        <h2 className="text-xl font-semibold mb-2">Withdrawal & conversion</h2>
        <p className="text-sm text-muted-foreground mb-4">
          Lower conversion rates protect platform economics — KARMA ÷ rate = BYC credited to wallet.
        </p>
        <div className="grid gap-6 md:grid-cols-2">
          <div className="space-y-2">
            <label htmlFor="minThreshold" className="text-sm font-medium">Minimum KARMA to withdraw</label>
            <Input
              id="minThreshold"
              type="number"
              min="1"
              max="1000000"
              value={minThreshold}
              onChange={(e) => {
                const v = parseFloat(e.target.value);
                if (!isNaN(v)) setMinThreshold(v);
              }}
              disabled={isLoading || isSaving}
            />
            <p className="text-xs text-muted-foreground">
              {minThreshold} KARMA → {bycPerMin.toFixed(4)} BYC at current rate
            </p>
          </div>
          <div className="space-y-2">
            <label htmlFor="karmaToBycRate" className="text-sm font-medium">KARMA per 1 BYC</label>
            <Input
              id="karmaToBycRate"
              type="number"
              min="1"
              max="10000"
              step="0.01"
              value={karmaToBycRate}
              onChange={(e) => {
                const v = parseFloat(e.target.value);
                if (!isNaN(v)) setKarmaToBycRate(v);
              }}
              disabled={isLoading || isSaving}
            />
            <p className="text-xs text-muted-foreground">
              {karmaToBycRate} KARMA = 1 BYC
            </p>
          </div>
        </div>
      </Card>

      {Object.entries(groupedFields).map(([group, groupFields]) => (
        <Card key={group} className="p-6">
          <h2 className="text-lg font-semibold mb-1">{GROUP_LABELS[group] ?? group}</h2>
          <p className="text-xs text-muted-foreground mb-4">
            Active values are used by the API and mobile app. “Was” shows previous hardcoded amounts.
          </p>
          <div className="space-y-4">
            {groupFields.map((field) => {
              const key = field.key;
              const active = points[key] ?? defaults[key] ?? 0;
              const was = legacy[key];
              const isPercent = field.unit === 'percent';
              return (
                <div
                  key={key}
                  className="grid gap-3 md:grid-cols-[1fr_140px] md:items-center border-b border-border/60 pb-4 last:border-0 last:pb-0"
                >
                  <div>
                    <div className="font-medium text-sm">{field.label}</div>
                    <div className="text-xs text-muted-foreground">{field.description}</div>
                    <div className="text-xs mt-1 flex flex-wrap gap-3">
                      <span className="text-emerald-700 dark:text-emerald-400">
                        In use: <strong>{active}{isPercent ? '%' : ''}</strong>
                      </span>
                      {was != null && was !== active && (
                        <span className="text-amber-700 dark:text-amber-400">Was: {was}{isPercent ? '%' : ''}</span>
                      )}
                      <span className="text-muted-foreground">Default: {defaults[key] ?? '—'}{isPercent ? '%' : ''}</span>
                    </div>
                  </div>
                  <Input
                    type="number"
                    min={field.min}
                    max={field.max}
                    step={field.step ?? 1}
                    value={active}
                    onChange={(e) => {
                      const v = parseFloat(e.target.value);
                      if (!isNaN(v)) setPoint(key, v);
                    }}
                    disabled={isLoading || isSaving}
                  />
                </div>
              );
            })}
          </div>
        </Card>
      ))}

      <div className="flex flex-wrap gap-3">
        <Button onClick={save} disabled={isLoading || isSaving} className="min-w-[120px]">
          {isSaving ? "Saving..." : "Save all settings"}
        </Button>
        <Button variant="outline" onClick={resetToDefaults} disabled={isLoading || isSaving}>
          Reset earn amounts to defaults
        </Button>
      </div>

      <Card className="p-6 bg-muted/50">
        <h3 className="font-semibold mb-2">Economics cheat sheet</h3>
        <ul className="text-sm text-muted-foreground space-y-1 list-disc list-inside">
          <li>Trade complete: flat KARMA per completed trade</li>
          <li>Gift: giver sets reward between min/max; default used if omitted</li>
          <li>Donation: floor(BYC donated × percent ÷ 100) — e.g. 100 BYC at 5% = 5 KARMA</li>
          <li>Withdrawal: users convert KARMA to BYC once they hit the minimum threshold</li>
        </ul>
      </Card>
    </div>
  );
}
