"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  Home, 
  Users, 
  UserPlus,
  Wallet, 
  Layers, 
  Bell,
  Settings,
  Gift,
  Handshake,
  TrendingUp,
  DollarSign,
  Activity,
  Heart,
  Globe,
  Star,
  MessageSquare,
  FileCheck,
  ChevronDown,
  AlertTriangle,
  Megaphone,
  Sparkles,
} from "lucide-react";
import clsx from "clsx";
import { useState } from "react";

interface NavItem {
  href: string;
  label: string;
  icon: any;
  disabled?: boolean;
  badge?: number;
  group?: string;
}

const NAV_ITEMS: NavItem[] = [
  { href: "/dashboard", label: "Dashboard", icon: Home, group: "main" },
  { href: "/users", label: "Users", icon: Users, group: "platform" },
  { href: "/referrals", label: "Referrals", icon: UserPlus, group: "platform" },
  { href: "/verification", label: "Verification", icon: FileCheck, group: "platform" },
  { href: "/trades", label: "Trades", icon: Layers, group: "platform" },
  { href: "/negotiations", label: "Negotiations", icon: Handshake, group: "platform" },
  { href: "/gifts", label: "Gifts", icon: Gift, group: "platform" },
  { href: "/campaigns", label: "Donations", icon: Heart, group: "platform" },
  { href: "/communities", label: "Communities", icon: Globe, group: "platform" },
  { href: "/wallet", label: "Wallet", icon: Wallet, group: "finance" },
  { href: "/wallet/withdrawals", label: "Withdrawals", icon: DollarSign, group: "finance" },
  { href: "/rates", label: "Exchange Rates", icon: DollarSign, group: "finance" },
  { href: "/funding-packages", label: "Funding Packages", icon: Wallet, group: "finance" },
  { href: "/promotions", label: "Ads & Promotions", icon: TrendingUp, group: "marketing" },
  { href: "/boost-config", label: "Boost Config", icon: TrendingUp, group: "marketing" },
  { href: "/boost-types", label: "Boost Types", icon: TrendingUp, group: "marketing" },
  { href: "/ad-placements", label: "Ad Placements", icon: TrendingUp, group: "marketing" },
  { href: "/ads", label: "All Ads", icon: Megaphone, group: "marketing" },
  { href: "/ads-review", label: "Ads Review", icon: FileCheck, group: "marketing" },
  { href: "/karma", label: "Karma System", icon: Star, group: "features" },
  { href: "/chat", label: "Chat Moderation", icon: MessageSquare, group: "features" },
  { href: "/reports", label: "User Reports", icon: AlertTriangle, group: "platform" },
  { href: "/support", label: "Help & Support", icon: MessageSquare, group: "platform" },
  { href: "/appeals", label: "Appeals", icon: FileCheck, group: "platform" },
  { href: "/status", label: "System Status", icon: Activity, group: "system" },
  { href: "/notifications", label: "Notifications", icon: Bell, group: "system" },
  { href: "/settings", label: "Settings", icon: Settings, group: "system" },
  { href: "/settings/email", label: "Email Settings", icon: Bell, group: "system" },
  { href: "/settings/messaging", label: "SMS / WhatsApp", icon: Bell, group: "system" },
  { href: "/settings/email-logs", label: "Email Activity", icon: Activity, group: "system" },
  { href: "/settings/maps", label: "Maps Settings", icon: Globe, group: "system" },
  { href: "/settings/ai-intent", label: "Bento AI", icon: Sparkles, group: "system" },
];

const GROUP_LABELS: Record<string, string> = {
  main: "Main",
  platform: "Platform",
  finance: "Finance",
  marketing: "Marketing",
  features: "Features",
  system: "System",
};

const groupedItems = Object.entries(
  NAV_ITEMS.reduce((acc, item) => {
    const group = item.group || "other";
    if (!acc[group]) acc[group] = [];
    acc[group].push(item);
    return acc;
  }, {} as Record<string, NavItem[]>)
);

