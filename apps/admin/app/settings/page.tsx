"use client";
import { Card } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Settings, CreditCard, Globe, Bell, Shield, Database, Users, Coins, Megaphone } from "lucide-react";

export default function SettingsIndexPage() {
  return (
    <div className="p-6 space-y-8">
      <div className="relative overflow-hidden rounded-xl bg-gradient-to-r from-indigo-600 to-purple-600 text-white">
        <div className="absolute -top-10 -left-10 w-48 h-48 rounded-full bg-white/10" />
        <div className="absolute -bottom-10 -right-10 w-64 h-64 rounded-full bg-white/10" />
        <div className="relative p-6 md:p-8 flex items-center gap-4">
          <div className="p-3 bg-white/20 rounded-lg">
            <Settings className="w-6 h-6" />
          </div>
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold">Settings</h1>
            <p className="text-sm md:text-base text-white/80">Configure system integrations and administrative preferences</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-indigo-50">
              <CreditCard className="w-5 h-5 text-indigo-600" />
            </div>
            <div>
              <h2 className="font-medium">Payment Gateways</h2>
              <p className="text-xs text-gray-600">Manage keys and webhooks for Stripe, Paystack, PayPal, Flutterwave</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/gateways">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-blue-50">
              <Globe className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h2 className="font-medium">Domains & URLs</h2>
              <p className="text-xs text-gray-600">Application base URL, callback URLs, CDN settings</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button variant="secondary" disabled>Coming Soon</Button>
            <span className="text-xs text-gray-500">Planned</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-amber-50">
              <Bell className="w-5 h-5 text-amber-600" />
            </div>
            <div>
              <h2 className="font-medium">Notifications</h2>
              <p className="text-xs text-gray-600">Email templates, push settings, broadcast rules</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/email">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-teal-50">
              <Bell className="w-5 h-5 text-teal-600" />
            </div>
            <div>
              <h2 className="font-medium">SMS & WhatsApp OTP</h2>
              <p className="text-xs text-gray-600">
                EbulkSMS + Twilio keys, enable SMS/WhatsApp channels for phone verification
              </p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/messaging">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-emerald-50">
              <Shield className="w-5 h-5 text-emerald-600" />
            </div>
            <div>
              <h2 className="font-medium">Security</h2>
              <p className="text-xs text-gray-600">Roles & permissions, audit logs, rate limits</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button variant="secondary" disabled>Coming Soon</Button>
            <span className="text-xs text-gray-500">Planned</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-purple-50">
              <Database className="w-5 h-5 text-purple-600" />
            </div>
            <div>
              <h2 className="font-medium">Data & Integrations</h2>
              <p className="text-xs text-gray-600">Exports, imports, third-party connectors</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button variant="secondary" disabled>Coming Soon</Button>
            <span className="text-xs text-gray-500">Planned</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-green-50">
              <Users className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <h2 className="font-medium">Community Settings</h2>
              <p className="text-xs text-gray-600">Configure join distance requirements and community restrictions</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/communities">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-amber-50">
              <Coins className="w-5 h-5 text-amber-600" />
            </div>
            <div>
              <h2 className="font-medium">Karma Settings</h2>
              <p className="text-xs text-gray-600">Earn amounts, withdrawal threshold, and KARMA→BYC rate</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/karma">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-blue-50">
              <Globe className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h2 className="font-medium">Maps Settings</h2>
              <p className="text-xs text-gray-600">Google Maps API key configuration</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/maps">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>

        <Card className="p-5 flex flex-col gap-3">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-md bg-amber-50">
              <Megaphone className="w-5 h-5 text-amber-600" />
            </div>
            <div>
              <h2 className="font-medium">Ad Pricing</h2>
              <p className="text-xs text-gray-600">BYC per day for trade, gift, donation, and normal ads</p>
            </div>
          </div>
          <div className="flex items-center justify-between">
            <Button asChild>
              <a href="/settings/ads">Configure</a>
            </Button>
            <span className="text-xs text-gray-500">Active: configurable</span>
          </div>
        </Card>
      </div>
    </div>
  );
}
