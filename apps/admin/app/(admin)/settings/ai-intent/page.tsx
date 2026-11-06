"use client";
import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { Card } from "@/app/components/ui/card";
import { Button } from "@/app/components/ui/button";
import { Input } from "@/app/components/ui/input";
import { useToast } from "@/app/components/ui/use-toast";
import PageHeader from "@/app/components/page-header";

type CohortStat = {
  cohort: string;
  shown: number;
  taps: number;
  conversions: number;
  fallbacks: number;
  ctr: number | null;
  conversionRate: number | null;
};

type LatencyStat = {
  bucket: string;
  count: number;
  p95LatencyMs: number;
  sloMs: number | null;
  slo: "pass" | "fail" | null;
};

type SlotStat = {
  cohort: string;
  module: string;
  size: string;
  taps: number;
};

type SourceStat = {
  source: string;
  count: number;
  p95LatencyMs: number;
  tokensPerThousand: number | null;
};

function applyPayload(
  data: any,
  setEnabled: (v: boolean) => void,
  setEnvDefault: (v: boolean) => void,
  setPercent: (v: string) => void,
  setCity: (v: string) => void,
  setSources: (v: SourceStat[]) => void,
  setCohorts: (v: CohortStat[]) => void,
  setSlots: (v: SlotStat[]) => void,
  setLatency: (v: LatencyStat[]) => void,
  setMetricsReady: (v: boolean) => void,
) {
  setEnabled(data?.enabled === true);
  setEnvDefault(data?.envDefault === true);
  setPercent(String(data?.rolloutPercent ?? 100));
  setCity(data?.rolloutCity ?? "");
  setSources(Array.isArray(data?.metrics?.sources) ? data.metrics.sources : []);
  setCohorts(Array.isArray(data?.metrics?.cohorts) ? data.metrics.cohorts : []);
  setSlots(Array.isArray(data?.metrics?.slots) ? data.metrics.slots : []);
  setLatency(Array.isArray(data?.metrics?.latency) ? data.metrics.latency : []);
  setMetricsReady(data?.metrics?.available === true);
}

