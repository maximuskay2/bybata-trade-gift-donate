"use client";
import { Menu, Search, CircleUserRound, Moon, Sun, LogOut, Bell, HelpCircle } from "lucide-react";
import { useEffect, useState } from "react";

export default function Topbar({ onToggleSidebar }: { onToggleSidebar: () => void }) {
  const [theme, setTheme] = useState<'light' | 'dark'>(() =>
    (typeof window !== 'undefined' && (localStorage.getItem('theme') as 'light' | 'dark')) || 'light'
  );
  useEffect(() => {
    if (typeof document !== 'undefined') {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('theme', theme);
    }
  }, [theme]);

  return (
    <header className="sticky top-0 z-40 h-16 bg-white/95 backdrop-blur-xl border-b border-gray-200 shadow-sm">
      <div className="h-full px-6 flex items-center justify-between gap-4">
        {/* Left Section */}
        <div className="flex items-center gap-4">
          <button
            onClick={onToggleSidebar}
            className="inline-flex items-center justify-center w-9 h-9 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
            aria-label="Toggle sidebar"
          >
            <Menu size={20} />
          </button>
          
          {/* Search Bar */}
          <div className="hidden md:block relative w-80">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              className="w-full pl-9 pr-4 py-2 text-sm rounded-lg border border-gray-200 bg-gray-50 hover:bg-white focus:bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all duration-200"
              placeholder="Search dashboard..."
            />
          </div>
        </div>

        {/* Right Section */}
        <div className="flex items-center gap-2">
          {/* Help Button */}
          <button
            className="hidden sm:inline-flex items-center justify-center w-9 h-9 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
            title="Help & Documentation"
          >
            <HelpCircle size={20} />
          </button>

          {/* Notifications */}
          <button
            className="relative inline-flex items-center justify-center w-9 h-9 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
            title="Notifications"
          >
            <Bell size={20} />
            <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
          </button>

          {/* Divider */}
          <div className="h-6 w-px bg-gray-200" />

          {/* Theme Toggle */}
          <button
            className="inline-flex items-center justify-center w-9 h-9 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
            onClick={() => setTheme(theme === 'light' ? 'dark' : 'light')}
            title="Toggle theme"
          >
            {theme === 'light' ? <Moon size={20} /> : <Sun size={20} />}
          </button>

          {/* Profile */}
          <button
            className="inline-flex items-center gap-2 px-3 py-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-100 transition-all duration-200"
            title="User profile"
          >
            <div className="w-6 h-6 rounded-full bg-gradient-to-br from-indigo-500 to-purple-500" />
            <span className="hidden sm:inline text-sm font-medium">Admin</span>
          </button>

          {/* Logout */}
          <button
            className="inline-flex items-center justify-center w-9 h-9 rounded-lg text-gray-600 hover:text-red-600 hover:bg-red-50 transition-all duration-200"
            onClick={() => {
              if (typeof window !== 'undefined') {
                localStorage.removeItem('admin_token');
                window.location.href = '/login';
              }
            }}
            title="Log out"
          >
            <LogOut size={20} />
          </button>
        </div>
      </div>
    </header>
  );
}
