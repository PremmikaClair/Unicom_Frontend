// src/features/auth/AuthContext.tsx
import React, {
  createContext, useContext, useEffect, useMemo, useState
} from "react";
import { getMe, loginWithPassword, logoutServer, setToken } from "../../services/api";
import type { User } from "../../types";

type AuthState = {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
};

const Ctx = createContext<AuthState | null>(null);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  // bootstrap user if token exists
  useEffect(() => {
    (async () => {
      try {
        const tok = localStorage.getItem("access_token");
        if (!tok) {
          setUser(null);
          return;
        }
        setToken(tok);
        const me = await getMe();
        setUser(me);
      } catch {
        setToken(null);
        setUser(null);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const login = async (email: string, password: string) => {
    console.log("📡 Calling backend /auth/login...");
    const res = await loginWithPassword(email, password);
    console.log("📦 Got response:", res);
    setToken(res.access_token);
    setUser(res.user ?? ({ id: "self", email } as any));
    console.log("✅ Token stored, user set");
  };


  const logout = async () => {
    try {
      await logoutServer();
    } catch {
      // ignore errors
    } finally {
      setToken(null);
      setUser(null);
    }
  };

  const value = useMemo(
    () => ({ user, loading, login, logout }),
    [user, loading]
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
};

export const useAuth = () => {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
};