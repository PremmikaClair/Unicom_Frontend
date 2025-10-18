import React, { useEffect, useState } from "react";
import {
  listManagedEvents,
  listEventParticipants,
  updateParticipantStatus,
  getEventFormMatrix,
  getEventDetail,
  getEventFormQuestions,
  saveEventFormQuestions,
  initializeEventForm,
  disableEventForm,
} from "../../services/api";
import type { ManagedEventSummary, EventParticipantRow, FormMatrix, FormQuestion } from "../../services/api";

const ParticipantManagementPage: React.FC = () => {
  const [managed, setManaged] = useState<ManagedEventSummary[]>([]);
  const [managedLoading, setManagedLoading] = useState(false);
  const [managedError, setManagedError] = useState<string | null>(null);

  const [selectedEventId, setSelectedEventId] = useState<string>("");

  const [participants, setParticipants] = useState<EventParticipantRow[]>([]);
  const [participantsAll, setParticipantsAll] = useState<EventParticipantRow[]>([]);
  const [participantsLoading, setParticipantsLoading] = useState(false);
  const [participantsError, setParticipantsError] = useState<string | null>(null);
  const [pFilter, setPFilter] = useState<"stall" | "accept" | "reject" | "all">("stall");

  const [organizers, setOrganizers] = useState<EventParticipantRow[]>([]);

  const [matrix, setMatrix] = useState<FormMatrix | null>(null);
  const [matrixEventId, setMatrixEventId] = useState<string>("");
  const [viewUserId, setViewUserId] = useState<string>("");

  // Form builder state
  const [formEnabled, setFormEnabled] = useState<boolean | null>(null);
  const [questions, setQuestions] = useState<FormQuestion[]>([]);
  const [formLoading, setFormLoading] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  async function loadManaged() {
    setManagedLoading(true);
    setManagedError(null);
    try {
      const list = await listManagedEvents();
      setManaged(list);
      if (!selectedEventId && list.length > 0) setSelectedEventId(list[0].eventId);
    } catch (e: any) {
      setManagedError(e?.message || "Failed to load manageable events");
    } finally {
      setManagedLoading(false);
    }
  }

  useEffect(() => { loadManaged(); }, []);

  async function loadParticipants(eid: string, status: "stall" | "accept" | "reject" | "all" = pFilter) {
    if (!eid) return;
    setParticipantsLoading(true);
    setParticipantsError(null);
    try {
      const opt = status === "all" ? {} : { status };
      const list = await listEventParticipants(eid, opt as any);
      setParticipants(list);
      // load all (for counts)
      const all = await listEventParticipants(eid, {} as any);
      setParticipantsAll(all);
      // load organizers
      const orgs = await listEventParticipants(eid, { role: 'organizer' });
      setOrganizers(orgs);
    } catch (e: any) {
      setParticipantsError(e?.message || "Failed to load participants");
    } finally {
      setParticipantsLoading(false);
    }
  }

  useEffect(() => {
    if (selectedEventId) loadParticipants(selectedEventId, pFilter);
  }, [selectedEventId, pFilter]);

  // Load form detail + questions
  async function loadForm(eid: string) {
    setFormLoading(true);
    setFormError(null);
    try {
      const detail = await getEventDetail(eid);
      setFormEnabled(!!detail?.have_form);
      let qs: FormQuestion[] = [];
      if (detail?.have_form) {
        qs = await getEventFormQuestions(eid).catch(() => []);
      }
      setQuestions(qs);
    } catch (e: any) {
      // if detail fails, attempt questions; if also fails, mark none
      try {
        const qs = await getEventFormQuestions(eid);
        setFormEnabled(qs.length > 0);
        setQuestions(qs);
      } catch (err: any) {
        setFormEnabled(false);
        setQuestions([]);
      }
    } finally {
      setFormLoading(false);
    }
  }

  useEffect(() => {
    if (selectedEventId) loadForm(selectedEventId);
  }, [selectedEventId]);

  async function onUpdateStatus(eid: string, uid: string, status: "accept" | "stall" | "reject") {
    try {
      await updateParticipantStatus({ user_id: uid, event_id: eid, status });
      // refresh lists and counts
      await loadParticipants(eid, pFilter);
      await loadManaged();
    } catch (e: any) {
      alert(e?.message || "Failed to update status");
    }
  }

  async function ensureMatrixLoaded(eid: string) {
    if (matrix && matrixEventId === eid) return;
    try {
      const m = await getEventFormMatrix(eid);
      setMatrix(m);
      setMatrixEventId(eid);
    } catch (e: any) {
      setMatrix(null);
      setMatrixEventId("");
    }
  }

  const counts = (() => {
    const all = participantsAll;
    const c = { stall: 0, accept: 0, reject: 0 } as Record<string, number>;
    all.forEach(p => { if (p.role !== 'organizer') c[(p.status || 'stall')] = (c[(p.status || 'stall')] || 0) + 1; });
    return c;
  })();

  return (
    <div className="p-4 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Participant Management</h1>
        <button className="px-3 py-1.5 border rounded" onClick={() => loadManaged()}>Refresh</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Left: manageable events */}
        <div className="md:col-span-1 border rounded-xl bg-white">
          <div className="p-3 border-b flex items-center justify-between">
            <div className="font-semibold">My Manageable Events</div>
            <button className="text-sm px-2 py-1 border rounded" onClick={() => loadManaged()}>Reload</button>
          </div>
          {managedError && <div className="p-3 text-red-700">{managedError}</div>}
          {managedLoading && <div className="p-3 text-gray-500">Loading…</div>}
          {!managedLoading && managed.length === 0 && <div className="p-3 text-gray-600">No manageable events</div>}
          <div className="divide-y">
            {managed.map(m => (
              <button key={m.eventId}
                      className={`w-full text-left p-3 hover:bg-emerald-50 ${selectedEventId===m.eventId ? 'bg-emerald-50' : ''}`}
                      onClick={() => { setSelectedEventId(m.eventId); setViewUserId(''); }}>
                <div className="font-medium truncate">{m.topic || '(untitled)'}</div>
                <div className="text-xs text-gray-600 flex gap-2 mt-1">
                  <span>Pending: {m.pendingCount ?? 0}</span>
                  <span>Accepted: {m.acceptedCount ?? 0}</span>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Right: participants + organizers + summary */}
        <div className="md:col-span-2 border rounded-xl bg-white">
          <div className="p-3 border-b space-y-2">
            <div className="flex items-center justify-between gap-3 flex-wrap">
              <div className="font-semibold">Participants</div>
              <div className="flex items-center gap-2">
                {(['stall','accept','reject','all'] as const).map(k => (
                  <button key={k}
                          className={`text-sm px-2 py-1 border rounded ${pFilter===k ? 'bg-emerald-600 text-white' : ''}`}
                          onClick={() => setPFilter(k)}>
                    {k === 'stall' ? 'Pending' : k.charAt(0).toUpperCase() + k.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            {/* Summary counts */}
            {selectedEventId && (
              <div className="grid grid-cols-3 gap-2">
                <div className="text-xs px-3 py-2 border rounded bg-amber-50 border-amber-200 text-amber-800">Pending: {counts.stall || 0}</div>
                <div className="text-xs px-3 py-2 border rounded bg-emerald-50 border-emerald-200 text-emerald-800">Accepted: {counts.accept || 0}</div>
                <div className="text-xs px-3 py-2 border rounded bg-rose-50 border-rose-200 text-rose-800">Rejected: {counts.reject || 0}</div>
              </div>
            )}

            {/* Organizers list */}
            {selectedEventId && (
              <div className="mt-2">
                <div className="text-sm font-medium text-slate-800 mb-1">Organizers</div>
                {organizers.length === 0 ? (
                  <div className="text-xs text-gray-600">No organizers found.</div>
                ) : (
                  <div className="flex flex-wrap gap-1">
                    {organizers.map(o => (
                      <span key={o.user_id} className="text-xs px-2 py-0.5 rounded border bg-slate-50 border-slate-200 text-slate-800">
                        {[o.first_name, o.last_name].filter(Boolean).join(' ') || o.user_id}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          {participantsError && <div className="p-3 text-red-700">{participantsError}</div>}
          {!selectedEventId && <div className="p-3 text-gray-600">Select an event</div>}
          {selectedEventId && participantsLoading && <div className="p-3 text-gray-500">Loading…</div>}
          {selectedEventId && !participantsLoading && (
            <div className="p-3">
              {participants.length === 0 ? (
                <div className="text-gray-600">No participants for this filter.</div>
              ) : (
                <div className="grid gap-2">
                  {participants.map(p => (
                    <div key={p.user_id} className={`border rounded-lg p-3 flex items-center justify-between ${viewUserId===p.user_id ? 'bg-emerald-50' : 'bg-white'}`}>
                      <div className="flex items-center gap-3">
                        <div className="h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center text-gray-600 text-sm">
                          {(p.first_name || '?').charAt(0)}
                        </div>
                        <div>
                          <div className="font-medium">{[p.first_name, p.last_name].filter(Boolean).join(' ') || p.user_id}</div>
                          <div className="text-xs text-gray-600">{p.role || 'participant'} • {p.status || '-'}</div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <button className="text-xs px-2 py-1 border rounded" onClick={() => onUpdateStatus(selectedEventId, p.user_id, 'accept')}>Accept</button>
                        <button className="text-xs px-2 py-1 border rounded" onClick={() => onUpdateStatus(selectedEventId, p.user_id, 'stall')}>Stall</button>
                        <button className="text-xs px-2 py-1 border rounded text-red-700 border-red-200" onClick={() => onUpdateStatus(selectedEventId, p.user_id, 'reject')}>Reject</button>
                        {p.response_id && (
                          <button className="text-xs px-2 py-1 border rounded bg-slate-50" onClick={async () => {
                            await ensureMatrixLoaded(selectedEventId);
                            setViewUserId(prev => prev === p.user_id ? '' : p.user_id);
                          }}>View Form</button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {viewUserId && matrix && matrixEventId === selectedEventId && (
                <div className="mt-4 border-t pt-3">
                  <div className="font-semibold mb-2">Form Submission</div>
                  {(() => {
                    const resp = matrix.responses.find(r => r.user_id === viewUserId);
                    if (!resp) return <div className="text-gray-600">No form response found for this user.</div>;
                    return (
                      <div className="grid gap-2">
                        {matrix.questions.map((q, idx) => (
                          <div key={q.id} className="border rounded p-2 bg-slate-50">
                            <div className="text-sm font-medium text-slate-800">{q.text}</div>
                            <div className="text-sm text-slate-700 mt-1">{resp.answers?.[idx] ?? ''}</div>
                          </div>
                        ))}
                      </div>
                    );
                  })()}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Form builder / viewer */}
      <div className="border rounded-xl bg-white">
        <div className="p-3 border-b flex items-center justify-between">
          <div className="font-semibold">Event Form</div>
          <div className="flex items-center gap-2">
            {selectedEventId && (formEnabled ? (
              <button className="text-sm px-2 py-1 border rounded" onClick={async () => {
                try { await disableEventForm(selectedEventId); setFormEnabled(false); setQuestions([]); }
                catch (e: any) { alert(e?.message || 'Failed to disable form'); }
              }}>Disable Form</button>
            ) : (
              <button className="text-sm px-2 py-1 border rounded" onClick={async () => {
                try { await initializeEventForm(selectedEventId); setFormEnabled(true); await loadForm(selectedEventId); }
                catch (e: any) { alert(e?.message || 'Failed to initialize form'); }
              }}>Initialize Form</button>
            ))}
            {selectedEventId && <button className="text-sm px-2 py-1 border rounded" onClick={() => loadForm(selectedEventId)}>Reload</button>}
          </div>
        </div>
        <div className="p-3">
          {!selectedEventId && <div className="text-gray-600">Select an event to manage form</div>}
          {selectedEventId && formLoading && <div className="text-gray-500">Loading…</div>}
          {selectedEventId && !formLoading && (
            <>
              {formEnabled ? (
                <div className="space-y-3">
                  <div className="text-sm text-gray-700">Define or edit questions, then click Save to apply. This replaces the entire list.</div>
                  <div className="grid gap-2">
                    {questions.map((q, idx) => (
                      <div key={q.id || idx} className="border rounded p-2 bg-slate-50">
                        <div className="flex items-center gap-2">
                          <label className="text-xs text-gray-600">Order</label>
                          <input type="number" value={q.order_index}
                                 onChange={e => setQuestions(prev => prev.map((x,i)=> i===idx ? { ...x, order_index: Number(e.target.value) } : x))}
                                 className="w-16 px-2 py-1 border rounded" />
                          <label className="text-xs text-gray-600 ml-2">Required</label>
                          <input type="checkbox" checked={!!q.required}
                                 onChange={e => setQuestions(prev => prev.map((x,i)=> i===idx ? { ...x, required: e.target.checked } : x))}
                                 className="h-4 w-4" />
                        </div>
                        <input
                          value={q.question_text}
                          onChange={e => setQuestions(prev => prev.map((x,i)=> i===idx ? { ...x, question_text: e.target.value } : x))}
                          placeholder={`Question #${idx+1}`}
                          className="mt-2 w-full px-3 py-2 border rounded"
                        />
                        <div className="mt-2 flex justify-end">
                          <button className="text-xs px-2 py-1 border rounded text-red-700 border-red-200" onClick={() => setQuestions(prev => prev.filter((_,i)=> i!==idx))}>Remove</button>
                        </div>
                      </div>
                    ))}
                  </div>
                  <div className="flex items-center gap-2">
                    <button className="px-3 py-1.5 border rounded" onClick={() => setQuestions(prev => [...prev, { question_text: '', required: false, order_index: (prev[prev.length-1]?.order_index ?? prev.length) + 1 }])}>Add Question</button>
                    <button className="px-3 py-1.5 border rounded bg-emerald-600 text-white" onClick={async () => {
                      try {
                        await saveEventFormQuestions(selectedEventId, questions.filter(q => q.question_text.trim().length>0));
                        await loadForm(selectedEventId);
                        alert('Saved');
                      } catch (e: any) {
                        alert(e?.message || 'Failed to save questions');
                      }
                    }}>Save</button>
                  </div>
                </div>
              ) : (
                <div className="text-gray-700">No form initialized for this event.</div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default ParticipantManagementPage;
