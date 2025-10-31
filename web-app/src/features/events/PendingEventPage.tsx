import React, { useEffect, useMemo, useState } from "react";
import { getAbilitiesWhere, listEvents, createEvent, deleteEvent } from "../../services/api";
import type { EventDoc } from "../../types";

type WhereResp = { action: string; orgs: { org_path: string; label?: string }[]; version?: string };

const PendingEventsPage: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [orgs, setOrgs] = useState<WhereResp["orgs"]>([]);
  const [rows, setRows] = useState<EventDoc[]>([]);

  // All events only

  // Create form state (minimal)
  const [topic, setTopic] = useState("");
  const [nodeIdHex, setNodeIdHex] = useState("");
  const [orgOfContent, setOrgOfContent] = useState("/"); 

  async function refetch() {
    setLoading(true);
    setError(null);
    try {
      const [perm, list] = await Promise.all([
        getAbilitiesWhere("event:create").catch(() => ({ orgs: [] } as any)),
        listEvents(),
      ]);
      console.log(list)
    //   console.log(list[0]['visibility']['access']);
      const filterlist = list.filter(item => item.visibility?.access === "pending");
    //   console.log(list);
      setOrgs(perm?.orgs || []);
      setRows(Array.isArray(filterlist) ? filterlist : []);
    } catch (e: any) {
      setError(e?.message || "Failed to load events");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { refetch(); }, []);

  // nothing else here

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!topic.trim()) return;
    try {
      setLoading(true);
      const org = (orgOfContent || "/").trim() || "/";
      await createEvent({
        node_id: nodeIdHex.trim(),
        topic: topic.trim(),
        description: "",
        max_participation: 0,
        posted_as: { org_path: org, position_key: "head" },
        visibility: { access: "private", audience: [] },
        org_of_content: org,
        schedules: [],
      });
      setTopic("");
      await refetch();
    } catch (e: any) {
      setError(e?.message || "Create failed");
      setLoading(false);
    }
  }

  async function handleDelete(id?: string) {
    if (!id) return;
    if (!window.confirm("Delete (soft hide) this event?")) return;
    const prev = rows;
    setRows(prev.filter(r => (r.id || r._id) !== id));
    try { await deleteEvent(id); } catch (e: any) {
      setError(e?.message || "Delete failed");
      setRows(prev);
    }
  }

  const visible = useMemo(() => rows, [rows]);

  return (
    <div className="p-4 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Events</h1>
        <button className="px-3 py-1.5 border rounded" onClick={() => refetch()}>Refresh</button>
      </div>

      {error && (
        <div className="p-3 rounded border border-red-200 text-red-700">{error}</div>
      )}

      {/* Create (kept for admins) */}
      <form onSubmit={handleCreate} className="flex gap-2 items-end flex-wrap">
        <div className="flex flex-col">
          <label className="text-sm text-gray-600">Topic</label>
          <input value={topic} onChange={e => setTopic(e.target.value)} placeholder="Event topic" className="px-3 py-2 border rounded w-64" />
        </div>
        <div className="flex flex-col">
          <label className="text-sm text-gray-600">NodeID (hex)</label>
          <input value={nodeIdHex} onChange={e => setNodeIdHex(e.target.value)} placeholder="68be..." className="px-3 py-2 border rounded w-64" />
        </div>
        <div className="flex flex-col">
          <label className="text-sm text-gray-600">Org (path)</label>
          <input value={orgOfContent} onChange={e => setOrgOfContent(e.target.value)} placeholder="/faculty/eng/smo" className="px-3 py-2 border rounded w-64" />
        </div>
        {/* <button type="submit" disabled={!canCreate || !topic.trim() || !nodeIdHex.trim()} className={`px-3 py-2 rounded text-white ${canCreate ? 'bg-blue-600' : 'bg-gray-400 cursor-not-allowed'}`}>
          Create Event
        </button> */}
        {/* {!canCreate && <span className="text-sm text-gray-600">No permission to create</span>} */}
      </form>

      {/* Cards */}
      {loading && (
        <div className="p-4 text-center text-gray-500">Loading…</div>
      )}
      {!loading && visible.length === 0 && (
        <div className="p-4 text-center text-gray-500">No events</div>
      )}

      <div className="grid gap-3">
        {!loading && visible.map(ev => {
          const id = ev.id || ev._id || "";
        //   console.log(ev);
          const status = (ev.status || '').toLowerCase();
          const pill = status === 'hidden' ? 'border-amber-200 text-amber-800 bg-amber-50' : 'border-emerald-200 text-emerald-800 bg-emerald-50';
          const fmtDate = (s?: string) => {
            if (!s) return '';
            try { return new Date(s).toLocaleDateString(undefined, { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' }); } catch { return s; }
          };
          const fmtTime = (s?: string) => {
            if (!s) return '';
            try { return new Date(s).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }); } catch { return s; }
          };
          return (
            <div key={id} className="border rounded-xl p-3 bg-white">
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <div className="text-base font-semibold">{ev.topic || '(untitled)'}</div>
                  {ev.posted_as?.label && (
                    <div className="text-xs text-slate-700 flex items-center gap-2">
                      <span className="font-medium">Post as:</span>
                      <span className="inline-block px-2 py-0.5 rounded border bg-slate-50 border-slate-200 text-slate-700">{ev.posted_as.label}</span>
                    </div>
                  )}
                  {ev.org_of_content && (
                    <div className="text-sm text-gray-700">{ev.org_of_content}</div>
                  )}
                </div>
                <div className="flex items-center gap-2 flex-wrap">
                  <span className={`text-xs px-2 py-0.5 rounded border ${pill}`}>{ev.status || 'active'}</span>
                  {typeof ev.max_participation === 'number' && (
                    <span className="text-xs px-2 py-0.5 rounded border bg-amber-50 border-amber-200 text-amber-800">Max participation: {ev.max_participation}</span>
                  )}
                  {ev.created_at && <span className="text-xs text-gray-600">Created {ev.created_at}</span>}
                  {ev.updated_at && ev.updated_at !== ev.created_at && <span className="text-xs text-gray-600">• Updated {ev.updated_at}</span>}
                </div>
              </div>

              {ev.description && (
                <div className="mt-2 whitespace-pre-wrap text-sm text-gray-800">{ev.description}</div>
              )}

              {Array.isArray(ev.schedules) && ev.schedules.length > 0 && (
                <div className="mt-3">
                  <div className="text-sm font-semibold text-slate-800 mb-2">Schedules</div>
                  <div className="grid gap-3">
                    {ev.schedules.map((s, i) => {
                      const date = fmtDate(s.date || s.start_time || s.time_start);
                      const t1 = fmtTime(s.start_time || s.time_start);
                      const t2 = fmtTime(s.end_time || s.time_end);
                      return (
                        <div key={i} className="border rounded-lg bg-slate-50 border-slate-200 shadow-sm p-3 md:p-4">
                          <div className="flex flex-wrap items-center gap-2 text-xs">
                            {date && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-slate-100 border border-slate-200 text-slate-800 px-2 py-0.5">
                                <span>📅</span>
                                <span className="font-medium">{date}</span>
                              </span>
                            )}
                            {(t1 || t2) && (
                              <span className="inline-flex items-center gap-1 rounded-full bg-indigo-50 border border-indigo-200 text-indigo-800 px-2 py-0.5">
                                <span>🕒</span>
                                <span className="font-medium">{t1}{t2 ? ` ${t2}` : ''}</span>
                              </span>
                            )}
                          </div>
                          {s.location && (
                            <div className="mt-2 text-sm md:text-base text-slate-900 font-medium flex items-center gap-2">
                              <span>📍</span>
                              <span>{s.location}</span>
                            </div>
                          )}
                          {s.description && (
                            <div className="mt-1 text-sm text-slate-700">{s.description}</div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
            )}

                <div className="mt-3 flex items-center justify-end">
                    <button
                    className="text-red-700 text-sm px-2 py-1 border rounded border-red-200 cursor-pointer hover:bg-red-50"
                    onClick={() => handleDelete(id)}
                    >
                    Delete
                    </button>
                </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default PendingEventsPage;
