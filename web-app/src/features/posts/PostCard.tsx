import React, { useEffect, useMemo, useRef, useState } from "react";
import type { PostDoc, CommentDoc } from "../../types";
import { listComments, createComment, deletePost } from "../../services/api";

type Props = {
  post: PostDoc;
  onStatusChange?: (id: string, status: "active" | "hidden") => void;
  onDelete?: (id: string) => void;
};

function formatDT(s?: string) {
  if (!s) return "—";
  try { return new Date(s).toLocaleString(); } catch { return s; }
}

const badge: React.CSSProperties = {
  display: "inline-block",
  padding: "2px 8px",
  borderRadius: 999,
  fontSize: 12,
  lineHeight: 1.4,
  border: "1px solid transparent",
};

const tagPill: React.CSSProperties = {
  display: "inline-block",
  padding: "2px 6px",
  borderRadius: 6,
  fontSize: 12,
  background: "#f1f5f9",
  border: "1px solid #e2e8f0",
  color: "#334155",
};

const card: React.CSSProperties = {
  padding: 16,
  border: "1px solid #e5e7eb",
  borderRadius: 12,
  background: "#fff",
};

const linkBtn: React.CSSProperties = {
  background: "transparent",
  border: "none",
  color: "#2563eb",
  fontSize: 13,
  padding: 0,
  cursor: "pointer",
};

const linkBtnDanger: React.CSSProperties = {
  ...linkBtn,
  color: "#b91c1c",
};

