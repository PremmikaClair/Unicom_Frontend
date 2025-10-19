// Centralized API client for:
// Auth, Users, Memberships (raw/tags/codes), Abilities (MVP), Posts CRUD + actions, Positions

import type {
  User,
  Membership,
  Position,
  AbilitiesResp,
  PostDoc,
  Paged,
  OrgUnit,
  MembershipDoc,
  MembershipWithUser,
  OrgUnitNode,
  Policy,
  EventDoc,
  CommentDoc,
} from "../types";

const BASE = (import.meta as any).env?.VITE_API_BASE_URL || "/api";
const normalizeMembership = (doc: MembershipDoc): Membership => ({
  _id: (doc as any)._id,
  org_path: (doc as any).org_path,
  position_key: (doc as any).position_key,
  // Prefer boolean 'active' if provided by backend; fallback to status string
  active: typeof (doc as any).active === 'boolean' ? (doc as any).active : (doc as any).status ? (doc as any).status !== 'inactive' : true,
});


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

// New backend (main-webbase) does not support refresh endpoints; disable refresh.
async function refreshAccessToken(): Promise<boolean> {
  return false;
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
  // main-webbase login is at /login and returns { user, accessToken }
  const data = await apiFetch<{ accessToken?: string; access_token?: string; user?: any }>(
    `/login`,
    { method: "POST", body: JSON.stringify({ email, password }) }
  );
  const tok = data.accessToken ?? (data as any)?.access_token;
  if (!tok) throw new Error("No access token in response");
  setToken(tok);
  return data as any;
}

export async function getMe() {
  // Map main-webbase UserProfileDTO => frontend User
  const prof = await apiFetch<any>(`/users/myprofile`);
  const u: User = {
    _id: prof?.id || prof?._id,
    id: Number.NaN as any, // not provided by new backend; avoid accidental use
    firstName: prof?.firstname ?? prof?.firstName ?? "",
    lastName: prof?.lastname ?? prof?.lastName ?? "",
    email: prof?.email ?? "",
    student_id: prof?.student_id,
    advisor_id: prof?.advisor_id,
    gender: prof?.gender,
    type_person: prof?.type_person,
  };
  return u;
}

export async function logoutServer() {
  // No logout route in main-webbase; clear token client-side.
  setToken(null);
}

// ======================= Users =======================

export async function getUsersPaged(params?: { limit?: number; cursor?: string; q?: string; role?: string }) {
  // Ask backend to include memberships to avoid N+1 fetches
  const resp = await apiFetch<any>(`/users?include=memberships`).catch(() => ({ data: [] }));
  const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
  const mapUser = (r: any): User => ({
    _id: r?._id,
    id: Number.NaN as any, // no numeric app id in new backend
    firstName: r?.firstname ?? r?.firstName ?? "",
    lastName: r?.lastname ?? r?.lastName ?? "",
    email: r?.email ?? "",
    student_id: r?.student_id,
    advisor_id: r?.advisor_id,
    gender: r?.gender,
    type_person: r?.type_person,
    memberships: Array.isArray(r?.memberships) ? (r.memberships as any[]).map(normalizeMembership) : undefined,
  });
  let items = rows.map(mapUser);
  const q = params?.q?.trim().toLowerCase();
  if (q) {
    items = items.filter(u => (
      (u.firstName + " " + u.lastName).toLowerCase().includes(q) ||
      (u.email || '').toLowerCase().includes(q) ||
      (u.student_id || '').toLowerCase().includes(q)
    ));
  }
  const limit = Math.max(1, Number(params?.limit) || 20);
  const startIdx = 0; // simplified; ignore cursor for now
  const pageItems = items.slice(startIdx, startIdx + limit);
  const nextCursor = items.length > startIdx + limit ? String(startIdx + limit) : undefined;
  return { items: pageItems, nextCursor } as Paged<User>;
}

