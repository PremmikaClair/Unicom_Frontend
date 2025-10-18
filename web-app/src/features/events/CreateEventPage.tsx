import React, { useEffect, useMemo, useState } from 'react';
import { createEvent, apiFetch } from '../../services/api';

type OrgRow = { org_path: string; short_name?: string; name?: string; node_id?: string };
type Membership = { org_path?: string; position_key?: string };

const CreateEventPage: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [orgs, setOrgs] = useState<OrgRow[]>([]);
  const [memberships, setMemberships] = useState<Membership[]>([]);

  const [topic, setTopic] = useState('');
  const [description, setDescription] = useState('');
  const [orgPath, setOrgPath] = useState('');
  const [posKey, setPosKey] = useState('');
  const [maxPart, setMaxPart] = useState<number>(0);
  const [date, setDate] = useState<string>('');
  const [start, setStart] = useState<string>('');
  const [end, setEnd] = useState<string>('');
  const [visPublic, setVisPublic] = useState(true);

  useEffect(() => {
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const [orgsRaw, prof] = await Promise.all([
          apiFetch<any[]>('/event/manageable-orgs').catch(() => [] as any[]),
          apiFetch<any>('/users/myprofile').catch(() => ({})),
        ]);
        setOrgs(Array.isArray(orgsRaw) ? orgsRaw : []);
        const mems = Array.isArray(prof?.memberships) ? prof.memberships : [];
        setMemberships(mems.map((m: any) => ({
          org_path: m?.org_unit?.org_path || m?.org_path,
          position_key: m?.position?.key || m?.position_key,
        })));
        if (orgsRaw?.length) setOrgPath(orgsRaw[0]?.org_path || '');
      } catch (e: any) {
        setError(e?.message || 'Failed to load prerequisites');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const posOptions = useMemo(() => (
    memberships.filter(m => m.org_path === orgPath && m.position_key).map(m => m.position_key as string)
  ), [memberships, orgPath]);

  useEffect(() => {
    if (posOptions.length && !posOptions.includes(posKey)) setPosKey(posOptions[0] || '');
  }, [posOptions]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      if (!topic.trim()) throw new Error('Topic is required');
      const org = orgs.find(o => o.org_path === orgPath);
      const node_id = org?.node_id;
      if (!node_id) throw new Error('Organizer node_id not found');
      if (!posKey) throw new Error('No role to post as in this org');
      // build visibility
      const visibility = visPublic ? { access: 'public' } : { access: 'org', audience: [{ org_path: orgPath, scope: 'exact' }] };
      // build schedules
      const dt = date ? new Date(date) : new Date();
      const [sh, sm] = (start || '09:00').split(':').map(x => parseInt(x, 10));
      const [eh, em] = (end || '10:00').split(':').map(x => parseInt(x, 10));
      const dateOnly = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate()));
      const ts = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate(), sh || 9, sm || 0));
      const te = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate(), eh || 10, em || 0));

      await createEvent({
        node_id,
        topic: topic.trim(),
        description: description.trim(),
        max_participation: Number.isFinite(maxPart) ? maxPart : 0,
        posted_as: { org_path: orgPath, position_key: posKey },
        visibility,
        org_of_content: orgPath,
        schedules: [{
          date: dateOnly.toISOString(),
          time_start: ts.toISOString(),
          time_end: te.toISOString(),
          location: '',
          description: '',
        }],
      });
      alert('Event created');
      history.back();
    } catch (e: any) {
      setError(e?.message || 'Create failed');
    }
  }

  return (
    <div className="p-4 space-y-4">
      <h1 className="text-xl font-semibold">Create Event</h1>
      {loading && <div className="text-gray-500">Loading…</div>}
      {error && <div className="p-3 rounded border border-red-200 text-red-700">{error}</div>}
      {!loading && (
        <form onSubmit={onSubmit} className="grid gap-3 max-w-2xl">
          <label className="grid gap-1">
            <span className="text-sm text-gray-600">Topic</span>
            <input className="px-3 py-2 border rounded" value={topic} onChange={e => setTopic(e.target.value)} />
          </label>
          <label className="grid gap-1">
            <span className="text-sm text-gray-600">Description</span>
            <textarea className="px-3 py-2 border rounded" value={description} onChange={e => setDescription(e.target.value)} />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="grid gap-1">
              <span className="text-sm text-gray-600">Organizer (Org)</span>
              <select className="px-3 py-2 border rounded" value={orgPath} onChange={e => setOrgPath(e.target.value)}>
                {orgs.map(o => (
                  <option key={o.org_path} value={o.org_path}>{o.short_name || o.name || o.org_path}</option>
                ))}
              </select>
            </label>
            <label className="grid gap-1">
              <span className="text-sm text-gray-600">Post As (Position)</span>
              <select className="px-3 py-2 border rounded" value={posKey} onChange={e => setPosKey(e.target.value)}>
                {posOptions.length ? posOptions.map(k => (<option key={k} value={k}>{k}</option>)) : <option value="">No role</option>}
              </select>
            </label>
          </div>
          <label className="grid gap-1">
            <span className="text-sm text-gray-600">Max participation</span>
            <input type="number" className="px-3 py-2 border rounded" value={maxPart} onChange={e => setMaxPart(parseInt(e.target.value || '0', 10))} />
          </label>
          <div className="grid grid-cols-3 gap-3">
            <label className="grid gap-1">
              <span className="text-sm text-gray-600">Date</span>
              <input type="date" className="px-3 py-2 border rounded" value={date} onChange={e => setDate(e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-sm text-gray-600">Start</span>
              <input type="time" className="px-3 py-2 border rounded" value={start} onChange={e => setStart(e.target.value)} />
            </label>
            <label className="grid gap-1">
              <span className="text-sm text-gray-600">End</span>
              <input type="time" className="px-3 py-2 border rounded" value={end} onChange={e => setEnd(e.target.value)} />
            </label>
          </div>
          <label className="inline-flex gap-2 items-center">
            <input type="checkbox" checked={visPublic} onChange={e => setVisPublic(e.target.checked)} />
            <span className="text-sm">Public visibility</span>
          </label>
          <div className="flex gap-2">
            <button type="submit" className="px-3 py-2 rounded bg-emerald-600 text-white">Create</button>
            <button type="button" className="px-3 py-2 rounded border" onClick={() => history.back()}>Cancel</button>
          </div>
        </form>
      )}
    </div>
  );
};

export default CreateEventPage;

