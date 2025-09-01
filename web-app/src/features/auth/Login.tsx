// src/features/auth/Login.tsx
import React, { useState } from "react";
import { useAuth } from "./AuthContext";
import { useNavigate } from "react-router-dom";

const Login: React.FC = () => {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState("admin@example.com");
  const [password, setPassword] = useState("admin");
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      // Call AuthContext.login -> sets token + user
      await login(email, password);

      // ✅ Force redirect to /users after login
      navigate("/users", { replace: true });
    } catch (e: any) {
      setErr(e.message || "Login failed");
    } finally {
      setBusy(false);
    }
  };

  const startOAuth = () => {
    const API = import.meta.env.VITE_API_BASE_URL as string;
    const APP = import.meta.env.VITE_APP_BASE_URL as string;
    window.location.href = `${API}/oauth/university/start?redirect_uri=${encodeURIComponent(
      APP + "/auth/callback"
    )}`;
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <form
        onSubmit={onSubmit}
        className="w-full max-w-sm bg-white rounded-2xl p-6 shadow"
      >
        <h1 className="text-2xl font-semibold mb-4">Admin Login</h1>

        <label className="block mb-2 text-sm font-medium">Email</label>
        <input
          className="w-full border rounded-lg px-3 py-2 mb-4"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <label className="block mb-2 text-sm font-medium">Password</label>
        <input
          type="password"
          className="w-full border rounded-lg px-3 py-2 mb-4"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />

        {err && <div className="text-red-600 text-sm mb-3">{err}</div>}

        <button
          disabled={busy}
          className="w-full py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {busy ? "Signing in…" : "Sign In"}
        </button>

        <div className="mt-4 text-center">
          <button
            type="button"
            onClick={startOAuth}
            className="text-sm underline"
          >
            Sign in with University OAuth (later)
          </button>
        </div>
      </form>
    </div>
  );
};

export default Login;