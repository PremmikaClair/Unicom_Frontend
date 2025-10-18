import React, { useEffect, useMemo, useState } from "react";
import type { OrgUnitNode, Policy, Position, MembershipWithUser, User } from "../../types";
import { getOrgTree, listPolicies, createPolicy, upsertPolicy, deletePolicy, getPositions, getUsersPaged, createMembership, deactivateMembership, listMembershipsWithUsers } from "../../services/api";
import { apiFetch } from "../../services/api";
import useAbilities from "../../hooks/useAbilities";

// Action catalog aligned with backend simple-mode allow-list
const ALL_ACTIONS = [
  "post:create",
  "post:moderate",
  "event:create",
  "event:manage",
  "membership:assign",
  "membership:revoke",
  "position:create",
  "policy:write",
];

const ScopeOptions = [
  { value: "exact", label: "Exact node only" },
  { value: "subtree", label: "Node + descendants" },
];

const EffectOptions = [{ value: "allow", label: "Allow" }]; // deny reserved for future

// Path tag helper (like Role tag without position)
function pathLabel(path?: string) {
  const bits = (path || "/").split("/").filter(Boolean).reverse().map(b => b.toUpperCase());
  return bits.join(" • ") || "/";
}
function pathColorClasses(path?: string) {
  if ((path || "").startsWith("/club")) return "bg-orange-100 text-orange-700 ring-1 ring-orange-200";
  if ((path || "").startsWith("/fac")) return "bg-green-100 text-green-700 ring-1 ring-green-200";
  return "bg-blue-100 text-blue-700 ring-1 ring-blue-200";
}

/* --------- Tree component (read-only) --------- */
const TreeNode: React.FC<{
  node: OrgUnitNode;
  selected?: string;
  onSelect: (org_path: string) => void;
}> = ({ node, selected, onSelect }) => {
  const label = node.short_name || node.label || node.org_path.split("/").filter(Boolean).slice(-1)[0] || "/";
  const isSelected = selected === node.org_path;

  return (
    <div className="ml-3">
      <button
        className={`text-left px-2 py-1 rounded-md w-full transition ${
          isSelected ? "bg-emerald-50 text-emerald-800 ring-1 ring-emerald-200" : "hover:bg-gray-50"
        }`}
        onClick={() => onSelect(node.org_path)}
        title={node.org_path}
      >
        <span className="font-medium">{label}</span>
        <span className="text-xs text-gray-500"> ({node.org_path})</span>
      </button>
      {node.children?.length ? (
        <div className="ml-3 border-l pl-2 border-gray-200">
          {node.children.map((ch) => (
            <TreeNode key={ch.org_path} node={ch} selected={selected} onSelect={onSelect} />
          ))}
        </div>
      ) : null}
    </div>
  );
};

function positionLabel(key: string, positions: Position[]) {
  const pos = positions.find(p => p.key === key);
  return (pos?.display && (pos.display.en || Object.values(pos.display)[0])) || pos?.key || key;
}

