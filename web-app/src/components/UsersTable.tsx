// src/components/UsersTable.tsx
import React, { useEffect, useState } from "react";
import type { User, Membership, Position } from "../types";
import {
  getUsersPaged,
  getUserPermissions,
  updateUser,
  createUser,
  deleteUser,
  getPositions,
  getMembershipsRaw,
} from "../services/api";
import PermissionModal from "./PermissionModal";

const PlusIcon: React.FC<{ className?: string }> = ({ className }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" className={className ?? "w-4 h-4"}>
    <path strokeWidth="2" strokeLinecap="round" d="M12 5v14M5 12h14" />
  </svg>
);

// Pretty label helper (e.g., "Head • COM • ENG")
function membershipLabel(m: Membership, positions: Position[]) {
  const pos = positions.find((p) => p.key === m.position_key);
  const role =
    (pos?.display && (pos.display.en || Object.values(pos.display)[0])) ||
    pos?.key ||
    m.position_key;
  const orgBits = m.org_path.split("/").filter(Boolean).reverse();
  return [role, ...orgBits].join(" • ");
}

const UsersTable: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [nextCursor, setNextCursor] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [selectedPermissions, setSelectedPermissions] = useState<string[]>([]);
  const [showModal, setShowModal] = useState(false);

  const [expandedUserKey, setExpandedUserKey] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [editableUser, setEditableUser] = useState<User>({} as User);

  const [positions, setPositions] = useState<Position[]>([]);

  // Derive a stable string key (but operate on numeric id for API)
// 1) replace the helper
const getKey = (u: User) => (u._id ?? u.email ?? String(u.id));

