// src/features/auth/AuthContext.tsx
import React, { createContext, useContext, useState, useEffect, useMemo } from "react";
import { getMe, loginWithPassword, logoutServer } from "../../services/api";
import type { User } from "../../types";
import { setToken } from "../../services/api";

type AuthState = {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  hasRole: (r: string) => boolean;
  hasPermission: (resource: string, action: string) => boolean;
};

const Ctx = createContext<AuthState | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const me = await getMe();
        setUser(me);
      } catch {
        setUser(null);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const login = async (email: string, password: string) => {
    const res = await loginWithPassword(email, password);
    setToken(res.accessToken);
    setUser(res.user);
  };

  const logout = async () => {
    await logoutServer().catch(() => {});
    setToken(null);
    setUser(null);
  };

  const hasRole = (r: string) => !!user?.roles.includes(r);

  // in your schema, roles = string[], permissions live in Role objects
  // so backend probably maps user.roles → full Role objects when needed
  const hasPermission = (resource: string, action: string) => {
    // 🔮 if later backend sends expanded roles with permissions:
    // user?.rolesExpanded.some(role => role.permissions.some(p => p.resource === resource && p.action === action))
    return false; // placeholder until backend sends role->permissions map
  };

  const value = useMemo(() => ({ user, loading, login, logout, hasRole, hasPermission }), [user, loading]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
};

export const useAuth = () => {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
};