export default function PostCard({ post, onStatusChange, onDelete }: Props) {
  const [expanded, setExpanded] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [comments, setComments] = useState<CommentDoc[]>([]);
  const [nextCursor, setNextCursor] = useState<string | undefined>(undefined);
  const [text, setText] = useState("");
  const [commentCount, setCommentCount] = useState<number>((post as any).commentCount ?? (post as any).comment_count ?? 0);
  const [overlayUrl, setOverlayUrl] = useState<string | null>(null);
  const [overlayIndex, setOverlayIndex] = useState<number | null>(null);

  const access = post.visibility?.access || "public";
  const visStyle = access === "public"
    ? { ...badge, background: "#ecfdf5", color: "#065f46", borderColor: "#a7f3d0" }
    : { ...badge, background: "#fff7ed", color: "#9a3412", borderColor: "#fed7aa" };

  const created = useMemo(() => formatDT(post.created_at || post.timestamp), [post]);
  const updated = useMemo(() => formatDT(post.updated_at), [post]);

  const media = Array.isArray(post.media) ? post.media : [];

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (!overlayUrl) return;
      if (e.key === "Escape") {
        setOverlayUrl(null);
        setOverlayIndex(null);
      } else if (e.key === "ArrowRight") {
        if (media.length > 1 && overlayIndex !== null) {
          const next = (overlayIndex + 1) % media.length;
          setOverlayIndex(next);
          setOverlayUrl(media[next]);
        }
      } else if (e.key === "ArrowLeft") {
        if (media.length > 1 && overlayIndex !== null) {
          const prev = (overlayIndex - 1 + media.length) % media.length;
          setOverlayIndex(prev);
          setOverlayUrl(media[prev]);
        }
      }
    }
    if (overlayUrl) window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [overlayUrl, overlayIndex, media]);

  function isVideoUrl(url: string) {
    const u = (url || "").split("?")[0].toLowerCase();
    return /\.(mp4|webm|ogg|ogv|mov|m4v)$/.test(u);
  }

  function openOverlayAt(i: number) {
    if (!media[i]) return;
    setOverlayIndex(i);
    setOverlayUrl(media[i]);
  }
  function closeOverlay() {
    setOverlayUrl(null);
    setOverlayIndex(null);
  }
  function go(delta: number) {
    if (overlayIndex === null || media.length < 2) return;
    const next = (overlayIndex + delta + media.length) % media.length;
    setOverlayIndex(next);
    setOverlayUrl(media[next]);
  }

  async function toggleComments() {
    setExpanded(v => !v);
    if (!expanded && comments.length === 0 && !loading) {
      setLoading(true);
      setErr(null);
      try {
        const res = await listComments(post._id, 5);
        setComments(res.items || []);
        setNextCursor(res.nextCursor);
      } catch (e: any) {
        setErr(e?.message || "Failed to load comments");
      } finally {
        setLoading(false);
      }
    }
  }

  async function submitComment() {
    const t = text.trim();
    if (!t) return;
    try {
      const c = await createComment(post._id, t);
      setComments(prev => [c, ...prev]);
      setText("");
      setCommentCount((n) => (typeof n === "number" ? n + 1 : 1));
    } catch (e: any) {
      setErr(e?.message || "Failed to post comment");
    }
  }

  async function loadMore() {
    if (!nextCursor) return;
    try {
      const more = await listComments(post._id, 5, nextCursor);
      setComments(prev => [...prev, ...(more.items || [])]);
      setNextCursor(more.nextCursor);
    } catch (e: any) {
      setErr(e?.message || "Failed to load");
    }
  }

  // Hide/Unhide actions removed per request
  async function onDeleteClick() {
    if (!window.confirm("Delete this post? This cannot be undone.")) return;
    try {
      await deletePost(post._id);
      onDelete?.(post._id);
    } catch (e: any) {
      setErr(e?.message || "Delete failed");
    }
  }

  return (
    <div style={card}>
      <div style={{ display: "flex", alignItems: "flex-start", gap: 12, justifyContent: "space-between" }}>
        <div style={{ display: "grid", gap: 4 }}>
          <div style={{ fontWeight: 600 }}>{post.name || "—"}</div>
          <div style={{ fontSize: 12, color: "#6b7280" }}>uid: {post.uid || "—"}</div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
          {post.posted_as?.label && <span style={tagPill}>{post.posted_as.label}</span>}
          <span style={visStyle}>{access}</span>
          <div style={{ fontSize: 12, color: "#6b7280" }}>Created {created}</div>
          {post.updated_at && post.updated_at !== post.created_at && (
            <div style={{ fontSize: 12, color: "#6b7280" }}>• Updated {updated}</div>
          )}
        </div>
      </div>

      <div style={{ marginTop: 8, whiteSpace: "pre-wrap" }}>{post.message}</div>

      {media.length > 0 && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(120px, 1fr))", gap: 8, marginTop: 10 }}>
          {media.map((url, i) => {
            const isVid = isVideoUrl(url);
            return (
              <div
                key={i}
                onClick={() => openOverlayAt(i)}
                title={isVid ? "Play video" : "View image"}
                role="button"
                aria-label={isVid ? "Open video" : "Open image"}
                style={{
                  display: "block",
                  borderRadius: 8,
                  overflow: "hidden",
                  border: "1px solid #e5e7eb",
                  cursor: "zoom-in",
                  position: "relative",
                  background: isVid ? "#000" : undefined,
                }}
              >
                {isVid ? (
                  <VideoThumb url={url} />
                ) : (
                  <img src={url} alt="media" loading="lazy" style={{ width: "100%", height: 120, objectFit: "cover", display: "block" }} />
                )}
              </div>
            );
          })}
        </div>
      )}

      <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 12 }}>
        <div style={{ fontSize: 12, color: "#334155" }}>Likes: {post.likes ?? 0}</div>
        <button onClick={toggleComments} style={linkBtn}>Comments {typeof commentCount === 'number' ? `(${commentCount})` : ''}</button>
        <div style={{ marginLeft: "auto" }} />
        <button onClick={onDeleteClick} style={linkBtnDanger}>Delete</button>
      </div>

      {err && <div style={{ marginTop: 8, color: "#b91c1c" }}>{err}</div>}

      {expanded && (
        <div style={{ marginTop: 12 }}>
          <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
            <input
              value={text}
              onChange={e => setText(e.target.value)}
              placeholder="Add a comment"
              style={{ flex: 1, padding: "8px 10px", border: "1px solid #e5e7eb", borderRadius: 8 }}
            />
            <button onClick={submitComment} style={linkBtn}>Post</button>
          </div>
          <div style={{ display: "grid", gap: 8 }}>
            {loading && <div style={{ color: "#6b7280" }}>Loading…</div>}
            {comments.map(c => (
              <div key={c.id || c._id} style={{ padding: 10, background: "#fff", border: "1px solid #eee", borderRadius: 8 }}>
                <div style={{ whiteSpace: "pre-wrap" }}>{c.text}</div>
                <div style={{ fontSize: 12, color: "#6b7280", marginTop: 4 }}>{formatDT(c.createdAt)}</div>
              </div>
            ))}
            {nextCursor && (
              <button onClick={loadMore} style={linkBtn}>Load more</button>
            )}
          </div>
        </div>
      )}

      {overlayUrl && (
        <div
          onClick={closeOverlay}
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,0.8)",
            zIndex: 1000,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            padding: 16,
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: "92vw", maxHeight: "88vh", position: "relative", display: "flex", flexDirection: "column", gap: 8 }}
          >
            <button
              onClick={closeOverlay}
              style={{
                position: "absolute",
                top: -8,
                right: -8,
                background: "#111827",
                color: "#fff",
                border: "1px solid #374151",
                borderRadius: 999,
                width: 32,
                height: 32,
                cursor: "pointer",
              }}
              aria-label="Close"
              title="Close"
            >
              ✕
            </button>
            <div style={{ position: "relative", display: "flex", alignItems: "center", justifyContent: "center" }}>
              {media.length > 1 && (
                <>
                  <button
                    onClick={() => go(-1)}
                    style={{ position: "absolute", left: -8, top: "50%", transform: "translateY(-50%)", background: "rgba(17,24,39,0.7)", color: "#fff", border: "1px solid #374151", borderRadius: 8, width: 36, height: 36, cursor: "pointer" }}
                    aria-label="Previous"
                  >
                    ‹
                  </button>
                  <button
                    onClick={() => go(1)}
                    style={{ position: "absolute", right: -8, top: "50%", transform: "translateY(-50%)", background: "rgba(17,24,39,0.7)", color: "#fff", border: "1px solid #374151", borderRadius: 8, width: 36, height: 36, cursor: "pointer" }}
                    aria-label="Next"
                  >
                    ›
                  </button>
                </>
              )}
              {isVideoUrl(overlayUrl) ? (
                <video
                  src={overlayUrl}
                  controls
                  autoPlay
                  playsInline
                  style={{ maxWidth: "92vw", maxHeight: "76vh", background: "#000", display: "block" }}
                />
              ) : (
                <img
                  src={overlayUrl}
                  alt="media preview"
                  style={{ maxWidth: "92vw", maxHeight: "76vh", display: "block" }}
                />
              )}
            </div>
            {media.length > 1 && (
              <div style={{ color: "#e5e7eb", textAlign: "center", fontSize: 12 }}>
                {(overlayIndex ?? 0) + 1} / {media.length}
              </div>
            )}
            {media.length > 1 && (
              <div style={{ display: "flex", gap: 8, justifyContent: "center", alignItems: "center", maxWidth: "92vw", overflowX: "auto", paddingTop: 4 }}>
                {media.map((u, idx) => {
                  const active = idx === overlayIndex;
                  const isVid = isVideoUrl(u);
                  return (
                    <div
                      key={idx}
                      onClick={() => { setOverlayIndex(idx); setOverlayUrl(u); }}
                      title={isVid ? "Play video" : "View image"}
                      style={{
                        width: 80,
                        height: 60,
                        borderRadius: 6,
                        overflow: "hidden",
                        border: active ? "2px solid #60a5fa" : "1px solid #374151",
                        cursor: "pointer",
                        background: "#000",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      {isVid ? (
                        <VideoThumb url={u} small />
                      ) : (
                        <img src={u} alt="thumb" loading="lazy" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// Lightweight video thumbnail that seeks to ~0.1s and pauses, with fallbacks.
function VideoThumb({ url, style, className, small = false }: { url: string; style?: React.CSSProperties; className?: string; small?: boolean }) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;

    const onLoadedMeta = () => {
      try {
        // Seek slightly forward to capture a non-black frame
        v.currentTime = 0.1;
      } catch {
        // Ignore seek errors
      }
    };
    const onLoadedData = () => {
      // Some browsers show frame on loadeddata without needing seeked
      setReady(true);
      try { v.pause(); } catch {}
    };
    const onSeeked = () => {
      setReady(true);
      try { v.pause(); } catch {}
    };
    const onError = () => {
      setFailed(true);
    };

    v.addEventListener("loadedmetadata", onLoadedMeta);
    v.addEventListener("loadeddata", onLoadedData);
    v.addEventListener("seeked", onSeeked);
    v.addEventListener("error", onError);
    return () => {
      v.removeEventListener("loadedmetadata", onLoadedMeta);
      v.removeEventListener("loadeddata", onLoadedData);
      v.removeEventListener("seeked", onSeeked);
      v.removeEventListener("error", onError);
    };
  }, [url]);

  const baseStyle: React.CSSProperties = {
    width: "100%",
    height: small ? 60 : 120,
    objectFit: "cover",
    display: "block",
    background: "#000",
  };

  return (
    <div className={className} style={{ position: "relative", overflow: "hidden", borderRadius: 8, ...style }}>
      {!failed && (
        <video
          ref={videoRef}
          src={url}
          muted
          playsInline
          preload="metadata"
          crossOrigin="anonymous"
          style={{ ...baseStyle, opacity: ready ? 1 : 0 }}
        />
      )}
      {/* Placeholder while loading or on failure */}
      {(!ready || failed) && (
        <div style={{ ...baseStyle, display: "flex", alignItems: "center", justifyContent: "center", color: "#fff" }}>
          <span style={{ fontSize: small ? 14 : 22, lineHeight: 1 }}>▶</span>
        </div>
      )}
    </div>
  );
}
