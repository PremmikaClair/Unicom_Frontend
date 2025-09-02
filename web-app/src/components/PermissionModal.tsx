// src/components/PermissionModal.tsx
import { useMemo, useState } from "react";
import type { Permission } from "../types";

type Props = {
  visible: boolean;
  onClose: () => void;
  permissions: (Permission | string)[];
};

type Flat = { key: string; resource: string; action: string };

function splitKey(key: string): { resource: string; action: string } {
  const i = key.indexOf(":");
  if (i === -1) return { resource: "", action: key };
  return { resource: key.slice(0, i), action: key.slice(i + 1) };
}

export default function PermissionModal({ visible, onClose, permissions }: Props) {
  // 🟢 Always call hooks
  const [query, setQuery] = useState("");

  const { groups, total } = useMemo(() => {
    const uniq = new Map<string, Flat>();
    for (const p of permissions ?? []) {
      const key = typeof p === "string" ? p : p.key;
      if (!key) continue;
      const { resource, action } = splitKey(key);
      const normKey = `${resource}:${action}`;
      if (!uniq.has(normKey)) uniq.set(normKey, { key: normKey, resource, action });
    }

    const q = query.trim().toLowerCase();
    const list = Array.from(uniq.values()).filter((f) =>
      q ? f.key.toLowerCase().includes(q) || f.resource.toLowerCase().includes(q) || f.action.toLowerCase().includes(q) : true
    );

    const g = new Map<string, Flat[]>();
    for (const f of list) {
      const arr = g.get(f.resource) ?? [];
      arr.push(f);
      g.set(f.resource, arr);
    }

    for (const [, arr] of g) arr.sort((a, b) => a.action.localeCompare(b.action));
    const sorted = new Map(Array.from(g.entries()).sort(([a], [b]) => a.localeCompare(b)));

    return { groups: sorted, total: list.length };
  }, [permissions, query]);

  // It's now safe to early-return after hooks
  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/30 backdrop-blur-sm flex justify-center items-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl">
        {/* Header */}
        <div className="px-4 py-3 border-b flex items-center gap-3">
          <h2 className="text-lg font-semibold">User Permissions</h2>
          <span className="text-xs text-gray-500">({total} unique)</span>
          <div className="ml-auto flex items-center gap-2">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Filter by resource or action…"
              className="border rounded px-2 py-1 text-sm w-56"
            />
            <button
              onClick={() => setQuery("")}
              className="text-sm text-gray-600 hover:text-gray-900"
              title="Clear filter"
            >
              Clear
            </button>
          </div>
        </div>

        {/* Body (scrollable) */}
        <div className="max-h-[70vh] overflow-y-auto">
          {groups.size === 0 ? (
            <p className="p-4 text-sm text-gray-600">No permissions.</p>
          ) : (
            <div className="divide-y">
              {Array.from(groups.entries()).map(([resource, items]) => (
                <section key={resource || "(none)"} className="p-4">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="font-medium">
                      {resource || <span className="italic text-gray-500">(no resource)</span>}
                    </h3>
                    <span className="text-xs text-gray-500">{items.length}</span>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {items.map((f) => (
                      <span
                        key={f.key}
                        className="inline-flex items-center rounded-full border px-2 py-0.5 text-xs bg-gray-50"
                        title={f.key}
                      >
                        {f.action}
                      </span>
                    ))}
                  </div>
                </section>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-4 py-3 border-t flex items-center justify-end gap-2">
          <button
            onClick={onClose}
            className="px-3 py-1.5 rounded bg-gray-200 hover:bg-gray-300 text-sm"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}