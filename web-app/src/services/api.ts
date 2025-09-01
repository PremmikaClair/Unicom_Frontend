// src/services/api.ts (or keep your path, just replace content)

import type { User } from "../types"; // adjust path if needed
// If you have Role/Permission types, import them too
// import type { Role } from "../features/auth/types";

const BASE = "/api"; // <-- use Vite proxy (recommended for dev)

let accessToken: string | null = localStorage.getItem("access_token");

export function setToken(tok: string | null) {
  accessToken = tok;
  if (tok) localStorage.setItem("access_token", tok);
  else localStorage.removeItem("access_token");
}

function withAuthHeaders(headers?: HeadersInit): Record<string, string> {
  const h: Record<string, string> = {
    "Content-Type": "application/json",
    ...(headers as Record<string, string>),
  };
  if (accessToken) h["Authorization"] = `Bearer ${accessToken}`;
  return h;
}

async function doFetch(path: string, opts: RequestInit = {}) {
  return fetch(`${BASE}${path}`, {
    ...opts,
    headers: withAuthHeaders(opts.headers),
    credentials: "include", // send refresh cookie
  });
}

async function refreshAccessToken(): Promise<boolean> {
  const r = await fetch(`${BASE}/auth/refresh`, {
    method: "POST",
    credentials: "include",
  });
  if (!r.ok) return false;
  const data = await r.json().catch(() => null);
  if (data?.accessToken) {
    setToken(data.accessToken);
    return true;
  }
  return false;
}

export async function apiFetch<T = any>(path: string, opts: RequestInit = {}): Promise<T> {
  let res = await doFetch(path, opts);

  if (res.status === 401) {
    // try refresh once
    const ok = await refreshAccessToken();
    if (ok) res = await doFetch(path, opts);
  }

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(`API ${res.status}: ${txt || res.statusText}`);
  }
  return res.json() as Promise<T>;
}

/* ----------------- Your feature calls (now using apiFetch) ----------------- */

export async function getUsersPaged(params?: {
  limit?: number; cursor?: string; q?: string; role?: string;
}) {
  const qs = new URLSearchParams();
  if (params?.limit) qs.set("limit", String(params.limit));
  if (params?.cursor) qs.set("cursor", params.cursor);
  if (params?.q) qs.set("q", params.q);
  if (params?.role) qs.set("role", params.role);
  return apiFetch<{ items: User[]; nextCursor?: string }>(`/users?${qs.toString()}`);
}

export async function updateUser(id: number, patch: Partial<User>): Promise<User> {
  return apiFetch<User>(`/users/${id}`, {
    method: "PUT",
    body: JSON.stringify(patch),
  });
}

export async function deleteUser(id: number): Promise<void> {
  await apiFetch<void>(`/users/${id}`, { method: "DELETE" });
}

// If you have a Role type, prefer it here:
export type SimpleRole = { id?: string; name: string; label: string; permissions: any[] };
export async function getRoles(): Promise<SimpleRole[]> {
  return apiFetch<SimpleRole[]>("/roles");
}

export async function getUserPermissions(userId: number) {
  return apiFetch<any>(`/users/${userId}/permissions`);
}

/* ----------------- Auth helpers (called from Login / AuthContext) ----------------- */

export async function loginWithPassword(email: string, password: string) {
  const res = await apiFetch<{ user: User; accessToken: string }>(`/auth/login`, {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  setToken(res.accessToken);
  return res;
}

export async function getMe() {
  return apiFetch<User>("/auth/me");
}

export async function logoutServer() {
  await apiFetch("/auth/logout", { method: "POST" });
  setToken(null);
}