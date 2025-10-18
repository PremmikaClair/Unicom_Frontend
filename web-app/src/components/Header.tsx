import React from "react";
import { useAuth } from "../features/auth/AuthContext";

const AdminHeader: React.FC = () => {
  const { user, loading, logout } = useAuth();

  const displayName = (() => {
    if (!user) return "";
    const name = [user.firstName, user.lastName].filter(Boolean).join(" ");
    return name || (user as any).name || user.email || String((user as any).id || "User");
  })();

  return (
    <header className="sticky top-0 z-10 bg-gradient-to-r from-emerald-700 via-emerald-600 to-teal-600 text-white border-b border-emerald-600">
      <div className="px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-lg md:text-xl font-semibold flex items-center gap-2">
            📊 Dashboard
            <span className="hidden sm:inline-flex items-center rounded-full bg-white/15 text-white text-[11px] px-2 py-0.5">Admin</span>
          </h1>
        </div>
        <div className="flex items-center gap-2">
          <span className="hidden sm:inline text-sm text-white/90">
            {loading ? "Loading…" : `Hi, ${displayName || "User"}`}
          </span>
          <button
            onClick={logout}
            className="text-xs px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-white shadow-sm"
            title="Sign out"
          >
            Logout
          </button>
        </div>
      </div>
    </header>
  );
};

export default AdminHeader;
