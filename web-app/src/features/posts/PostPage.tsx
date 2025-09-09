import React, { useEffect, useMemo, useState } from "react";
import { PostDoc } from "../../types";
import {
  listPosts,
  hidePostApi,
  unhidePostApi,
  deletePost,
} from "../../services/api";

// Admin Post Moderation Page
// - Lists posts with paging
// - Search (client-side), filter by status
// - Single & bulk actions: Hide / Unhide / Delete
// - Optimistic UI with basic error fallback

const PAGE_SIZE = 20;

type StatusFilter = "all" | "active" | "hidden";

const badgeStyle: React.CSSProperties = {
  display: "inline-block",
  padding: "2px 8px",
  borderRadius: 999,
  fontSize: 12,
  lineHeight: 1.4,
  background: "#eef2ff",
  color: "#3730a3",
  border: "1px solid #c7d2fe",
};

const tagStyle: React.CSSProperties = {
  display: "inline-block",
  padding: "2px 6px",
  borderRadius: 6,
  fontSize: 12,
  background: "#f1f5f9",
  border: "1px solid #e2e8f0",
  color: "#334155",
};

function formatDate(s?: string) {
  if (!s) return "—";
  try { return new Date(s).toLocaleString(); } catch { return s; }
}

export default function PostPage() {
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [posts, setPosts] = useState<PostDoc[]>([]);

  // UI state
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<StatusFilter>("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const hasNext = posts.length === PAGE_SIZE; // naive (server returns exactly limit when more pages likely exist)

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const data = await listPosts(page, PAGE_SIZE, false); // admin wants all
        if (!cancelled) {
          setPosts(data || []);
          setSelected(new Set());
        }
      } catch (e: any) {
        if (!cancelled) setError(e?.message || "Failed to load posts");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [page]);

  const filtered = useMemo(() => {
    const qLower = q.trim().toLowerCase();
    return posts.filter(p => {
      if (status !== "all") {
        const s = p.status ?? "active";
        if (status === "active" && s !== "active") return false;
        if (status === "hidden" && s !== "hidden") return false;
      }
      if (!qLower) return true;
      const text = [
        p.message,
        p.name,
        p.username,
        p.posted_as?.label,
        p.posted_as?.org_path,
      ].filter(Boolean).join(" \n").toLowerCase();
      return text.includes(qLower);
    });
  }, [posts, q, status]);

  function toggleSelect(id: string) {
    setSelected(prev => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });
  }

  function selectAllVisible() {
    setSelected(new Set(filtered.map(p => p._id)));
  }

  function clearSelection() {
    setSelected(new Set());
  }

  async function bulkHide(ids: string[]) {
    if (!ids.length) return;
    // Optimistic update
    setPosts(prev => prev.map(p => ids.includes(p._id) ? { ...p, status: "hidden" } : p));
    try {
      await Promise.all(ids.map(id => hidePostApi(id)));
    } catch (e) {
      // revert on error
      setError((e as any)?.message || "Bulk hide failed");
      // simple refetch instead of complex rollback
      setPage(p => p); 
    } finally {
      clearSelection();
    }
  }

  async function bulkUnhide(ids: string[]) {
    if (!ids.length) return;
    setPosts(prev => prev.map(p => ids.includes(p._id) ? { ...p, status: "active" } : p));
    try {
      await Promise.all(ids.map(id => unhidePostApi(id)));
    } catch (e) {
      setError((e as any)?.message || "Bulk unhide failed");
      setPage(p => p);
    } finally {
      clearSelection();
    }
  }

  async function bulkDelete(ids: string[]) {
    if (!ids.length) return;
    if (!window.confirm(`Delete ${ids.length} post(s)? This cannot be undone.`)) return;
    const old = posts;
    setPosts(prev => prev.filter(p => !ids.includes(p._id)));
    try {
      await Promise.all(ids.map(id => deletePost(id)));
    } catch (e) {
      setError((e as any)?.message || "Bulk delete failed");
      setPosts(old); // rollback
    } finally {
      clearSelection();
    }
  }

  async function handleSingleHide(p: PostDoc) {
    setPosts(prev => prev.map(x => x._id === p._id ? { ...x, status: "hidden" } : x));
    try { await hidePostApi(p._id); } catch (e) { setError((e as any)?.message || "Hide failed"); setPage(pg => pg); }
  }

  async function handleSingleUnhide(p: PostDoc) {
    setPosts(prev => prev.map(x => x._id === p._id ? { ...x, status: "active" } : x));
    try { await unhidePostApi(p._id); } catch (e) { setError((e as any)?.message || "Unhide failed"); setPage(pg => pg); }
  }

  async function handleSingleDelete(p: PostDoc) {
    if (!window.confirm("Delete this post? This cannot be undone.")) return;
    const old = posts;
    setPosts(prev => prev.filter(x => x._id !== p._id));
    try { await deletePost(p._id); } catch (e) { setError((e as any)?.message || "Delete failed"); setPosts(old); }
  }

  return (
    <div style={{ padding: 24 }}>
      <header style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap", marginBottom: 16 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, marginRight: "auto" }}>Post Moderation</h1>
        <input
          value={q}
          onChange={e => setQ(e.target.value)}
          placeholder="Search message, user, org..."
          style={{ padding: "8px 10px", border: "1px solid #e5e7eb", borderRadius: 8, width: 280 }}
        />
        <select
          value={status}
          onChange={e => setStatus(e.target.value as StatusFilter)}
          style={{ padding: "8px 10px", border: "1px solid #e5e7eb", borderRadius: 8 }}
        >
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="hidden">Hidden</option>
        </select>
        <button
          onClick={() => { setPage(1); /* force reload */ setPage(p => p); }}
          style={{ padding: "8px 12px", border: "1px solid #e5e7eb", borderRadius: 8, background: "#fff" }}
        >Refresh</button>
      </header>

      {/* Bulk toolbar */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12 }}>
        <span>{selected.size} selected</span>
        <button onClick={selectAllVisible} style={btnGhost}>Select visible</button>
        <button onClick={clearSelection} style={btnGhost}>Clear</button>
        <div style={{ marginLeft: "auto", display: "flex", gap: 8 }}>
          <button onClick={() => bulkHide([...selected])} disabled={!selected.size} style={btn}>Hide</button>
          <button onClick={() => bulkUnhide([...selected])} disabled={!selected.size} style={btn}>Unhide</button>
          <button onClick={() => bulkDelete([...selected])} disabled={!selected.size} style={btnDanger}>Delete</button>
        </div>
      </div>

      {error && (
        <div style={{ marginBottom: 12, padding: 12, background: "#fef2f2", border: "1px solid #fecaca", color: "#991b1b", borderRadius: 8 }}>
          {error}
        </div>
      )}

      <div style={{ width: "100%", overflowX: "auto" }}>
        <table style={{ width: "100%", borderCollapse: "separate", borderSpacing: 0 }}>
          <thead>
            <tr>
              <th style={th} />
              <th style={th}>Post</th>
              <th style={th}>Author</th>
              <th style={th}>Posted as</th>
              <th style={th}>Visibility</th>
              <th style={th}>Likes</th>
              <th style={th}>Status</th>
              <th style={th}>Created</th>
              <th style={th}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={9} style={{ padding: 24, textAlign: "center", color: "#6b7280" }}>
                  Loading…
                </td>
              </tr>
            )}

            {!loading && filtered.length === 0 && (
              <tr>
                <td colSpan={9} style={{ padding: 24, textAlign: "center", color: "#6b7280" }}>
                  No posts
                </td>
              </tr>
            )}

            {!loading && filtered.map(p => (
              <tr key={p._id} style={{ borderTop: "1px solid #e5e7eb" }}>
                <td style={td}>
                  <input
                    type="checkbox"
                    checked={selected.has(p._id)}
                    onChange={() => toggleSelect(p._id)}
                  />
                </td>
                <td style={{ ...td, maxWidth: 420 }}>
                  <div style={{ fontWeight: 600 }}>{p.message}</div>
                  {p.org_of_content && (
                    <div style={{ fontSize: 12, color: "#6b7280", marginTop: 4 }}>org_of_content: {p.org_of_content}</div>
                  )}
                </td>
                <td style={td}>
                  <div>{p.name || "—"} <span style={{ color: "#6b7280" }}>@{p.username || "—"}</span></div>
                  <div style={{ fontSize: 12, color: "#6b7280" }}>uid: {p.uid}</div>
                </td>
                <td style={td}>
                  {p.posted_as?.label || p.posted_as?.position_key || p.posted_as?.org_path ? (
                    <span style={tagStyle}>
                      {p.posted_as?.label || `${p.posted_as?.position_key ?? ""} • ${p.posted_as?.org_path ?? ""}`}
                    </span>
                  ) : (
                    <span style={{ color: "#6b7280" }}>—</span>
                  )}
                </td>
                <td style={{ ...td, minWidth: 200 }}>
                  {p.visibility?.access ? (
                    <div>
                      <span style={badgeStyle}>{p.visibility.access}</span>
                      {p.visibility.access === "org" && p.visibility.audience?.length ? (
                        <div style={{ marginTop: 6, fontSize: 12, color: "#334155" }}>
                          {p.visibility.audience.map((a, i) => (
                            <div key={i}>
                              {a.org_path} <span style={{ color: "#6b7280" }}>({a.scope})</span>
                            </div>
                          ))}
                        </div>
                      ) : null}
                    </div>
                  ) : (
                    <span style={{ color: "#6b7280" }}>—</span>
                  )}
                </td>
                <td style={td}>{p.likes ?? 0}</td>
                <td style={td}>
                  {p.status === "hidden" ? (
                    <span style={{ ...badgeStyle, background: "#fff7ed", color: "#9a3412", borderColor: "#fed7aa" }}>hidden</span>
                  ) : (
                    <span style={{ ...badgeStyle, background: "#ecfdf5", color: "#065f46", borderColor: "#a7f3d0" }}>{p.status ?? "active"}</span>
                  )}
                </td>
                <td style={td}>{formatDate(p.created_at || p.timestamp)}</td>
                <td style={{ ...td, minWidth: 220 }}>
                  {p.status === "hidden" ? (
                    <button onClick={() => handleSingleUnhide(p)} style={btnSmall}>Unhide</button>
                  ) : (
                    <button onClick={() => handleSingleHide(p)} style={btnSmall}>Hide</button>
                  )}
                  <button onClick={() => handleSingleDelete(p)} style={btnSmallDanger}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pager */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 16 }}>
        <div style={{ color: "#6b7280" }}>Page {page}</div>
        <div style={{ display: "flex", gap: 8 }}>
          <button disabled={page <= 1} onClick={() => setPage(p => Math.max(1, p - 1))} style={btnGhost}>Prev</button>
          <button disabled={!hasNext} onClick={() => setPage(p => p + 1)} style={btnGhost}>Next</button>
        </div>
      </div>
    </div>
  );
}

// ---------- minimal inline styles for buttons / table ----------
const th: React.CSSProperties = {
  textAlign: "left",
  fontSize: 12,
  fontWeight: 600,
  color: "#6b7280",
  padding: "10px 12px",
  borderBottom: "1px solid #e5e7eb",
  background: "#f8fafc",
  position: "sticky",
  top: 0,
  zIndex: 1,
};

const td: React.CSSProperties = {
  fontSize: 14,
  color: "#111827",
  padding: "12px",
  verticalAlign: "top",
};

const btn: React.CSSProperties = {
  padding: "8px 12px",
  border: "1px solid #e5e7eb",
  borderRadius: 8,
  background: "white",
  cursor: "pointer",
};

const btnGhost: React.CSSProperties = {
  ...btn,
  background: "#fff",
};

const btnDanger: React.CSSProperties = {
  ...btn,
  color: "#b91c1c",
  borderColor: "#fecaca",
};

const btnSmall: React.CSSProperties = {
  ...btn,
  padding: "6px 10px",
  marginRight: 8,
};

const btnSmallDanger: React.CSSProperties = {
  ...btnSmall,
  color: "#b91c1c",
  borderColor: "#fecaca",
};
