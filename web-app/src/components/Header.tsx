import React from "react";
import { useAuth } from "../features/auth/AuthContext";

const AdminHeader: React.FC = () => {
  const { user, loading, logout } = useAuth();

  const displayName = (() => {
    if (!user) return "";
    // Try common fields then fallback to email or id
    const name = [user.firstName, user.lastName].filter(Boolean).join(" ");
    return name || (user as any).name || user.email || String((user as any).id || "User");
  })();

  return (
    <header className="bg-white shadow-sm px-6 py-4 flex justify-between items-center sticky top-0 z-10">
      <h1 className="text-xl font-bold text-gray-800">Admin Dashboard</h1>
      <div className="flex items-center gap-4">
        <span className="text-sm text-gray-600">
          {loading ? "Loading…" : `Hello, ${displayName || "User"}`}
        </span>
        <button
          onClick={logout}
          className="text-xs px-2 py-1 border rounded hover:bg-gray-50"
          title="Sign out"
        >
          Logout
        </button>
      </div>
    </header>
  );
};

export default AdminHeader;
