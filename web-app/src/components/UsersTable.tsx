// src/components/UsersTable.tsx
import React, { useEffect, useState } from "react";
import type { User, Membership, Position } from "../types";
import useAbilities from "../hooks/useAbilities";
import RoleCard from "./RoleCard";
import {
  getUsersPaged,
  updateUser,
  createUser,
  deleteUser,
  getPositions,
  getMembershipsRaw,
  createMembership,
  deactivateMembership,
} from "../services/api";

const PlusIcon: React.FC<{ className?: string }> = ({ className }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" className={className ?? "w-4 h-4"}>
    <path strokeWidth="2" strokeLinecap="round" d="M12 5v14M5 12h14" />
  </svg>
);


function sortMemberships(mems: Membership[]): Membership[] {
  const pri = (m: Membership) => (m.org_path?.startsWith("/fac") ? 0 : m.org_path?.startsWith("/club") ? 1 : 2);
  return (mems || []).slice().sort((a, b) => pri(a) - pri(b));
}

const UsersTable: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [nextCursor, setNextCursor] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // permissions UI removed

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

      // If memberships already included from backend, skip N+1 fetch.
      const hasIncluded = base.some(u => Array.isArray(u.memberships) && u.memberships.length > 0);
      if (!hasIncluded) {
        const withStudentId = base.filter(u => !!u.student_id);
        const results = await Promise.allSettled(
          withStudentId.map(async (u) => {
            const res = await getMembershipsRaw(u.student_id!);
            return { key: getKey(u), memberships: res.memberships || [] };
          })
        );
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
      }

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
      if (!Number.isFinite(editableUser.id) || (editableUser.id as any) <= 0) {
        throw new Error("User missing numeric id (cannot update)");
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
    console.log(`on delete click: ${u.email}`)
    if (!confirm(`Delete ${u.email}?`)) return;
    try {
      // if (typeof u._id !== "number") {
      //   throw new Error("User missing numeric id");
      // }
      await deleteUser(u._id);
      setUsers((prev) => prev.filter((x) => getKey(x) !== getKey(u)));
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to delete user");
    }
  };

  // Membership management moved to Roles page; keep tags view-only here.

  // ----- UI
  if (loading && users.length === 0) return <div className="p-4 text-gray-600">Loading users…</div>;
  if (error && users.length === 0) return <div className="p-4 text-red-600">{error}</div>;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
          👤 User Management
          <span className="text-xs font-normal text-gray-500">cute mode</span>
        </h1>
        <div className="flex items-center gap-3">
          {error && <span className="text-sm text-red-600">{error}</span>}
          <button
            onClick={onCreate}
            className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full text-sm inline-flex items-center gap-1 shadow-sm"
          >
            <PlusIcon /> New User
          </button>
        </div>
      </div>

      <table className="min-w-full bg-white border border-gray-200 rounded-2xl shadow-sm overflow-hidden">
        <thead>
          <tr className="bg-gray-50/80 text-left text-sm font-semibold text-gray-600">
            <th className="p-3">Student ID</th>
            <th className="p-3">Name</th>
            <th className="p-3">Email</th>
            <th className="p-3">Memberships</th>
            <th className="p-3">Actions</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {users.map((user) => {
            const key = getKey(user);
            return (
              <React.Fragment key={key}>
                <tr className="text-sm text-gray-800 hover:bg-gray-50">
                  <td className="p-3">{user.student_id ?? "-"}</td>
                  <td className="p-3">{user.firstName} {user.lastName}</td>
                  <td className="p-3">{user.email}</td>
                  <td className="p-3">
                    <div className="flex flex-wrap gap-1.5">
                      {sortMemberships(user.memberships ?? []).map((m, i) => (
                        <RoleCard key={`${key}-m-${i}`} membership={m} positions={positions} />
                      ))}
                      {(user.memberships ?? []).length === 0 && (
                        <span className="text-xs text-gray-400">—</span>
                      )}
                    </div>
                  </td>
                  {/* Permissions column removed */}
                  <td className="p-3">
                    <div className="flex gap-3">
                      <button
                        onClick={() => handleToggleInfo(user)}
                        className="text-xs px-3 py-1 rounded-full bg-gray-100 hover:bg-gray-200 text-gray-700 shadow-sm"
                      >
                        Edit
                      </button>
                      <button
                        onClick={() => onDelete(user)}
                        className="text-xs px-3 py-1 rounded-full bg-red-50 hover:bg-red-100 text-red-700 shadow-sm"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>

                {expandedUserKey === key && (
                  <tr>
                    <td colSpan={5} className="p-3 bg-gray-50">
                      {!editing ? (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                          <div><strong>ID:</strong> {user.id ?? user._id}</div>
                          <div><strong>Email:</strong> {user.email}</div>
                          <div><strong>Name:</strong> {user.firstName} {user.lastName}</div>
                          <div><strong>Student ID:</strong> {user.student_id ?? "-"}</div>
                          <div className="md:col-span-2 flex gap-2 mt-1">
                            <button onClick={() => setEditing(true)} className="text-xs px-3 py-1 rounded-full bg-blue-50 hover:bg-blue-100 text-blue-700 shadow-sm">
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

                          <div className="md:col-span-2">
                            <label className="block text-sm font-medium mb-1">Memberships</label>
                            <div className="text-sm text-gray-600">View-only here. Manage assignments in Roles page.</div>
                            <div className="flex flex-wrap gap-1.5 mt-1">
                              {sortMemberships((editableUser.memberships ?? []).filter(m => m.active)).map((m, i) => (
                                <RoleCard key={i} membership={m} positions={positions} />
                              ))}
                              {(editableUser.memberships ?? []).filter(m => m.active).length === 0 && (
                                <span className="text-xs text-gray-400">—</span>
                              )}
                            </div>
                          </div>

                          <div className="md:col-span-2 flex gap-2 mt-2">
                            <button onClick={handleSave} className="px-3 py-1.5 bg-emerald-500 hover:bg-emerald-600 text-white rounded-full text-sm shadow-sm" disabled={loading}>Save</button>
                            <button onClick={() => { setEditing(false); const original = users.find((u) => getKey(u) === getKey(editableUser)); if (original) setEditableUser({ ...original, memberships: original.memberships ?? [] }); }} className="px-3 py-1.5 bg-gray-200 hover:bg-gray-300 rounded-full text-sm">Cancel</button>
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

      {/* Permissions modal removed */}
    </div>
  );
};

export default UsersTable;
