// src/features/auth/RequireAuth.tsx
import { Navigate, Outlet, useLocation } from "react-router-dom";

const TOKEN_KEY = "access_token";

export default function RequireAuth() {
  const location = useLocation();
  const hasToken = Boolean(localStorage.getItem(TOKEN_KEY));

  if (!hasToken) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  return <Outlet />;
}