export async function getUser(id: string | number) {
  // Fallback: fetch all and pick by _id or student_id (GET /users returns {data})
  const resp = await apiFetch<any>(`/users`).catch(() => ({ data: [] }));
  const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
  const sid = String(id);
  const r = rows.find(r => r?._id === sid || r?.student_id === sid) || rows[0] || null;
  if (!r) throw new Error("User not found");
  const u: User = {
    _id: r?._id,
    id: Number.NaN as any,
    firstName: r?.firstname ?? r?.firstName ?? "",
    lastName: r?.lastname ?? r?.lastName ?? "",
    email: r?.email ?? "",
    student_id: r?.student_id,
    advisor_id: r?.advisor_id,
    gender: r?.gender,
    type_person: r?.type_person,
  };
  return u;
}

export async function createUser(_payload: Partial<User>) {
  // Not supported by main-webbase. Use /register instead at auth flow.
  throw new Error("User creation is not supported by this backend");
}

export async function updateUser(_id: string | number, _patch: Partial<User>) {
  // Not supported by main-webbase
  throw new Error("Updating user is not supported by this backend");
}

export async function deleteUser(id: string | number) {
  // New backend expects ObjectID hex as :id; allow numeric by resolving first
  let target = String(id);
  console.log(`delete user : ${id}`)
  const isHex = /^[a-fA-F0-9]{24}$/.test(target);
  if (!isHex) {
    const resp = await apiFetch<any>(`/users`).catch(() => ({ data: [] }));
    const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
    const found = rows.find(r => String(r?.id) === target || r?.student_id === target || r?.email === target);
    if (found?._id) target = String(found._id);
  }
  await apiFetch<void>(`/users/${encodeURIComponent(target)}`, { method: "DELETE" });
}

// legacy/flattened permissions endpoint (if enabled)
export async function getUserPermissions(userId: number) {
  return apiFetch<string[]>(`/users/${userId}/permissions`);
}

// ======================= Positions =======================

export async function getPositions(): Promise<Position[]> {
  const resp = await apiFetch<any>(`/positions`).catch(() => ({ data: [] }));
  const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
  return rows as Position[];
}

// ======================= Abilities (MVP) =======================

export async function getAbilities(orgPath: string) {
  // Derive abilities from my profile memberships' policies
  const me = await getMe();
  // Fetch full profile to get memberships (getMe already mapped basic fields; pull raw too)
  const prof = await apiFetch<any>(`/users/myprofile`).catch(() => null);
  const policies: any[] = prof?.memberships?.map((m: any) => ({
    org_prefix: m?.policies?.org_prefix,
    scope: m?.policies?.scope,
    actions: m?.policies?.actions || [],
    enabled: m?.policies?.enabled !== false,
  })) || [];
  const abilities: Record<string, boolean> = {};
  const path = (orgPath || '').trim() || '/';
  for (const p of policies) {
    if (!p?.enabled || !p?.org_prefix) continue;
    const prefix = String(p.org_prefix);
    const scope = String(p.scope || 'exact');
    const ok = scope === 'subtree' ? path.startsWith(prefix) : path === prefix;
    if (!ok) continue;
    for (const a of p.actions || []) abilities[a] = true;
  }
  return { org_path: orgPath, abilities, version: 'local' } as AbilitiesResp;
}
export async function getAbilitiesWhere(action: string) {
  const prof = await apiFetch<any>(`/users/myprofile`).catch(() => null);
  const policies: any[] = prof?.memberships?.map((m: any) => ({
    org_prefix: m?.policies?.org_prefix,
    scope: m?.policies?.scope,
    actions: m?.policies?.actions || [],
    enabled: m?.policies?.enabled !== false,
  })) || [];
  const orgs: { org_path: string; label?: string }[] = [];
  for (const p of policies) {
    if (!p?.enabled || !Array.isArray(p.actions)) continue;
    if (p.actions.includes(action)) {
      orgs.push({ org_path: p.org_prefix });
    }
  }
  return { action, orgs, version: 'local' };
}

