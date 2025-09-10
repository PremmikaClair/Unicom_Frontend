// Centralized API client for:
// Auth, Users, Memberships (raw/tags/codes), Abilities (MVP), Posts CRUD + actions, Positions

import type {
  User,
  Membership,
  Position,
  TagItem,
  AbilitiesResp,
  PostDoc,
  Paged,
} from "../types";

const BASE = "/api";

// ---------- token management ----------
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
  if (accessToken) h.Authorization = `Bearer ${accessToken}`;
  return h;
}

async function rawFetch(path: string, opts: RequestInit = {}) {
  return fetch(`${BASE}${path}`, {
    ...opts,
    headers: withAuthHeaders(opts.headers),
    credentials: "include", // allow refresh cookie
  });
}

async function tryParseJSON<T>(res: Response): Promise<T> {
  const txt = await res.text();
  if (!txt) return null as unknown as T;
  try { return JSON.parse(txt) as T; } catch { throw new Error(txt || res.statusText); }
}

async function refreshAccessToken(): Promise<boolean> {
  const r = await fetch(`${BASE}/auth/refresh`, { method: "POST", credentials: "include" });
  if (!r.ok) return false;
  const data = await r.json().catch(() => null);
  const tok = data?.accessToken ?? data?.access_token;
  if (!tok) return false;
  setToken(tok);
  return true;
}

export async function apiFetch<T = any>(path: string, opts: RequestInit = {}): Promise<T> {
  let res = await rawFetch(path, opts);
  if (res.status === 401) {
    const ok = await refreshAccessToken();
    if (ok) res = await rawFetch(path, opts);
  }
  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(txt || `HTTP ${res.status}`);
  }
  return tryParseJSON<T>(res);
}

// ======================= Auth =======================

export async function loginWithPassword(email: string, password: string) {
  const data = await apiFetch<{ accessToken?: string; access_token?: string; user?: User }>(
    `/auth/login`,
    { method: "POST", body: JSON.stringify({ email, password }) }
  );
  const tok = data.accessToken ?? data.access_token;
  if (!tok) throw new Error("No access token in response");
  setToken(tok);
  return data;
}

export async function getMe() {
  return apiFetch<User>(`/auth/me`);
}

export async function logoutServer() {
  await apiFetch(`/auth/logout`, { method: "POST" });
  setToken(null);
}

// ======================= Users =======================

export async function getUsersPaged(params?: { limit?: number; cursor?: string; q?: string; role?: string }) {
  const qs = new URLSearchParams();
  if (params?.limit) qs.set("limit", String(params.limit));
  if (params?.cursor) qs.set("cursor", params.cursor);
  if (params?.q) qs.set("q", params.q);
  if (params?.role) qs.set("role", params.role);
  return apiFetch<Paged<User>>(`/users?${qs.toString()}`);
}

export async function getUserById(id: number) {
  return apiFetch<User>(`/users/${id}`);
}

export async function createUser(payload: Partial<User>) {
  return apiFetch<User>(`/users`, { method: "POST", body: JSON.stringify(payload) });
}

export async function updateUser(id: number, patch: Partial<User>) {
  return apiFetch<User>(`/users/${id}`, { method: "PUT", body: JSON.stringify(patch) });
}

export async function deleteUser(id: number) {
  await apiFetch<void>(`/users/${id}`, { method: "DELETE" });
}

// legacy/flattened permissions endpoint (if enabled)
export async function getUserPermissions(userId: number) {
  return apiFetch<string[]>(`/users/${userId}/permissions`);
}

// ======================= Positions =======================

export async function getPositions(): Promise<Position[]> {
  return apiFetch<Position[]>(`/positions`);
}

// ======================= Memberships by student_id =======================

export async function getMembershipsRaw(studentId: string) {
  return apiFetch<{ student_id: string; user_id: string; memberships: Membership[] }>(
    `/users/${encodeURIComponent(studentId)}/memberships?view=raw`
  );
}

export async function getMembershipTags(studentId: string, lang: "en" | "th" | string = "en") {
  return apiFetch<{ student_id: string; user_id: string; tags: TagItem[] }>(
    `/users/${encodeURIComponent(studentId)}/memberships?view=tags&lang=${encodeURIComponent(lang)}`
  );
}

