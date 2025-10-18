import React, { useEffect, useMemo, useState } from "react";
import { PostDoc } from "../../types";
import { listPostsCursorEnriched } from "../../services/api";
import PostCard from "./PostCard";

// Admin Post Moderation Page
// - Lists posts with paging
// - Search (client-side), filter by status
// - Single & bulk actions: Hide / Unhide / Delete
// - Optimistic UI with basic error fallback

const PAGE_SIZE = 10;

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
  const [nextCursor, setNextCursor] = useState<string | undefined>(undefined);
  const [cursorStack, setCursorStack] = useState<string[]>([""]);

  // UI state
  const [q, setQ] = useState("");
  const [status, setStatus] = useState<StatusFilter>("all");
  // no bulk selection in card layout

  const hasNext = Boolean(nextCursor);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const cur = cursorStack[cursorStack.length - 1] || undefined;
        const { items, nextCursor } = await listPostsCursorEnriched(PAGE_SIZE, cur);
        if (!cancelled) {
          setPosts(items || []);
          setNextCursor(nextCursor);
        }
      } catch (e: any) {
        if (!cancelled) setError(e?.message || "Failed to load posts");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [page, cursorStack]);

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

  // no selection / bulk actions in card layout

  // bulk actions removed

  function handleStatusChange(id: string, status: "active" | "hidden") {
    setPosts(prev => prev.map(x => x._id === id ? { ...x, status } : x));
  }
  function handleDelete(id: string) {
    setPosts(prev => prev.filter(p => p._id !== id));
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
          onClick={() => { setPage(1); setPage(p => p); }}
          style={{ padding: "8px 12px", border: "1px solid #e5e7eb", borderRadius: 8, background: "#fff" }}
        >Refresh</button>
      </header>

      {error && (
        <div style={{ marginBottom: 12, padding: 12, background: "#fef2f2", border: "1px solid #fecaca", color: "#991b1b", borderRadius: 8 }}>
          {error}
        </div>
      )}

      {loading && (
        <div style={{ padding: 24, textAlign: "center", color: "#6b7280" }}>Loading…</div>
      )}

      {!loading && filtered.length === 0 && (
        <div style={{ padding: 24, textAlign: "center", color: "#6b7280" }}>No posts</div>
      )}

      <div style={{ display: "grid", gap: 12 }}>
        {!loading && filtered.map(p => (
          <PostCard key={p._id} post={p} onStatusChange={handleStatusChange} onDelete={handleDelete} />
        ))}
      </div>

      {/* Pager */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 16 }}>
        <div style={{ color: "#6b7280" }}>Page {cursorStack.length}</div>
        <div style={{ display: "flex", gap: 8 }}>
          <button
            disabled={cursorStack.length <= 1}
            onClick={() => {
              setCursorStack(stack => stack.length > 1 ? stack.slice(0, -1) : stack);
              setPage(p => Math.max(1, p - 1));
            }}
            style={btnGhost}
          >Prev</button>
          <button
            disabled={!hasNext}
            onClick={() => {
              if (nextCursor) setCursorStack(stack => [...stack, nextCursor]);
              setPage(p => p + 1);
            }}
            style={btnGhost}
          >Next</button>
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

// card moved to PostCard