// ======================= Posts =======================

// Helpers to normalize backend shapes to FE PostDoc
function toHexId(v: any): string {
  if (!v) return "";
  if (typeof v === "string") return v;
  if (typeof v === "object" && v.$oid) return String(v.$oid);
  return String(v);
}

function mapPostResponseToDoc(r: any): PostDoc {
  // Maps dto.PostResponse -> PostDoc
  const visibility = r?.visibility
    ? { access: r.visibility.access || r.visibility, audience: r.visibility.audience || [] }
    : undefined;
  return {
    _id: toHexId(r?.id || r?._id),
    uid: r?.userId || r?.uid || "",
    name: r?.name,
    username: r?.username,
    message: r?.postText || r?.message || "",
    timestamp: r?.createdAt || r?.created_at || r?.timestamp || new Date().toISOString(),
    likes: r?.likeCount ?? r?.likes ?? 0,
    likedBy: Array.isArray(r?.likedBy) ? r.likedBy : [],
    media: Array.isArray(r?.media) ? r.media : undefined,
    commentCount: r?.commentCount ?? r?.comment_count ?? 0,
    posted_as: r?.postAs || r?.posted_as,
    visibility,
    org_of_content: r?.org_of_content,
    status: r?.status || "active",
    created_at: r?.createdAt || r?.created_at,
    updated_at: r?.updatedAt || r?.updated_at,
  } as PostDoc;
}

function mapFeedItemToDoc(x: any): PostDoc {
  const id = toHexId(x?._id);
  const visibility = typeof x?.visibility === "string"
    ? { access: x.visibility, audience: [] }
    : x?.visibility;
  const tag = x?.tag ?? x?.tags;
  const posted_as = x?.posted_as || (tag ? { label: tag } : undefined);
  return {
    _id: id,
    uid: toHexId(x?.user_id || x?.uid || ""),
    name: x?.name,
    username: x?.username,
    message: x?.post_text || x?.message || x?.postText || "",
    timestamp: x?.created_at || x?.timestamp || new Date().toISOString(),
    likes: x?.like_count ?? x?.likes ?? 0,
    likedBy: [],
    media: Array.isArray(x?.media) ? x.media : undefined,
    commentCount: x?.comment_count ?? 0,
    posted_as,
    visibility,
    org_of_content: x?.org_of_content,
    status: x?.status || "active",
    created_at: x?.created_at,
    updated_at: x?.updated_at,
  } as PostDoc;
}

// Cursor-based listing from main-webbase (/posts?limit=..&cursor=..)
export async function listPostsCursor(limit = 20, cursor?: string) {
  const qs = new URLSearchParams();
  if (limit) qs.set("limit", String(limit));
  if (cursor) qs.set("cursor", cursor);
  const res = await apiFetch<any>(`/posts${qs.toString() ? `?${qs.toString()}` : ""}`);
  const list = (res && (res.items ?? res.Items ?? res.data)) || [];
  const items = Array.isArray(list) ? list.map(mapFeedItemToDoc) : [];
  const nextCursor = res?.next_cursor ?? res?.NextCursor ?? res?.nextCursor ?? res?.cursor;
  return { items, nextCursor } as { items: PostDoc[]; nextCursor?: string };
}

// Backward-compatible pager wrapper (uses first page only)
export async function listPosts(_page = 1, limit = 20, _all = false) {
  const page1 = await listPostsCursor(limit);
  return page1.items;
}

export async function getPost(id: string) {
  const raw = await apiFetch<any>(`/posts/${id}`);
  return mapPostResponseToDoc(raw);
}

// -------- Author enrichment --------
async function getUserProfileRaw(idHex: string) {
  if (!idHex) return null;
  try { return await apiFetch<any>(`/users/profile/${encodeURIComponent(idHex)}`); } catch { return null; }
}