export default function AiIntentSettingsPage() {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [enabled, setEnabled] = useState(false);
  const [envDefault, setEnvDefault] = useState(false);
  const [percent, setPercent] = useState("100");
  const [city, setCity] = useState("");
  const [sources, setSources] = useState<SourceStat[]>([]);
  const [cohorts, setCohorts] = useState<CohortStat[]>([]);
  const [slots, setSlots] = useState<SlotStat[]>([]);
  const [latency, setLatency] = useState<LatencyStat[]>([]);
  const [metricsReady, setMetricsReady] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const res = await api.get("/v1/admin/settings/ai-intent");
        applyPayload(
          res.data,
          setEnabled,
          setEnvDefault,
          setPercent,
          setCity,
          setSources,
          setCohorts,
          setSlots,
          setLatency,
          setMetricsReady,
        );
      } catch (e: any) {
        const msg = e?.response?.data?.message || "Could not load AI intent settings";
        toast({ title: "Failed to load", description: msg, variant: "destructive" });
      }
    })();
  }, [toast]);

  async function save(next: boolean) {
    setLoading(true);
    try {
      const res = await api.post("/v1/admin/settings/ai-intent", { enabled: next });
      applyPayload(
        res.data,
        setEnabled,
        setEnvDefault,
        setPercent,
        setCity,
        setSources,
        setCohorts,
        setSlots,
        setLatency,
        setMetricsReady,
      );
      toast({
        title: next ? "AI interpretation on" : "AI interpretation off",
        description: "Rules search stays available either way.",
      });
    } catch (e: any) {
      const msg = e?.response?.data?.message || "Update failed";
      toast({ title: "Error", description: msg, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  }

  async function saveRollout() {
    const rolloutPercent = Number(percent);
    if (!Number.isFinite(rolloutPercent) || rolloutPercent < 0 || rolloutPercent > 100) {
      toast({ title: "Percent must be 0 to 100", variant: "destructive" });
      return;
    }
    setLoading(true);
    try {
      const res = await api.post("/v1/admin/settings/ai-intent", {
        rolloutPercent,
        rolloutCity: city.trim(),
      });
      applyPayload(
        res.data,
        setEnabled,
        setEnvDefault,
        setPercent,
        setCity,
        setSources,
        setCohorts,
        setSlots,
        setLatency,
        setMetricsReady,
      );
      toast({ title: "Rollout saved", description: "Staff stay on the AI arm at any percent." });
    } catch (e: any) {
      const msg = e?.response?.data?.message || "Update failed";
      toast({ title: "Error", description: msg, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title="Bento AI"
        subtitle="Turn intent interpretation on or off without a deploy"
      />
      <Card className="p-4 space-y-4">
        <div className="text-sm">
          AI interpretation is <span className="font-semibold">{enabled ? "on" : "off"}</span>.
          The environment default is {envDefault ? "on" : "off"}. A saved choice here overrides that default.
        </div>
        <div className="text-sm text-muted-foreground">
          When this is off, or the model times out, search still uses the rules interpreter.
          The model never receives coordinates, wallet, KYC, or chat data.
        </div>
        <div className="flex gap-2">
          <Button disabled={loading || enabled} onClick={() => save(true)}>
            Enable
          </Button>
          <Button disabled={loading || !enabled} variant="outline" onClick={() => save(false)}>
            Disable
          </Button>
        </div>
      </Card>
      <Card className="p-4 space-y-4">
        <div className="text-sm font-semibold">Rollout</div>
        <p className="text-sm text-muted-foreground">
          100% means every signed-in user and guest can reach the model. Lower it to keep a rules-only cohort.
          Admins and moderators stay on the AI arm at any percent. Guests stay on rules until the percent is 100.
          A city limits the percent to people whose search is inside that city. Blank means every city. Uyo is the configured city.
        </p>
        <label className="block text-sm">
          Percent
          <Input
            type="number"
            min={0}
            max={100}
            value={percent}
            onChange={(e) => setPercent(e.target.value)}
          />
        </label>
        <label className="block text-sm">
          City
          <Input
            value={city}
            placeholder="Blank, or Uyo"
            onChange={(e) => setCity(e.target.value)}
          />
        </label>
        <Button disabled={loading} onClick={saveRollout}>
          Save rollout
        </Button>
      </Card>
      <Card className="p-4 space-y-3">
        <div className="text-sm font-semibold">Last 7 days</div>
        {!metricsReady ? (
          <p className="text-sm text-muted-foreground">
            Metrics appear after the AiIntentEvent migration has been applied.
          </p>
        ) : (
          <>
            {latency.map((row) => (
              <div key={row.bucket} className="text-sm">
                {row.bucket}: p95 {row.p95LatencyMs} ms over {row.count}
                {row.sloMs != null ? ` (target ${row.sloMs} ms, ${row.slo})` : ""}
              </div>
            ))}
            {sources.map((row) => (
              <div key={row.source} className="text-sm">
                {row.source}: {row.count} interprets, p95 {row.p95LatencyMs} ms
                {row.tokensPerThousand != null ? `, ${row.tokensPerThousand} tokens per 1,000` : ""}
              </div>
            ))}
            {sources.length === 0 ? <div className="text-sm text-muted-foreground">No interprets yet.</div> : null}
            {cohorts.map((row) => (
              <div key={row.cohort} className="text-sm">
                {row.cohort} cohort: {row.shown} shown, {row.taps} taps, {row.conversions} conversions, {row.fallbacks} fallbacks
                {row.ctr != null ? `, CTR ${(row.ctr * 100).toFixed(1)}%` : ""}
                {row.conversionRate != null ? `, conversion ${(row.conversionRate * 100).toFixed(1)}%` : ""}
              </div>
            ))}
            {slots.map((row) => (
              <div key={`${row.cohort}-${row.module}-${row.size}`} className="text-sm">
                {row.cohort} {row.module} {row.size}: {row.taps} taps
              </div>
            ))}
          </>
        )}
      </Card>
    </div>
  );
}