// 2) after you set users from first page, pull memberships:
useEffect(() => {
  (async () => {
    try {
      setLoading(true);
      const [{ items, nextCursor }, pos] = await Promise.all([
        getUsersPaged({ limit: 20 }),
        getPositions().catch(() => [] as Position[]),
      ]);

      // no dedup — or use getKey(u) if you want
      const base = items.slice();
      setUsers(base);
      setNextCursor(nextCursor);
      setPositions(pos);

      // fetch memberships per user (MVP, N+1)
      const withStudentId = base.filter(u => !!u.student_id);
      const results = await Promise.allSettled(
        withStudentId.map(async (u) => {
          const res = await getMembershipsRaw(u.student_id!);
          return { key: getKey(u), memberships: res.memberships || [] };
        })
      );

      // merge memberships into users
      setUsers(prev => {
        const map = new Map(prev.map(u => [getKey(u), { ...u }]));
        for (const r of results) {
          if (r.status === "fulfilled") {
            const { key, memberships } = r.value;
            const ex = map.get(key);
            if (ex) map.set(key, { ...ex, memberships });
          }
        }
        return Array.from(map.values());
      });

    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to load users");
    } finally {
      setLoading(false);
    }
  })();
}, []);
  // ----- Load more
  const loadMore = async () => {
    if (!nextCursor) return;
    try {
      setLoadingMore(true);
      const { items, nextCursor: nc } = await getUsersPaged({ limit: 20, cursor: nextCursor });
      setUsers((prev) => {
        const map = new Map<string, User>();
        for (const u of prev) map.set(getKey(u), u);
        for (const u of items) map.set(getKey(u), u);
        return Array.from(map.values()).sort((a, b) =>
          (a.lastName || a.firstName || a.email).localeCompare(
            b.lastName || b.firstName || b.email
          )
        );
      });
      setNextCursor(nc);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to load more");
    } finally {
      setLoadingMore(false);
    }
  };

  // ----- Permissions modal
  const handleViewPermissions = async (user: User) => {
    try {
      if (typeof user.id !== "number") {
        throw new Error("User missing numeric id");
      }
      const perms = await getUserPermissions(user.id);
      setSelectedPermissions(perms ?? []);
      setShowModal(true);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to load permissions");
    }
  };

  // ----- Row expand / edit
  const handleToggleInfo = (user: User) => {
    const key = getKey(user);
    if (expandedUserKey === key) {
      setExpandedUserKey(null);
      setEditing(false);
    } else {
      setExpandedUserKey(key);
      setEditableUser({
        ...user,
        memberships: user.memberships ?? [],
      });
      setEditing(false);
    }
  };

  // ----- Save (basic fields only; memberships require dedicated APIs)
  const handleSave = async () => {
    try {
      if (typeof editableUser.id !== "number") {
        throw new Error("User missing numeric id");
      }
      setLoading(true);
      const updated = await updateUser(editableUser.id, {
        firstName: editableUser.firstName,
        lastName: editableUser.lastName,
        email: editableUser.email,
        student_id: editableUser.student_id,
        // NOTE: backend UpdateUser currently doesn't apply memberships — keep display-only here.
      });
      setUsers((prev) => prev.map((u) => (getKey(u) === getKey(updated) ? updated : u)));
      setEditing(false);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to update user");
    } finally {
      setLoading(false);
    }
  };

  // ----- Create (backend requires numeric SeqID `id`)
  const onCreate = async () => {
    try {
      const idRaw = prompt("Numeric ID (SeqID)?");
      if (!idRaw) return;
      const id = Number(idRaw);
      if (!Number.isFinite(id)) {
        alert("Invalid numeric id");
        return;
      }
      const email = prompt("Email?"); if (!email) return;
      const firstName = prompt("First name?") || "";
      const lastName = prompt("Last name?") || "";
      const student_id = prompt("Student ID?") || "";
      const created = await createUser({
        id,
        email,
        firstName,
        lastName,
        student_id,
        status: "active",
      } as Partial<User>);
      setUsers((prev) => [...prev, created].sort((a, b) => getKey(a).localeCompare(getKey(b))));
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to create user");
    }
  };

  // ----- Delete
  const onDelete = async (u: User) => {
    if (!confirm(`Delete ${u.email}?`)) return;
    try {
      if (typeof u.id !== "number") {
        throw new Error("User missing numeric id");
      }
      await deleteUser(u.id);
      setUsers((prev) => prev.filter((x) => getKey(x) !== getKey(u)));
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to delete user");
    }
  };

  // ----- Membership editor (inline UI only for now)
  const MembershipEditor: React.FC<{
    value: Membership[]; onChange: (v: Membership[]) => void;
  }> = ({ value, onChange }) => {
    const [orgPath, setOrgPath] = useState("");
    const [positionKey, setPositionKey] = useState("");

    const add = () => {
      const org_path = orgPath.trim();
      const position_key = positionKey.trim();
      if (!org_path || !position_key) return;
      onChange([...(value || []), { org_path, position_key }]);
      setOrgPath(""); setPositionKey("");
    };
    const remove = (i: number) => onChange(value.filter((_, idx) => idx !== i));

    return (
      <div className="space-y-2">
        <div className="flex gap-2">
          <input
            className="border rounded p-1 text-sm flex-1"
            placeholder="/club/cpsk"
            value={orgPath}
            onChange={(e) => setOrgPath(e.target.value)}
          />
          <input
            className="border rounded p-1 text-sm w-40"
            placeholder="head"
            value={positionKey}
            onChange={(e) => setPositionKey(e.target.value)}
            list="position-keys"
          />
          <datalist id="position-keys">
            {positions.map((p) => (
              <option key={p.key} value={p.key}>
                {(p.display && (p.display.en || Object.values(p.display)[0])) || p.key}
              </option>
            ))}
          </datalist>
          <button
            type="button"
            onClick={add}
            className="px-2 py-1 text-xs border rounded flex items-center gap-1"
            title="Add membership"
          >
            <PlusIcon /> Add
          </button>
        </div>
        <div className="flex flex-wrap gap-2">
          {value.map((m, i) => (
            <span key={i} className="inline-flex items-center gap-2 bg-gray-100 text-xs px-2 py-1 rounded">
              {membershipLabel(m, positions)}
              <button onClick={() => remove(i)} className="text-red-600" title="Remove">×</button>
            </span>
          ))}
        </div>
        <div className="text-[11px] text-gray-500">
          Note: This editor is UI-only here. Persisting memberships requires dedicated APIs.
        </div>
      </div>
    );
  };

  // ----- UI
  if (loading && users.length === 0) return <div className="p-4 text-gray-600">Loading users…</div>;
  if (error && users.length === 0) return <div className="p-4 text-red-600">{error}</div>;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-800">User Management</h1>
        <div className="flex items-center gap-3">
          {error && <span className="text-sm text-red-600">{error}</span>}
          <button
            onClick={onCreate}
            className="px-3 py-1 bg-gray-800 text-white rounded text-sm inline-flex items-center gap-1"
          >
            <PlusIcon /> New User
          </button>
        </div>
      </div>

      <table className="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
        <thead>
          <tr className="bg-gray-100 text-left text-sm font-semibold text-gray-600">
            <th className="p-3">Student ID</th>
            <th className="p-3">Name</th>
            <th className="p-3">Email</th>
            <th className="p-3">Memberships</th>
            <th className="p-3">Permissions</th>
            <th className="p-3">Actions</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => {
            const key = getKey(user);
            return (
              <React.Fragment key={key}>
                <tr className="text-sm text-gray-700 hover:bg-gray-50">
                  <td className="p-3">{user.student_id ?? "-"}</td>
                  <td className="p-3">{user.firstName} {user.lastName}</td>
                  <td className="p-3">{user.email}</td>
                  <td className="p-3">
                    <div className="flex flex-wrap gap-1">
                      {(user.memberships ?? []).map((m, i) => (
                        <span
                          key={`${key}-m-${i}`}
                          className="inline-block bg-blue-100 text-blue-700 text-xs px-2 py-0.5 rounded"
                        >
                          {membershipLabel(m, positions)}
                        </span>
                      ))}
                      {(user.memberships ?? []).length === 0 && (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </div>
                  </td>
                  <td className="p-3">
                    <button
                      onClick={() => handleViewPermissions(user)}
                      className="text-blue-600 hover:underline"
                    >
                      View
                    </button>
                  </td>
                  <td className="p-3">
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleToggleInfo(user)}
                        className="text-gray-600 hover:underline"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => onDelete(user)}
                        className="text-red-600 hover:underline"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>

                {expandedUserKey === key && (
                  <tr>
                    <td colSpan={6} className="p-3 bg-gray-50">
                      {!editing ? (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div><strong>ID:</strong> {user.id ?? user._id}</div>
                          <div><strong>Email:</strong> {user.email}</div>
                          <div><strong>Name:</strong> {user.firstName} {user.lastName}</div>
                          <div><strong>Student ID:</strong> {user.student_id ?? "-"}</div>
                          <div className="md:col-span-2 flex gap-2 mt-1">
                            <button onClick={() => setEditing(true)} className="text-blue-600 hover:underline text-sm">
                              Edit
                            </button>
                          </div>
                        </div>
                      ) : (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div>
                            <label className="block text-sm font-medium">First Name</label>
                            <input
                              type="text"
                              value={editableUser.firstName}
                              onChange={(e) => setEditableUser({ ...editableUser, firstName: e.target.value })}
                              className="border rounded p-1 w-full text-sm"
                            />
                          </div>
                          <div>
                            <label className="block text-sm font-medium">Last Name</label>
                            <input
                              type="text"
                              value={editableUser.lastName}
                              onChange={(e) => setEditableUser({ ...editableUser, lastName: e.target.value })}
                              className="border rounded p-1 w-full text-sm"
                            />
                          </div>
                          <div className="md:col-span-2">
                            <label className="block text-sm font-medium">Email</label>
                            <input
                              type="email"
                              value={editableUser.email}
                              onChange={(e) => setEditableUser({ ...editableUser, email: e.target.value })}
                              className="border rounded p-1 w-full text-sm"
                            />
                          </div>
                          <div>
                            <label className="block text-sm font-medium">Student ID</label>
                            <input
                              type="text"
                              value={editableUser.student_id || ""}
                              onChange={(e) => setEditableUser({ ...editableUser, student_id: e.target.value })}
                              className="border rounded p-1 w-full text-sm"
                            />
                          </div>

                          {/* Memberships (UI only for now) */}
                          <div className="md:col-span-2">
                            <label className="block text-sm font-medium mb-1">Memberships</label>
                            <MembershipEditor
                              value={editableUser.memberships ?? []}
                              onChange={(v) => setEditableUser({ ...editableUser, memberships: v })}
                            />
                          </div>

                          <div className="md:col-span-2 flex gap-2 mt-2">
                            <button
                              onClick={handleSave}
                              className="px-3 py-1 bg-green-500 text-white rounded text-sm"
                              disabled={loading}
                            >
                              Save
                            </button>
                            <button
                              onClick={() => {
                                setEditing(false);
                                const original = users.find((u) => getKey(u) === getKey(editableUser));
                                if (original) setEditableUser({ ...original, memberships: original.memberships ?? [] });
                              }}
                              className="px-3 py-1 bg-gray-300 rounded text-sm"
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      )}
                    </td>
                  </tr>
                )}
              </React.Fragment>
            );
          })}
        </tbody>
      </table>

      <div className="flex items-center gap-3">
        {nextCursor && (
          <button
            onClick={loadMore}
            disabled={loadingMore}
            className="px-3 py-1 bg-gray-800 text-white rounded text-sm"
          >
            {loadingMore ? "Loading…" : "Load more"}
          </button>
        )}
        {loading && <span className="text-sm text-gray-500">Working…</span>}
      </div>

      <PermissionModal
        visible={showModal}
        onClose={() => setShowModal(false)}
        permissions={selectedPermissions}
      />
    </div>
  );
};

export default UsersTable;