export async function listPostsCursorEnriched(limit = 20, cursor?: string) {
  const { items, nextCursor } = await listPostsCursor(limit, cursor);
  const ids = Array.from(new Set(items.map(p => p.uid).filter(Boolean)));
  const profiles = await Promise.all(ids.map(id => getUserProfileRaw(id)));
  const byId: Record<string, any> = {};
  profiles.forEach((p, i) => { if (p && ids[i]) byId[ids[i]] = p; });
  const enriched = items.map(p => {
    const prof = byId[p.uid];
    if (prof) {
      const name = [prof.firstname, prof.lastname].filter(Boolean).join(' ').trim();
      return { ...p, name: name || p.name };
    }
    return p;
  });
  return { items: enriched, nextCursor };
}

// Create post with new DTO
export async function createPost(payload: {
  postText: string;
  postAs: { org_path: string; position_key: string; label?: string };
  visibility: { access: "public" | "private"; audience?: string[] };
  categoryIds?: string[];
  org_of_content?: string;
}) {
  const body: any = {
    postText: payload.postText,
    postAs: payload.postAs,
    visibility: payload.visibility,
    categoryIds: payload.categoryIds || [],
    org_of_content: payload.org_of_content || payload.postAs?.org_path,
  };
  const raw = await apiFetch<any>(`/posts`, { method: "POST", body: JSON.stringify(body) });
  return mapPostResponseToDoc(raw);
}

// Full update requires full DTO on this backend
export async function updatePostFull(id: string, data: {
  postText: string;
  pictureUrl?: string[];
  videoUrl?: string[];
  categoryIds?: string[];
  postAs: { org_path: string; position_key: string; label?: string };
  visibility: { access: string; audience?: string[] };
  org_of_content?: string;
  status?: string;
}) {
  const raw = await apiFetch<any>(`/posts/${id}`, { method: "PUT", body: JSON.stringify(data) });
  return mapPostResponseToDoc(raw);
}

export async function deletePost(id: string) {
  await apiFetch<void>(`/posts/${id}`, { method: "DELETE" });
}

// Likes: new backend uses POST /likes with body { docId, action }
export async function sendLike(docId: string, action: "like" | "unlike") {
  return apiFetch<any>(`/likes`, { method: "POST", body: JSON.stringify({ doc_id: docId, action }) });
}

// Hide/Unhide via full update: fetch current detail then PUT with status changed
export async function hidePostApi(id: string) {
  const cur = await getPost(id);
  await updatePostFull(id, {
    postText: cur.message,
    postAs: {
      org_path: cur.posted_as?.org_path || cur.org_of_content || "/",
      position_key: cur.posted_as?.position_key || "",
      label: cur.posted_as?.label || cur.posted_as?.tag,
    },
    visibility: { access: cur.visibility?.access || "public", audience: (cur.visibility as any)?.audience || [] },
    categoryIds: [],
    org_of_content: cur.org_of_content,
    status: "hidden",
  });
}

export async function unhidePostApi(id: string) {
  const cur = await getPost(id);
  await updatePostFull(id, {
    postText: cur.message,
    postAs: {
      org_path: cur.posted_as?.org_path || cur.org_of_content || "/",
      position_key: cur.posted_as?.position_key || "",
      label: cur.posted_as?.label || cur.posted_as?.tag,
    },
    visibility: { access: cur.visibility?.access || "public", audience: (cur.visibility as any)?.audience || [] },
    categoryIds: [],
    org_of_content: cur.org_of_content,
    status: "active",
  });
}

// ======================= Comments =======================

export async function listComments(postId: string, limit = 10, cursor?: string) {
  const qs = new URLSearchParams({ limit: String(limit) });
  if (cursor) qs.set("cursor", cursor);
  const res = await apiFetch<any>(`/posts/${postId}/comments?${qs.toString()}`);
  const items = Array.isArray(res?.comments) ? res.comments : [];
  const nextCursor = res?.next_cursor ?? res?.cursor;
  return { items: items as CommentDoc[], nextCursor };
}

