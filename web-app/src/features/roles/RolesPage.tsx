import React, { useEffect, useMemo, useState } from "react";
import type { OrgUnitNode, Policy } from "../../types";
import { getOrgTree, listPolicies, createPolicy, upsertPolicy, deletePolicy } from "../../services/api";

// MVP action catalog
const ALL_ACTIONS = [
  // Posts
  "post:read",
  "post:create",
  "post:edit:own",
  "post:delete:own",
  "post:moderate",
  "post:pin",
  // Events
  "event:create",
  "event:edit:own",
  "event:delete:own",
];

const ScopeOptions = [
  { value: "exact", label: "Exact node only" },
  { value: "subtree", label: "Node + descendants" },
];

const EffectOptions = [{ value: "allow", label: "Allow" }]; // deny reserved for future

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
        className={`text-left px-2 py-0.5 rounded w-full ${
          isSelected ? "bg-blue-100" : "hover:bg-gray-100"
        }`}
        onClick={() => onSelect(node.org_path)}
        title={node.org_path}
      >
        {label} <span className="text-xs text-gray-500">({node.org_path})</span>
      </button>
      {node.children?.length ? (
        <div className="ml-3 border-l pl-2">
          {node.children.map((ch) => (
            <TreeNode key={ch.org_path} node={ch} selected={selected} onSelect={onSelect} />
          ))}
        </div>
      ) : null}
    </div>
  );
};

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
        <label className="block text-sm font-medium">Position key</label>
        <input
          className="border rounded px-2 py-1 w-full"
          placeholder="head | member | student"
          value={positionKey}
          onChange={(e) => setPositionKey(e.target.value)}
        />
      </div>

      <div>
        <label className="block text-sm font-medium">Org prefix</label>
        <input
          className="border rounded px-2 py-1 w-full"
          placeholder="/faculty/ or /club/"
          value={orgPrefix}
          onChange={(e) => setOrgPrefix(e.target.value)}
        />
        <p className="text-xs text-gray-500">Policies attach to memberships whose org_path starts with this prefix.</p>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="block text-sm font-medium">Scope</label>
          <select className="border rounded px-2 py-1 w-full" value={scope} onChange={(e) => setScope(e.target.value as any)}>
            {ScopeOptions.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium">Effect</label>
          <select className="border rounded px-2 py-1 w-full" value={effect} onChange={(e) => setEffect(e.target.value as any)}>
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

  const onCreate = async (p: Policy) => {
    const saved = await createPolicy(p);
    setPolicies((prev) => [saved, ...prev]);
    alert("Policy created");
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
  };

  const onDelete = async (p: Policy) => {
    if (!confirm(`Delete policy for ${p.position_key} at ${p.where.org_prefix}?`)) return;
    await deletePolicy(p.where.org_prefix, p.position_key);
    setPolicies((prev) => prev.filter((x) => !(x.position_key === p.position_key && x.where.org_prefix === p.where.org_prefix)));
  };

  // Later: derive canEdit from abilities (e.g., abilities["role:create_child"] at selectedOrg)
  const canEdit = true; // MVP: allow editing; flip to ability check later

  const selectedPolicies = useMemo(
    () => policies.filter((p) => selectedOrg.startsWith(p.where.org_prefix)),
    [policies, selectedOrg]
  );

  return (
    <div className="p-4 grid grid-cols-1 md:grid-cols-3 gap-4">
      {/* Left: Org tree */}
      <div className="md:col-span-1 border rounded p-3">
        <div className="flex items-center justify-between mb-2">
          <h2 className="font-semibold">Organization</h2>
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
      <div className="md:col-span-2 border rounded p-3 space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold">Policies</h2>
          {loadingPolicies && <span className="text-xs text-gray-500">Loading…</span>}
        </div>

        {/* Create / Upsert */}
        <div className="grid md:grid-cols-2 gap-6">
          <div className="border rounded p-3">
            <h3 className="font-medium mb-2">Create Policy</h3>
            <PolicyForm
              selectedOrg={selectedOrg}
              onSubmit={onCreate}
              mode="create"
            />
          </div>
          <div className="border rounded p-3">
            <h3 className="font-medium mb-2">Upsert Policy (by position_key + org_prefix + scope)</h3>
            <PolicyForm
              selectedOrg={selectedOrg}
              onSubmit={onUpsert}
              mode="upsert"
            />
          </div>
        </div>

        {/* List */}
        <div className="border rounded p-3">
          <h3 className="font-medium mb-2">Policies matching selection</h3>
          <table className="w-full text-sm border">
            <thead className="bg-gray-100">
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
                  <tr key={(p._id ?? "") + p.position_key + p.where.org_prefix + p.scope} className="border-t">
                    <td className="p-2">{p.position_key}</td>
                    <td className="p-2">{p.where.org_prefix}</td>
                    <td className="p-2">{p.scope}</td>
                    <td className="p-2">{p.effect}</td>
                    <td className="p-2">
                      <div className="flex flex-wrap gap-1">
                        {p.actions.map((a) => (
                          <span key={a} className="px-2 py-0.5 bg-gray-100 rounded">{a}</span>
                        ))}
                      </div>
                    </td>
                    <td className="p-2">{p.enabled ? "yes" : "no"}</td>
                    <td className="p-2">{p.created_at ? new Date(p.created_at).toLocaleString() : "—"}</td>
                    <td className="p-2">
                      <button
                        className="text-red-600 hover:underline disabled:opacity-50"
                        onClick={() => onDelete(p)}
                        disabled={!canEdit}
                        title={!canEdit ? "No permission" : "Delete policy"}
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
          {!canEdit && <div className="text-xs text-orange-600 mt-2">Editing disabled (future: enable per-subtree based on abilities)</div>}
        </div>
      </div>
    </div>
  );
};

export default OrgPoliciesPage;