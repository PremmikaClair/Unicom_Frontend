
import React, { useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { apiFetch } from "../../services/api";
import { setToken } from "../../services/api";
import { useAuth } from "./AuthContext";

const Callback: React.FC = () => {
  const [q] = useSearchParams();
  const code = q.get("code");
  const nav = useNavigate();
  const { user } = useAuth(); // to trigger me bootstrap if needed

  useEffect(() => {
    (async () => {
      if (!code) return nav("/login");
      // Exchange code -> access token (server sets refresh cookie)
      const res = await apiFetch<{ accessToken: string; user: any }>(
        `/oauth/university/callback?code=${encodeURIComponent(code)}`
      );
      setToken(res.accessToken);
      // Optional: put user into context by refetching /me or pass here
      nav("/admin/users", { replace: true });
    })().catch(() => nav("/login"));
  }, [code, nav]);

  return <div className="p-6">Signing you in…</div>;
};
export default Callback;