export async function createComment(postId: string, text: string) {
  return apiFetch<CommentDoc>(`/posts/${postId}/comments`, {
    method: "POST",
    body: JSON.stringify({ text }),
  });
}

export async function updateComment(commentId: string, text: string) {
  return apiFetch<CommentDoc>(`/comments/${commentId}`, {
    method: "PUT",
    body: JSON.stringify({ text }),
  });
}

export async function deleteComment(commentId: string) {
  await apiFetch<void>(`/comments/${commentId}`, { method: "DELETE" });
}



/* -------- Org Units -------- */
export async function getOrgTree(): Promise<OrgUnitNode[]> {
  // Adjust the path to your backend route. If your server exposes /org/units/tree, use that.
  return apiFetch<OrgUnitNode[]>("/org/units/tree?start=%2F");
}

export async function createOrgUnit(node: OrgUnit) {
  // Map FE OrgUnit -> BE OrgUnitDTO
  const parent_path = (node.parent_path || "/").trim() || "/";
  const chooseName = (n?: Record<string, string>) => (n?.en || n?.th || n && Object.values(n)[0]) || "";
  const name = chooseName(node.name as any) || chooseName(node.short_name as any) || "";
  const slug = (node.slug || (node.path || '').split('/').filter(Boolean).slice(-1)[0] || name.toLowerCase().replace(/\s+/g, '-')).toLowerCase();
  const body = { parent_path, name, slug, type: node.type || "unit" } as any;
  return apiFetch<any>(`/org/units`, { method: "POST", body: JSON.stringify(body) });
}
/* -------- Policies (CRUD) -------- */
export async function listPolicies(params?: { org_prefix?: string; position_key?: string }) {
  const qs = new URLSearchParams();
  if (params?.org_prefix) qs.set("org_prefix", params.org_prefix);
  if (params?.position_key) qs.set("position_key", params.position_key);
  const rows = await apiFetch<any[]>(`/policies${qs.toString() ? `?${qs.toString()}` : ''}`).catch(() => [] as any[]);
  return rows.map((r) => ({
    _id: r?._id,
    position_key: r?.position_key,
    where: { org_prefix: r?.org_prefix },
    scope: r?.scope || 'exact',
    effect: 'allow',
    actions: Array.isArray(r?.actions) ? r.actions : [],
    enabled: r?.enabled !== false,
    created_at: r?.created_at || r?.createdAt,
  })) as Policy[];
}

export async function createPolicy(p: Policy) {
  // No POST /policies; treat as upsert via PUT
  return upsertPolicy(p);
}

// Upsert by (position_key, where.org_prefix, scope)
export async function upsertPolicy(p: Policy) {
  // Map to main-webbase PolicyUpdateDTO
  const body = {
    org_path: p?.where?.org_prefix || "/",
    key: p?.position_key,
    actions: p?.actions || [],
    enabled: p?.enabled !== false,
  };
  const res = await apiFetch<any>("/policies", { method: "PUT", body: JSON.stringify(body) });
  // Map back to FE Policy shape
  const saved: Policy = {
    position_key: body.key || "",
    where: { org_prefix: body.org_path || "/" },
    scope: (p?.scope as any) || 'exact',
    effect: 'allow',
    actions: Array.isArray(res?.policy?.actions) ? res.policy.actions : (body.actions || []),
    enabled: res?.policy?.enabled ?? body.enabled,
    created_at: res?.policy?.createdAt,
  };
  return saved;
}

export async function deletePolicy(org_prefix: string, position_key?: string) {
  const qs = new URLSearchParams({ org_prefix });
  if (position_key) qs.set("position_key", position_key);
  await apiFetch<void>(`/policies?${qs.toString()}`, { method: "DELETE" });
}


