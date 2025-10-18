import React, { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getUsersPaged } from "../services/api";

type Props = {
  open: boolean;
  onClose: () => void;
};

const CommandPalette: React.FC<Props> = ({ open, onClose }) => {
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(false);
  const [items, setItems] = useState<any[]>([]);
  const navigate = useNavigate();

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!open) return;
      if (!q.trim()) { setItems([]); return; }
      try {
        setLoading(true);
        const { items } = await getUsersPaged({ q, limit: 5 });
        if (!cancelled) setItems(items || []);
      } catch {
        if (!cancelled) setItems([]);
      } finally { if (!cancelled) setLoading(false); }
    })();
    return () => { cancelled = true; };
  }, [q, open]);

  const visible = open ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none";

  return (
    <div className={`fixed inset-0 z-[100] ${visible} transition-opacity`}> 
      <div className="absolute inset-0 bg-black/30" onClick={onClose} />
      <div className="relative max-w-xl mx-auto mt-24 rounded-xl bg-white shadow-lg ring-1 ring-black/10 overflow-hidden">
        <div className="px-4 py-3 border-b bg-emerald-50">
          <input
            autoFocus
            placeholder="Search users… (type to search)"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            className="w-full bg-white rounded-md px-3 py-2 text-sm outline-none border border-emerald-200 focus:ring-2 focus:ring-emerald-400"
          />
        </div>
        <div className="max-h-72 overflow-auto">
          {loading && <div className="px-4 py-3 text-sm text-gray-500">Searching…</div>}
          {!loading && items.length === 0 && q.trim() && (
            <div className="px-4 py-3 text-sm text-gray-500">No results</div>
          )}
          {!loading && items.map((u, i) => (
            <button
              key={i}
              className="w-full text-left px-4 py-2 hover:bg-emerald-50 flex items-center gap-3"
              onClick={() => {
                onClose();
                navigate("/users");
              }}
            >
              <div className="h-6 w-6 rounded-full bg-emerald-100 text-emerald-700 flex items-center justify-center text-xs font-semibold">
                {(u.firstName?.[0] || u.email?.[0] || "U").toUpperCase()}
              </div>
              <div className="text-sm">
                <div className="font-medium text-gray-800">{(u.firstName || "") + " " + (u.lastName || "")}</div>
                <div className="text-gray-500">{u.email}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
};

export default CommandPalette;