export default function Sidebar({ open, onToggle }: { open: boolean; onToggle: () => void }) {
  const pathname = usePathname();
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>({
    main: true,
    platform: true,
    finance: false,
    marketing: false,
    features: false,
    system: false,
  });

  const toggleGroup = (group: string) => {
    setExpandedGroups(prev => ({
      ...prev,
      [group]: !prev[group]
    }));
  };

  return (
    <aside
      className={clsx(
        "sticky top-0 h-screen border-r border-gray-200 bg-white/95 backdrop-blur-xl transition-all duration-300 flex flex-col overflow-hidden",
        open ? "w-64" : "w-20"
      )}
    >
      {/* Logo Section */}
      <div className={clsx(
        "h-16 flex items-center gap-3 px-4 border-b border-gray-200 bg-gradient-to-r from-indigo-600/10 to-purple-600/10",
        !open && "justify-center"
      )}>
        <div className={clsx(
          "flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br from-indigo-600 to-purple-600 text-white font-bold text-lg shadow-lg"
        )}>
          B
        </div>
        {open && (
          <div>
            <div className="font-bold text-gray-900 leading-tight">BYBATA</div>
            <div className="text-xs text-gray-500">Admin Panel</div>
          </div>
        )}
      </div>

      {/* Navigation */}
      <nav className={clsx(
        "flex-1 overflow-y-auto py-4 scrollbar-hide",
        open ? "px-3" : "px-2"
      )}>
        {groupedItems.map(([group, items]) => (
          <div key={group} className="mb-2">
            {open && (
              <button
                onClick={() => toggleGroup(group)}
                className={clsx(
                  "w-full flex items-center justify-between px-3 py-2 text-xs font-semibold text-gray-600 hover:text-gray-900 transition-colors",
                  "rounded-lg hover:bg-gray-100 mb-2"
                )}
              >
                <span className="uppercase tracking-wider">{GROUP_LABELS[group]}</span>
                <ChevronDown size={14} className={clsx(
                  "transition-transform",
                  expandedGroups[group] ? "rotate-180" : ""
                )} />
              </button>
            )}
            {expandedGroups[group] && (
              <div className="space-y-1">
                {items.map((item) => (
                  <NavLink
                    key={item.href}
                    href={item.href}
                    label={item.label}
                    icon={item.icon}
                    active={pathname?.startsWith(item.href)}
                    disabled={'disabled' in item ? item.disabled : undefined}
                    collapsed={!open}
                    badge={item.badge}
                  />
                ))}
              </div>
            )}
          </div>
        ))}
      </nav>

      {/* Footer Info */}
      {open && (
        <div className="border-t border-gray-200 p-4 bg-gray-50/50">
          <div className="text-xs text-gray-500 space-y-1">
            <p className="font-medium text-gray-700">Version 2.0</p>
            <p>Admin Dashboard</p>
          </div>
        </div>
      )}
    </aside>
  );
}

function NavLink({
  href,
  label,
  icon: Icon,
  active,
  disabled,
  collapsed,
  badge,
}: {
  href: string;
  label: string;
  icon: any;
  active?: boolean;
  disabled?: boolean;
  collapsed?: boolean;
  badge?: number;
}) {
  return (
    <Link
      href={href}
      className={clsx(
        "relative flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-200",
        "hover:text-gray-900 hover:bg-gray-100",
        active
          ? "text-indigo-600 bg-indigo-50 shadow-sm"
          : "text-gray-600",
        disabled && "opacity-50 cursor-not-allowed pointer-events-none",
        collapsed && "justify-center px-2"
      )}
      title={collapsed ? label : undefined}
    >
      <div className={clsx(
        "relative flex-shrink-0",
        active && "text-indigo-600"
      )}>
        <Icon size={20} />
        {badge && badge > 0 && (
          <div className="absolute -top-2 -right-2 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-bold">
            {badge > 9 ? '9+' : badge}
          </div>
        )}
      </div>
      {!collapsed && (
        <>
          <span className="flex-1 truncate">{label}</span>
          {active && (
            <div className="w-1.5 h-1.5 rounded-full bg-indigo-600" />
          )}
        </>
      )}
    </Link>
  );
}