/* -------- MEMBERSHIPS (CRUD) -------- */

// ===== READ =====
export async function getMembershipsRaw(studentId: string) {
  // Resolve user by student_id, then fetch profile for that user to derive memberships.
  const resp = await apiFetch<any>(`/users`).catch(() => ({ data: [] }));
  const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
  const u = rows.find(x => x?.student_id === studentId);
  if (!u || !u._id) return { student_id: studentId, memberships: [] };
  const prof = await apiFetch<any>(`/users/profile/${encodeURIComponent(String(u._id))}`).catch(() => null);
  const details = Array.isArray(prof?.memberships) ? prof.memberships : [];
  const mems: Membership[] = details.map((m: any) => normalizeMembership({
    _id: m?.id || m?._id,
    org_path: m?.org_unit?.org_path,
    position_key: m?.position?.key,
    active: true,
  } as any));
  return { student_id: studentId, memberships: mems };
}

// List memberships by org path (active=true by default on the backend)
export async function listMembershipsByOrg(org_path: string) {
  // Not available; return empty list for now.
  return [] as Membership[];
}

export async function listMembershipsWithUsers(org_path: string, active: boolean = true) {
  const qs = new URLSearchParams({ org_path });
  if (!active) qs.set("active", "all");
  const rows = await apiFetch<any[]>(`/memberships/users?${qs.toString()}`).catch(() => [] as any[]);
  return rows.map(row => {
    const m = normalizeMembership(row as any);
    const user = (row as any).user || {};
    const out: MembershipWithUser = { ...m, user_id: (row as any).user_id } as any;
    if (user) {
      out.user = {
        _id: user._id,
        id: (user as any).id,
        firstName: user.firstname ?? user.firstName,
        lastName: user.lastname ?? user.lastName,
        email: user.email,
        student_id: user.student_id,
      };
    }
    return out;
  });
}

// ===== CREATE =====
export async function createMembership(body: {
  user_ref: string;           // student_id OR _id OR numeric id
  org_path: string;
  position_key: string;
  joined_at?: string;
}) {
  // Map to main-webbase MembershipRequestDTO { user_id, org_path, position_key, active }
  let ref = (body.user_ref || '').trim();
  const looksLikeObjectId = /^[a-fA-F0-9]{24}$/; 
  let user_id = '';
  if (looksLikeObjectId.test(ref)) {
    user_id = ref;
  } else {
    // Fetch users and try to resolve by student_id, email, or _id fallback
    const resp = await apiFetch<any>(`/users`).catch(() => ({ data: [] }));
    const rows: any[] = Array.isArray(resp) ? resp : (resp?.data || []);
    const found = rows.find(r => r?.student_id === ref) || rows.find(r => r?.email === ref) || rows.find(r => String(r?._id) === ref);
    if (!found) throw new Error("Cannot resolve user by reference");
    user_id = String(found?._id || '');
  }
  if (!user_id) throw new Error("Missing user_id for membership assignment");
  const payload = { user_id, org_path: body.org_path, position_key: body.position_key, active: true };
  const doc = await apiFetch<any>(`/memberships`, { method: "POST", body: JSON.stringify(payload) });
  return normalizeMembership({
    _id: doc?.data?._id || doc?._id || doc?.id,
    org_path: doc?.data?.org_path || doc?.org_path || body.org_path,
    position_key: doc?.data?.position_key || doc?.position_key || body.position_key,
    active: doc?.data?.active ?? doc?.active ?? true,
  } as any);
}

// ===== DEACTIVATE =====
export async function deactivateMembership(id: string) {
  const doc = await apiFetch<any>(`/memberships/${id}`, { method: "PATCH", body: JSON.stringify({ active: false }) });
  return normalizeMembership({ _id: id, active: doc?.active ?? false } as any);
}


// ======================= Events =======================