/* --------- Policy form --------- */
const PolicyForm: React.FC<{
  initial?: Partial<Policy>;
  selectedOrg?: string;
  onSubmit: (p: Policy) => Promise<void>;
  onCancel?: () => void;
  mode?: "create" | "upsert";
}> = ({ initial, selectedOrg, onSubmit, onCancel, mode = "create" }) => {
  const [positionKey, setPositionKey] = useState(initial?.position_key ?? "head");
  const [orgPrefix, setOrgPrefix] = useState(initial?.where?.org_prefix ?? (selectedOrg || "/"));
  const [scope, setScope] = useState<"exact" | "subtree">((initial?.scope as any) ?? "exact");
  const [effect, setEffect] = useState<"allow" | "deny">((initial?.effect as any) ?? "allow");
  const [enabled, setEnabled] = useState<boolean>(initial?.enabled ?? true);
  const [actions, setActions] = useState<string[]>(initial?.actions ?? ["post:create"]);

  const toggleAction = (a: string) =>
    setActions((prev) => (prev.includes(a) ? prev.filter((x) => x !== a) : [...prev, a]));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload: Policy = {
      position_key: positionKey.trim(),
      where: { org_prefix: orgPrefix.trim() || "/" },
      scope,
      effect,
      actions: actions.slice().sort(),
      enabled,
    };
    await onSubmit(payload);
  };

  return (
    <form onSubmit={submit} className="space-y-3">
      <div>
        <label className="block text-sm font-medium text-gray-700">Position key</label>
        <input
          className="border rounded px-2 py-1 w-full focus:ring-2 focus:ring-emerald-300"
          placeholder="head | member | student"
          value={positionKey}
          onChange={(e) => setPositionKey(e.target.value)}
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700">Org prefix</label>
        <input
          className="border rounded px-2 py-1 w-full focus:ring-2 focus:ring-emerald-300"
          placeholder="/faculty/ or /club/"
          value={orgPrefix}
          onChange={(e) => setOrgPrefix(e.target.value)}
        />
        <p className="text-xs text-gray-500">Policies attach to memberships whose org_path starts with this prefix.</p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="block text-sm font-medium text-gray-700">Scope</label>
          <select className="border rounded px-2 py-1 w-full focus:ring-2 focus:ring-emerald-300" value={scope} onChange={(e) => setScope(e.target.value as any)}>
            {ScopeOptions.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Effect</label>
          <select className="border rounded px-2 py-1 w-full focus:ring-2 focus:ring-emerald-300" value={effect} onChange={(e) => setEffect(e.target.value as any)}>
            {EffectOptions.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium">Actions</label>
        <div className="grid grid-cols-2 gap-1 mt-1">
          {ALL_ACTIONS.map((a) => (
            <label key={a} className="text-sm inline-flex items-center gap-2">
              <input type="checkbox" checked={actions.includes(a)} onChange={() => toggleAction(a)} />
              {a}
            </label>
          ))}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <label className="text-sm inline-flex items-center gap-2">
          <input type="checkbox" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} />
          Enabled
        </label>
      </div>

      <div className="flex gap-2">
        <button type="submit" className="px-3 py-1.5 bg-blue-600 text-white rounded">
          {mode === "upsert" ? "Save (Upsert)" : "Create Policy"}
        </button>
        {onCancel && (
          <button type="button" className="px-3 py-1.5 bg-gray-200 rounded" onClick={onCancel}>
            Cancel
          </button>
        )}
      </div>
    </form>
  );
};