export async function getMembershipCodes(studentId: string, lang: "en" | "th" | string = "en") {
  return apiFetch<{ student_id: string; user_id: string; codes: { org_path: string; position_key: string; code: string }[] }>(
    `/users/${encodeURIComponent(studentId)}/memberships?view=codes&lang=${encodeURIComponent(lang)}`
  );
}

// ======================= Abilities (MVP) =======================

export async function getAbilities(orgPath: string) {
  const qs = new URLSearchParams({ org_path: orgPath });
  return apiFetch<AbilitiesResp>(`/abilities?${qs.toString()}`);
}
export async function getAbilitiesWhere(action: string) {
  const qs = new URLSearchParams({ action });
  return apiFetch<{ action: string; orgs: { org_path: string; label?: string }[]; version?: string }>(
    `/abilities/where?${qs.toString()}`
  );
}

// ======================= Posts =======================

// services/api.ts
export async function listPosts(page = 1, limit = 20, all = false) {
  const qs = new URLSearchParams({ page: String(page), limit: String(limit) });
  if (all) qs.set("all", "true");
  return apiFetch<PostDoc[]>(`/posts?${qs.toString()}`);
}

export async function getPost(id: string) {
  return apiFetch<PostDoc>(`/posts/${id}`);
}

// Backend requires legacy fields for now (uid, name, username, message)
export async function createPost(payload: {
  uid: string; name: string; username: string; message: string;
  posted_as?: { org_path?: string; position_key?: string; label?: string; tag?: string };
  visibility?: PostDoc["visibility"];
  org_of_content?: string;
  status?: PostDoc["status"];
}) {
  return apiFetch<PostDoc>(`/posts`, { method: "POST", body: JSON.stringify(payload) });
}

export async function updatePost(id: string, patch: Partial<PostDoc>) {
  return apiFetch<PostDoc>(`/posts/${id}`, { method: "PUT", body: JSON.stringify(patch) });
}

export async function deletePost(id: string) {
  await apiFetch<void>(`/posts/${id}`, { method: "DELETE" });
}

export async function likePost(id: string, userId: string) {
  return apiFetch<PostDoc>(`/posts/${id}/like`, { method: "POST", body: JSON.stringify({ userId }) });
}

export async function unlikePost(id: string, userId: string) {
  return apiFetch<PostDoc>(`/posts/${id}/unlike`, { method: "POST", body: JSON.stringify({ userId }) });
}

export async function hidePostApi(id: string) {
  await apiFetch<void>(`/posts/${id}/hide`, { method: "POST" });
}

export async function unhidePostApi(id: string) {
  await apiFetch<void>(`/posts/${id}/unhide`, { method: "POST" });

}


import type { OrgUnitNode, Policy } from "../types";

/* -------- Org Units -------- */
export async function getOrgTree(): Promise<OrgUnitNode[]> {
  // Adjust the path to your backend route. If your server exposes /org/units/tree, use that.
  return apiFetch<OrgUnitNode[]>("/org/units/tree");
}

/* -------- Policies (CRUD) -------- */
export async function listPolicies(params?: { org_prefix?: string; position_key?: string }) {
  const qs = new URLSearchParams();
  if (params?.org_prefix) qs.set("org_prefix", params.org_prefix);
  if (params?.position_key) qs.set("position_key", params.position_key);
  const q = qs.toString();
  return apiFetch<Policy[]>(`/policies${q ? "?" + q : ""}`);
}

export async function createPolicy(p: Policy) {
  return apiFetch<Policy>("/policies", {
    method: "POST",
    body: JSON.stringify(p),
  });
}

// Upsert by (position_key, where.org_prefix, scope)
export async function upsertPolicy(p: Policy) {
  return apiFetch<Policy>("/policies", {
    method: "PUT",
    body: JSON.stringify(p),
  });
}

export async function deletePolicy(org_prefix: string, position_key?: string) {
  const qs = new URLSearchParams({ org_prefix });
  if (position_key) qs.set("position_key", position_key);
  await apiFetch<void>(`/policies?${qs.toString()}`, { method: "DELETE" });
}