function mapEvent(row: any): EventDoc {
  // Support two shapes:
  // 1) Raw event doc
  // 2) { event: <doc>, schedules: [...] }
  const x = row?.event ? row.event : row;
  const schedulesRaw = row?.schedules ?? x?.schedules;
  const schedules = Array.isArray(schedulesRaw)
    ? schedulesRaw.map((s: any) => ({
        date: s?.date,
        start_time: s?.start_time || s?.time_start,
        end_time: s?.end_time || s?.time_end,
        time_start: s?.time_start, // keep originals too
        time_end: s?.time_end,
        location: s?.location,
        description: s?.description,
      }))
    : undefined;
  return {
    id: toHexId(x?.id || x?._id),
    _id: toHexId(x?._id || x?.id),
    node_id: toHexId(x?.node_id),
    topic: x?.topic || "",
    description: x?.description,
    max_participation: x?.max_participation,
    posted_as: x?.posted_as || x?.postAs || x?.postedas,
    visibility: x?.visibility,
    org_of_content: x?.org_of_content,
    status: x?.status,
    have_form: x?.have_form,
    created_at: x?.created_at,
    updated_at: x?.updated_at,
    schedules,
  };
}

export async function listEvents(): Promise<EventDoc[]> {
  const rows = await apiFetch<any>(`/event`).catch(() => [] as any);
  const list = Array.isArray(rows) ? rows : (Array.isArray(rows?.data) ? rows.data : []);
  return list.map(mapEvent);
}

export async function createEvent(body: {
  node_id: string;
  topic: string;
  description?: string;
  max_participation?: number;
  posted_as?: { org_path?: string; position_key?: string; label?: string };
  visibility?: { access?: string; audience?: any[] };
  org_of_content?: string;
  schedules?: Array<{ date: string; time_start: string; time_end: string; location?: string; description?: string }>;
}) {
  const payload = { ...body, schedules: body.schedules || [] };
  const res = await apiFetch<any>(`/event`, { method: "POST", body: JSON.stringify(payload) });
  return res;
}

export async function deleteEvent(id: string) {
  console.log(`delete ${encodeURIComponent(id)}`)
  await apiFetch<void>(`/event/${encodeURIComponent(id)}`, { method: "DELETE" });
}

// -------- Event Management (participants) --------

export type ManagedEventSummary = {
  eventId: string;
  topic?: string;
  max_participation?: number;
  pendingCount?: number;
  acceptedCount?: number;
};

export type EventParticipantRow = {
  user_id: string;
  first_name?: string;
  last_name?: string;
  role?: string; // organizer | participant
  status?: string; // accept | stall | reject
  response_id?: string; // if form submitted
};

export type FormMatrix = {
  form_id: string;
  questions: { id: string; text: string }[];
  responses: { user_id: string; first_name?: string; last_name?: string; status?: string; answers: string[] }[];
};

// Events that current user manages (organizer)
export async function listManagedEvents(): Promise<ManagedEventSummary[]> {
  const rows = await apiFetch<any[]>(`/event/managed`).catch(() => [] as any[]);
  return rows.map((r: any) => ({
    eventId: String(r?.eventId || r?.event_id || r?.id || r?._id || ''),
    topic: r?.topic,
    max_participation: r?.max_participation ?? r?.maxPart ?? r?.max_participation,
    pendingCount: r?.pendingCount ?? r?.stallCount,
    acceptedCount: r?.acceptedCount ?? r?.acceptCount,
  }));
}

// List participants for an event (optionally filter by role/status)
export async function listEventParticipants(eventId: string, opts?: { role?: string; status?: string }): Promise<EventParticipantRow[]> {
  const qs = new URLSearchParams();
  if (opts?.role) qs.set('role', opts.role);
  if (opts?.status) qs.set('status', opts.status);
  const path = `/event/${encodeURIComponent(eventId)}/participants${qs.toString() ? `?${qs.toString()}` : ''}`;
  const rows = await apiFetch<any[]>(path).catch(() => [] as any[]);
  return rows.map((r: any) => ({
    user_id: String(r?.user_id || r?.userId || ''),
    first_name: r?.first_name,
    last_name: r?.last_name,
    role: r?.role,
    status: r?.status,
    response_id: r?.response_id || '',
  }));
}

