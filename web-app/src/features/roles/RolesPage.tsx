import { useState } from "react";

type User = {
  _id: string;
  id: number;
  firstName?: string;
  lastName?: string;
  email: string;
  student_id?: string;
  status?: string;
};

type Membership = {
  _id?: string;
  user_id: string;
  org_path: string;
  position_key: string;
  joined_at?: string;
};

type TagItem = {
  org_path: string;
  position_key: string;
  position_display?: string;
  org_short?: string;
  tag: string;
};

type PostDoc = {
  _id: string;
  uid: string;
  name?: string;
  username?: string;
  message: string;
  timestamp: string;
  likes: number;
  likedBy: string[];
  posted_as?: { org_path?: string; position_key?: string; tag?: string };
  visibility?: { access?: "public" | "org"; audience?: { org_path: string; scope: "self" | "subtree" }[] };
  org_of_content?: string;
};

type AbilitiesResp = {
  org_path: string;
  abilities: Record<string, boolean>;
  version?: string;
};



const defaultBaseURL = "http://localhost:3000/api";
const pre = (o: any) => <pre className="text-xs bg-gray-50 p-2 rounded border whitespace-pre-wrap">{JSON.stringify(o, null, 2)}</pre>;

export default function APISmokeTestLite() {
  const [baseURL, setBaseURL] = useState(defaultBaseURL);
  const [token, setToken] = useState<string>(""); // paste your JWT here
  const [query, setQuery] = useState("65012345");
  const [users, setUsers] = useState<User[]>([]);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  const [membershipsRaw, setMembershipsRaw] = useState<Membership[]>([]);
  const [membershipTags, setMembershipTags] = useState<TagItem[]>([]);
  const [abilities, setAbilities] = useState<Record<string, AbilitiesResp>>({});
  const [abilitiesErrors, setAbilitiesErrors] = useState<Record<string, string>>({});

  const [posts, setPosts] = useState<PostDoc[]>([]);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(10);

  async function doFetch<T>(path: string, init?: RequestInit): Promise<T> {
    
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    };

    const res = await fetch(`${baseURL}${path}`, { ...init, headers });
        const text = await res.text();
    let data: any = null;
    try { data = text ? JSON.parse(text) : null; } catch {
      throw new Error(`HTTP ${res.status} (non-JSON): ${text}`);
    }
    if (!res.ok) throw new Error(data?.error || `HTTP ${res.status}`);
    return data as T;
  }

  const onSearchUsers = async () => {
    try {
      const resp = await doFetch<{ items: User[]; nextCursor?: string }>(`/users?q=${encodeURIComponent(query)}&limit=20`);
      setUsers(resp.items || []);
      setSelectedUser(resp.items?.[0] || null);
    } catch (e: any) {
      alert(`Search failed: ${e.message}`);
    }
  };

  const onLoadMemberships = async () => {
    if (!selectedUser?.student_id) return alert("Selected user needs student_id");
    try {
      const raw = await doFetch<{ student_id: string; user_id: string; memberships: Membership[] }>(
        `/users/${encodeURIComponent(selectedUser.student_id)}/memberships?view=raw`,
      );
      setMembershipsRaw(raw.memberships || []);

      const tags = await doFetch<{ student_id: string; user_id: string; tags: TagItem[] }>(
        `/users/${encodeURIComponent(selectedUser.student_id)}/memberships?view=tags&lang=en`,
      );
      setMembershipTags(tags.tags || []);
    } catch (e: any) {
      alert(`Membership fetch failed: ${e.message}`);
    }
  };

  const onLoadAbilities = async () => {
    const newAbs: Record<string, AbilitiesResp> = {};
    const newErrs: Record<string, string> = {};
    for (const t of membershipTags) {
      try {
        const resp = await doFetch<AbilitiesResp>(`/abilities?org_path=${encodeURIComponent(t.org_path)}`);
        newAbs[t.org_path] = resp;
      } catch (e: any) {
        newErrs[t.org_path] = e.message;
      }
    }
    setAbilities(newAbs);
    setAbilitiesErrors(newErrs);
  };

  const onLoadPosts = async () => {
    try {
      const resp = await doFetch<PostDoc[]>(`/posts?page=${page}&limit=${limit}`);
      setPosts(resp || []);
    } catch (e: any) {
      alert(`Load posts failed: ${e.message}`);
    }
  };

  return (
    <div className="p-4 space-y-6 max-w-5xl mx-auto">
      <h1 className="text-lg font-bold">API Smoke Test (Lite)</h1>

      {/* Base URL + Token */}
      <section className="space-y-2 border rounded p-3">
        <div className="grid gap-2">
          <label className="text-sm">API Base URL</label>
          <input className="border rounded px-2 py-1" value={baseURL} onChange={(e) => setBaseURL(e.target.value)} />
          <label className="text-sm">JWT (paste from your login page)</label>
          <input className="border rounded px-2 py-1" value={token} onChange={(e) => setToken(e.target.value)} placeholder="eyJhbGciOi..." />
        </div>
      </section>

      {/* User search */}
      <section className="space-y-2 border rounded p-3">
        <h2 className="font-semibold">Find User</h2>
        <div className="flex gap-2">
          <input className="border rounded px-2 py-1 flex-1" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="student_id or name/email" />
          <button className="border rounded px-3 py-1" onClick={onSearchUsers}>Search</button>
        </div>
        <div className="grid sm:grid-cols-2 gap-3 mt-2">
          <div>
            <div className="text-sm font-medium mb-1">Results</div>
            <ul className="space-y-1 max-h-48 overflow-auto border rounded p-2">
              {users.map((u) => {
                const label = `${u.student_id ?? "?"} — ${u.firstName ?? ""} ${u.lastName ?? ""} (${u.email})`;
                const selected = selectedUser?._id === u._id;
                return (
                  <li key={u._id}>
                    <button className={`text-left w-full px-2 py-1 rounded ${selected ? "bg-blue-100" : "hover:bg-gray-100"}`} onClick={() => setSelectedUser(u)}>
                      {label}
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
          <div>
            <div className="text-sm font-medium mb-1">Selected User</div>
            {selectedUser ? pre(selectedUser) : <div className="text-sm text-gray-500">No user selected</div>}
          </div>
        </div>
      </section>

      {/* Memberships & Abilities */}
      <section className="space-y-2 border rounded p-3">
        <h2 className="font-semibold">Memberships</h2>
        <div className="flex gap-2">
          <button className="border rounded px-3 py-1" onClick={onLoadMemberships} disabled={!selectedUser}>
            Load memberships (raw + tags)
          </button>
          <button className="border rounded px-3 py-1" onClick={onLoadAbilities} disabled={membershipTags.length === 0}>
            Load abilities (per org)
          </button>
        </div>

        <div className="grid sm:grid-cols-2 gap-3">
          <div>
            <div className="text-sm font-medium mt-2">Raw memberships</div>
            {membershipsRaw.length ? pre(membershipsRaw) : <div className="text-sm text-gray-500">None</div>}
          </div>
          <div>
            <div className="text-sm font-medium mt-2">Membership tags</div>
            {membershipTags.length ? (
              <ul className="space-y-1">
                {membershipTags.map((t, i) => (
                  <li key={i} className="border rounded px-2 py-1">
                    <div className="text-sm font-medium">{t.tag}</div>
                    <div className="text-xs text-gray-600">{t.org_path} • {t.position_key}</div>
                    {abilities[t.org_path] ? pre(abilities[t.org_path]) : (abilitiesErrors[t.org_path] ? <div className="text-xs text-red-600">{abilitiesErrors[t.org_path]}</div> : null)}
                  </li>
                ))}
              </ul>
            ) : (
              <div className="text-sm text-gray-500">None</div>
            )}
          </div>
        </div>
      </section>

      {/* Posts */}
      <section className="space-y-2 border rounded p-3">
        <h2 className="font-semibold">Posts</h2>
        <div className="flex gap-2 items-center">
          <label className="text-sm">Page</label>
          <input type="number" className="border rounded px-2 py-1 w-24" value={page} onChange={(e) => setPage(parseInt(e.target.value || "1", 10))} />
          <label className="text-sm">Limit</label>
          <input type="number" className="border rounded px-2 py-1 w-24" value={limit} onChange={(e) => setLimit(parseInt(e.target.value || "10", 10))} />
          <button className="border rounded px-3 py-1" onClick={onLoadPosts}>Load posts</button>
        </div>

        {posts.length ? (
          <ul className="space-y-2">
            {posts.map((p) => (
              <li key={p._id} className="border rounded p-2">
                <div className="text-sm">
                  <span className="font-semibold">{p.username ?? p.name ?? p.uid}</span>
                  {p.posted_as?.tag && <span className="ml-2 text-xs px-2 py-0.5 rounded bg-gray-100">{p.posted_as.tag}</span>}
                </div>
                <div className="text-sm mt-1">{p.message}</div>
                <div className="text-xs text-gray-600 mt-1">
                  {new Date(p.timestamp).toLocaleString()} • likes: {p.likes}
                </div>
              </li>
            ))}
          </ul>
        ) : (
          <div className="text-sm text-gray-500">No posts loaded</div>
        )}
      </section>
    </div>
  );
}