/* --------- Main page --------- */
const OrgPoliciesPage: React.FC = () => {
  const [tree, setTree] = useState<OrgUnitNode[]>([]);
  const [selectedOrg, setSelectedOrg] = useState<string>("");
  const [policies, setPolicies] = useState<Policy[]>([]);
  const [loadingTree, setLoadingTree] = useState(false);
  const [loadingPolicies, setLoadingPolicies] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [positions, setPositions] = useState<Position[]>([]);
  const [assignQuery, setAssignQuery] = useState("");
  const [assignResults, setAssignResults] = useState<User[]>([]);
  const [selectedUserKeys, setSelectedUserKeys] = useState<Record<string, boolean>>({});
  const [assignPosKey, setAssignPosKey] = useState("");
  const [loadingAssign, setLoadingAssign] = useState(false);
  const [orgMemberships, setOrgMemberships] = useState<MembershipWithUser[]>([]);
  // positions inspector removed per request

  // Abilities for the selected node
  const { abilities, loading: loadingAbilities, refetch: refetchAbilities } = useAbilities(selectedOrg);
  const canCreatePosition = abilities["position:create"] === true;
  const canPolicyWrite = abilities["policy:write"] === true;

  // Load tree on mount
  useEffect(() => {
    (async () => {
      try {
        setLoadingTree(true);
        const t = await getOrgTree();
        setTree(t || []);
        // auto-select root-ish
        const first = t?.[0]?.org_path ?? "/faculty/";
        setSelectedOrg(first);
      } catch (e: any) {
        setError(e?.message ?? "Failed to load org tree");
      } finally {
        setLoadingTree(false);
      }
    })();
  }, []);

  // Load positions (for assignment options)
  useEffect(() => {
    (async () => {
      try { setPositions(await getPositions()); } catch {}
    })();
  }, []);

  // Load policies when selected org changes (filter by org_prefix)
  useEffect(() => {
    (async () => {
      if (!selectedOrg) return;
      try {
        setLoadingPolicies(true);
        const ps = await listPolicies({ org_prefix: selectedOrg.startsWith("/") ? selectedOrg.split("/", 3).slice(0, 2).join("/") + "/" : selectedOrg });
        // If your API returns all, you can filter client-side by prefix:
        // const psAll = await listPolicies();
        // const ps = psAll.filter(p => selectedOrg.startsWith(p.where.org_prefix));
        setPolicies(ps || []);
      } catch (e: any) {
        setError(e?.message ?? "Failed to load policies");
      } finally {
        setLoadingPolicies(false);
      }
    })();
  }, [selectedOrg]);

  // Load memberships at selected org
  const refreshOrgMemberships = async () => {
    if (!selectedOrg) { setOrgMemberships([]); return; }
    try { setOrgMemberships(await listMembershipsWithUsers(selectedOrg)); } catch { setOrgMemberships([]); }
  };
  useEffect(() => { refreshOrgMemberships(); /* eslint-disable react-hooks/exhaustive-deps */ }, [selectedOrg]);

  const onCreate = async (p: Policy) => {
    const saved = await createPolicy(p);
    setPolicies((prev) => [saved, ...prev]);
    alert("Policy created");
    refetchAbilities();
  };

  const onUpsert = async (p: Policy) => {
    const saved = await upsertPolicy(p);
    setPolicies((prev) => {
      const idx = prev.findIndex(
        (x) =>
          x.position_key === saved.position_key &&
          x.where?.org_prefix === saved.where?.org_prefix &&
          x.scope === saved.scope
      );
      if (idx >= 0) {
        const copy = [...prev];
        copy[idx] = saved;
        return copy;
      }
      return [saved, ...prev];
    });
    alert("Policy upserted");
    refetchAbilities();
  };

  const onDelete = async (p: Policy) => {
    if (!confirm(`Delete policy for ${p.position_key} at ${p.where.org_prefix}?`)) return;
    await deletePolicy(p.where.org_prefix, p.position_key);
    setPolicies((prev) => prev.filter((x) => !(x.position_key === p.position_key && x.where.org_prefix === p.where.org_prefix)));
  };

  const canEdit = canPolicyWrite;

  const selectedPolicies = useMemo(
    () => policies.filter((p) => selectedOrg.startsWith(p.where.org_prefix)),
    [policies, selectedOrg]
  );

  // Positions usable at this node
  const usablePositions = useMemo(() => {
    const path = selectedOrg || "/";
    const norm = (s?: string) => {
      if (!s || s === "/") return "/";
      return (s.startsWith("/") ? s : "/" + s).replace(/\/$/, "");
    };
    const isUsable = (p: Position) => {
      const scope = p.scope || {} as any;
      const owner = norm(scope.org_path);
      const inherit = !!scope.inherit;
      if (!owner || owner === "/") return true;
      if (owner === norm(path)) return true;
      if (inherit && norm(path).startsWith(owner + (owner === "/" ? "" : ""))) {
        // owner subtree
        return norm(path) === owner || norm(path).startsWith(owner + "/");
      }
      return false;
    };
    return positions.filter(isUsable);
  }, [positions, selectedOrg]);

  // Search users for assignment
  const runSearch = async () => {
    const q = assignQuery.trim(); if (!q) { setAssignResults([]); return; }
    try {
      setLoadingAssign(true);
      const { items } = await getUsersPaged({ q, limit: 10 });
      setAssignResults(items as unknown as User[]);
      setSelectedUserKeys({});
    } catch (e) {
      setAssignResults([]);
    } finally {
      setLoadingAssign(false);
    }
  };

  const toggleSelectUser = (u: User, on?: boolean) => {
    const key = u._id || u.email || String(u.id);
    setSelectedUserKeys(prev => ({ ...prev, [key]: on ?? !prev[key] }));
  };

  const assignSelectedUsers = async () => {
    const pos = assignPosKey.trim();
    if (!pos) { alert('Select a position'); return; }
    if (!canPolicyWrite && !abilities["membership:assign"]) { alert("No permission to assign here"); return; }
    const picked = assignResults.filter(u => selectedUserKeys[u._id || u.email || String(u.id)]);
    if (picked.length === 0) { alert('Select at least one user'); return; }
    setLoadingAssign(true);
    try {
      const tasks = picked.map(u => {
        const ref = u.student_id || String(u.id) || (u._id || "");
        return createMembership({ user_ref: ref, org_path: selectedOrg, position_key: pos });
      });
      const res = await Promise.allSettled(tasks);
      const ok = res.filter(r => r.status === 'fulfilled').length;
      const fail = res.length - ok;
      await refreshOrgMemberships();
      alert(`Assigned ${ok} user(s)${fail ? `, ${fail} failed` : ''}`);
      setSelectedUserKeys({});
    } catch (e: any) {
      alert(e?.message || 'Assignment failed');
    } finally {
      setLoadingAssign(false);
    }
  };

  const revokeMembership = async (m: any) => {
    if (!m._id) return;
    if (!abilities["membership:revoke"]) { alert('No permission'); return; }
    if (!confirm(`Deactivate ${m.position_key} at ${m.org_path}?`)) return;
    try {
      await deactivateMembership(m._id);
      await refreshOrgMemberships();
    } catch (e: any) {
      alert(e?.message || 'Failed to revoke');
    }
  };

  return (
    <div className="p-4 grid grid-cols-1 md:grid-cols-3 gap-4">
      {/* Left: Org tree */}
      <div className="md:col-span-1 border rounded-xl p-3 bg-white shadow-sm">
        <div className="flex items-center justify-between mb-2">
          <h2 className="font-semibold text-emerald-800">Organization</h2>
          {loadingTree && <span className="text-xs text-gray-500">Loading…</span>}
        </div>
        {error && <div className="text-sm text-red-600 mb-2">{error}</div>}
        {tree.length ? (
          <div className="max-h-[70vh] overflow-auto">
            {tree.map((n) => (
              <TreeNode key={n.org_path} node={n} selected={selectedOrg} onSelect={setSelectedOrg} />
            ))}
          </div>
        ) : (
          <div className="text-sm text-gray-500">No tree</div>
        )}
      </div>

      {/* Right: Policies */}
      <div className="md:col-span-2 space-y-4">
        {/* Membership assignments at selected node */}
        <div className="border rounded-xl p-3 bg-white shadow-sm space-y-3">
          <h3 className="font-medium text-emerald-800 flex items-center gap-2">
            Roles Assignments at
            {selectedOrg && (
              <span className={`${pathColorClasses(selectedOrg)} inline-block rounded-full text-[11px] px-2.5 py-0.5`}>{pathLabel(selectedOrg)}</span>
            )}
          </h3>
          <div className="text-xs text-gray-600">Search a user to assign a position at this node.</div>
          <div className="flex flex-wrap items-center gap-2">
            <input className="border rounded px-2 py-1 text-sm flex-1 min-w-[240px] focus:ring-2 focus:ring-emerald-300" placeholder="Search by name / email / student id" value={assignQuery} onChange={e => setAssignQuery(e.target.value)} />
            <button onClick={runSearch} disabled={loadingAssign} className="px-3 py-1.5 text-xs rounded-full bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm disabled:opacity-50">Search</button>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <label className="text-sm text-gray-700">Assign as</label>
            <select className="border rounded px-2 py-1 text-sm focus:ring-2 focus:ring-emerald-300" value={assignPosKey} onChange={e => setAssignPosKey(e.target.value)}>
              <option value="">Select position…</option>
              {usablePositions.map(p => (
                <option key={p.key} value={p.key}>{(p.display && (p.display.en || Object.values(p.display)[0])) || p.key}</option>
              ))}
            </select>
            {!abilities["membership:assign"] && (
              <span className="text-xs text-orange-600">You don’t have permission to assign here.</span>
            )}
          </div>
          {assignResults.length > 0 && (
            <div className="mt-2 border rounded-lg overflow-hidden">
              {assignResults.map(u => {
                const key = u._id || u.email || String(u.id);
                const checked = !!selectedUserKeys[key];
                return (
                  <label key={key} className="flex items-center justify-between px-2 py-1 border-t first:border-t-0 hover:bg-emerald-50/40">
                    <div className="flex items-center gap-2">
                      <input type="checkbox" checked={checked} onChange={(e) => toggleSelectUser(u, e.target.checked)} />
                      <div className="text-sm">{u.firstName} {u.lastName} <span className="text-gray-500">({u.email})</span></div>
                    </div>
                    <div className="text-xs text-gray-500">sid: {u.student_id || '-'}</div>
                  </label>
                );
              })}
              <div className="flex items-center justify-end gap-2 p-2">
                <button onClick={assignSelectedUsers} disabled={!abilities["membership:assign"] || loadingAssign || !assignPosKey} className={`px-3 py-1.5 text-xs rounded-full bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm ${!abilities["membership:assign"] ? 'opacity-50 cursor-not-allowed' : ''}`}>Assign selected</button>
              </div>
            </div>
          )}

          {/* Current memberships at this node */}
          <div className="mt-3">
            <div className="flex items-center justify-between mb-1">
              <div className="text-sm font-medium text-emerald-800">Active roles here</div>
              <div className="text-xs text-gray-600">Active users (any position): {Array.from(new Set(orgMemberships.map(m => (m.user?._id || m.user?.email || String((m as any).user_id || m._id))))).length}</div>
            </div>
            <div className="overflow-x-auto border rounded-lg">
              <table className="min-w-full text-sm">
                <thead className="bg-emerald-50/70">
                  <tr>
                    <th className="p-2 text-left">Name</th>
                    <th className="p-2 text-left">Student ID</th>
                    <th className="p-2 text-left">Position</th>
                    <th className="p-2 text-left w-24">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {orgMemberships.length ? (
                    orgMemberships.map((m, i) => (
                      <tr key={m._id || i} className="border-t hover:bg-emerald-50/40">
                        <td className="p-2">{((m.user?.firstName || '') + ' ' + (m.user?.lastName || '')).trim() || m.user?.email || 'User'}</td>
                        <td className="p-2">{m.user?.student_id || '-'}</td>
                        <td className="p-2">{positionLabel(m.position_key, positions)}</td>
                        <td className="p-2">
                          <button onClick={() => revokeMembership(m)} disabled={!abilities["membership:revoke"]} className={`text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-700 hover:bg-red-100 shadow-sm ${!abilities["membership:revoke"] ? 'opacity-50 cursor-not-allowed' : ''}`}>Remove</button>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr><td colSpan={4} className="p-3 text-gray-500">No active memberships</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
        {/* Create Position (org-scoped) */}
        <div className="border rounded p-3">
          <h3 className="font-medium mb-2">Create Position at node</h3>
          <div className="flex items-center gap-2">
            <CreatePositionInline selectedOrg={selectedOrg} canCreate={canCreatePosition} />
            {loadingAbilities && <span className="text-xs text-gray-500">Checking permissions…</span>}
          </div>
        </div>
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-emerald-800">Permissions</h2>
          {loadingPolicies && <span className="text-xs text-gray-500">Loading…</span>}
        </div>

        {/* Create / Upsert */}
        <div className="grid md:grid-cols-2 gap-6">
          {canPolicyWrite ? (
            <>
              <div className="border rounded-xl p-3 bg-white shadow-sm">
                <h3 className="font-medium mb-2">Create Permission</h3>
                <PolicyForm
                  selectedOrg={selectedOrg}
                  onSubmit={onCreate}
                  mode="create"
                />
              </div>
              <div className="border rounded-xl p-3 bg-white shadow-sm">
                <h3 className="font-medium mb-2">Upsert Permission (by position_key + org_prefix + scope)</h3>
                <PolicyForm
                  selectedOrg={selectedOrg}
                  onSubmit={onUpsert}
                  mode="upsert"
                />
              </div>
            </>
          ) : (
            <div className="border rounded-xl p-3 bg-white shadow-sm text-sm text-gray-600">
              You don’t have permission to edit permissions at {selectedOrg}.
            </div>
          )}
        </div>

        {/* List */}
        <div className="border rounded-xl p-3 bg-white shadow-sm">
          <h3 className="font-medium mb-2">Permissions matching selection</h3>
          <table className="w-full text-sm border rounded-lg overflow-hidden">
            <thead className="bg-emerald-50/70">
              <tr>
                <th className="p-2 text-left">Position</th>
                <th className="p-2 text-left">Org Prefix</th>
                <th className="p-2 text-left">Scope</th>
                <th className="p-2 text-left">Effect</th>
                <th className="p-2 text-left">Actions</th>
                <th className="p-2 text-left">Enabled</th>
                <th className="p-2 text-left">Created</th>
                <th className="p-2"></th>
              </tr>
            </thead>
            <tbody>
              {selectedPolicies.length ? (
                selectedPolicies.map((p) => (
                  <tr key={(p._id ?? "") + p.position_key + p.where.org_prefix + p.scope} className="border-t hover:bg-emerald-50/40">
                    <td className="p-2">{p.position_key}</td>
                    <td className="p-2">{p.where.org_prefix}</td>
                    <td className="p-2">{p.scope}</td>
                    <td className="p-2">{p.effect}</td>
                    <td className="p-2">
                      <div className="flex flex-wrap gap-1">
                        {p.actions.map((a) => (
                          <span key={a} className="px-2 py-0.5 rounded-full text-xs bg-emerald-100 text-emerald-800 ring-1 ring-emerald-200">{a}</span>
                        ))}
                      </div>
                    </td>
                    <td className="p-2">{p.enabled ? "yes" : "no"}</td>
                    <td className="p-2">{p.created_at ? new Date(p.created_at).toLocaleString() : "—"}</td>
                    <td className="p-2">
                      <button
                        className="text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-700 hover:bg-red-100 shadow-sm disabled:opacity-50"
                        onClick={() => onDelete(p)}
                        disabled={!canEdit}
                        title={!canEdit ? "No permission" : "Delete permission"}
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))
              ) : (
                <tr><td colSpan={8} className="p-3 text-gray-500">No policies for this selection</td></tr>
              )}
            </tbody>
          </table>
          {!canEdit && <div className="text-xs text-orange-600 mt-2">Editing disabled by permissions at {selectedOrg}</div>}
        </div>

        {/* positions inspector removed */}
      </div>
    </div>
  );
};

export default OrgPoliciesPage;

// Inline create position form
const CreatePositionInline: React.FC<{ selectedOrg: string; canCreate: boolean }> = ({ selectedOrg, canCreate }) => {
  const [key, setKey] = useState("");
  const [label, setLabel] = useState("");
  const [saving, setSaving] = useState(false);
  const create = async () => {
    if (!key.trim()) return;
    if (!canCreate) { alert(`You don't have permission at ${selectedOrg}.`); return; }
    try {
      setSaving(true);
      await apiFetch(`/positions`, {
        method: 'POST',
        body: JSON.stringify({ key: key.trim(), display: { en: label.trim() || key.trim() }, scope: { org_path: selectedOrg, inherit: true }, status: 'active' })
      });
      setKey(""); setLabel("");
      alert('Position created');
    } catch (e: any) {
      alert(e?.message || 'Failed to create position');
    } finally { setSaving(false); }
  };
  return (
    <div className="flex items-center gap-2">
      <input className="border rounded px-2 py-1 text-sm" placeholder="position key (e.g., head)" value={key} onChange={e => setKey(e.target.value)} />
      <input className="border rounded px-2 py-1 text-sm" placeholder="label (optional)" value={label} onChange={e => setLabel(e.target.value)} />
      <button onClick={create} disabled={!canCreate || saving} title={canCreate ? 'Create position' : `You don't have permission at ${selectedOrg}.`} className={`px-2 py-1 text-xs border rounded ${!canCreate ? 'opacity-50 cursor-not-allowed' : ''}`}>Create</button>
    </div>
  );
};