export async function updateParticipantStatus(payload: { user_id: string; event_id: string; status: 'accept' | 'stall' | 'reject' }) {
  return apiFetch<{ message?: string }>(`/event/participant/status`, { method: 'PUT', body: JSON.stringify(payload) });
}

export async function getEventFormMatrix(eventId: string): Promise<FormMatrix> {
  const res = await apiFetch<any>(`/event/${encodeURIComponent(eventId)}/form/matrix`).catch(() => null);
  if (!res) return { form_id: '', questions: [], responses: [] };
  const data = (res.data ?? res) as any;
  return {
    form_id: String(data?.form_id || data?.formId || ''),
    questions: Array.isArray(data?.questions) ? data.questions.map((q: any) => ({ id: String(q?.id || ''), text: String(q?.text || '') })) : [],
    responses: Array.isArray(data?.responses) ? data.responses.map((u: any) => ({
      user_id: String(u?.user_id || ''),
      first_name: u?.first_name,
      last_name: u?.last_name,
      status: u?.status,
      answers: Array.isArray(u?.answers) ? u.answers.map((a: any) => String(a)) : [],
    })) : [],
  } as FormMatrix;
}

// -------- Event Detail + Form Management --------

export async function getEventDetail(eventId: string) {
  const raw = await apiFetch<any>(`/event/${encodeURIComponent(eventId)}`).catch(() => null);
  if (!raw) return null;
  // Map dto.EventDetail into EventDoc-like shape
  const out: Partial<EventDoc> & { have_form?: boolean; form_id?: string } = {
    id: raw?.event_id || raw?.id || raw?._id,
    _id: raw?.event_id || raw?.id || raw?._id,
    topic: raw?.topic,
    description: raw?.description,
    max_participation: raw?.max_participation,
    posted_as: raw?.posted_as,
    visibility: raw?.visibility,
    status: raw?.status,
    have_form: !!raw?.have_form,
  } as any;
  if ((raw as any)?.form_id) (out as any).form_id = (raw as any).form_id;
  return out;
}

export type FormQuestion = {
  id?: string;
  question_text: string;
  required: boolean;
  order_index: number;
};

export async function getEventFormQuestions(eventId: string): Promise<FormQuestion[]> {
  const res = await apiFetch<any>(`/event/${encodeURIComponent(eventId)}/form/questions`).catch(() => null);
  const arr = Array.isArray(res?.Questions) ? res?.Questions : Array.isArray(res) ? res : [];
  return arr.map((q: any) => ({
    id: String(q?.id || q?._id || ''),
    question_text: String(q?.question_text || ''),
    required: !!q?.required,
    order_index: Number.isFinite(q?.order_index) ? q.order_index : 0,
  }));
}

export async function saveEventFormQuestions(eventId: string, questions: FormQuestion[]) {
  const payload = {
    questions: questions
      .slice()
      .sort((a, b) => (a.order_index ?? 0) - (b.order_index ?? 0))
      .map(q => ({
        question_text: q.question_text,
        required: !!q.required,
        order_index: Number(q.order_index) || 0,
      })),
  };
  return apiFetch<any>(`/event/${encodeURIComponent(eventId)}/form/questions`, { method: 'POST', body: JSON.stringify(payload) });
}

export async function initializeEventForm(eventId: string) {
  return apiFetch<any>(`/event/${encodeURIComponent(eventId)}/form/initialize`, { method: 'POST' });
}

export async function disableEventForm(eventId: string) {
  return apiFetch<any>(`/event/${encodeURIComponent(eventId)}/form/disable`, { method: 'POST' });
}
