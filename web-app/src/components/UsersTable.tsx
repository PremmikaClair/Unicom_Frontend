import React, { useEffect, useMemo, useState } from "react";
import type { User, Permission } from "../types";
import {
  getUsersPaged,
  getUserPermissions,
  updateUser,
  getRoles,
} from "../services/api";
import PermissionModal from "./PermissionModal";

type RoleDict = { name: string; label: string; permissions: string[] };

const PlusIcon: React.FC<{ className?: string }> = ({ className }) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    className={className ?? "w-4 h-4"}
  >
    <path strokeWidth="2" strokeLinecap="round" d="M12 5v14M5 12h14" />
  </svg>
);

const UsersTable = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [nextCursor, setNextCursor] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [selectedPermissions, setSelectedPermissions] = useState<Permission[]>([]);
  const [showModal, setShowModal] = useState(false);

  const [expandedUserId, setExpandedUserId] = useState<number | null>(null);
  const [editing, setEditing] = useState(false);
  const [editableUser, setEditableUser] = useState<User>({} as User);

  const [roles, setRoles] = useState<RoleDict[]>([]);
  const roleNames = useMemo(() => roles.map((r) => r.name), [roles]);

  // --- Boot data
  useEffect(() => {
    const boot = async () => {
      try {
        setLoading(true);
        const [{ items, nextCursor }, rolesDict] = await Promise.all([
          getUsersPaged({ limit: 20 }),
          getRoles(),
        ]);
        const map = new Map<number, User>();
        for (const u of items) map.set(u.id, u);
        setUsers(Array.from(map.values()).sort((a, b) => a.id - b.id));
        setNextCursor(nextCursor);
        setRoles(rolesDict);
      } catch (e: any) {
        console.error(e);
        setError(e?.message ?? "Failed to load users");
      } finally {
        setLoading(false);
      }
    };
    boot();
  }, []);

  // --- Load more
  const loadMore = async () => {
    if (!nextCursor) return;
    try {
      setLoadingMore(true);
      const { items, nextCursor: nc } = await getUsersPaged({
        limit: 20,
        cursor: nextCursor,
      });
      setUsers((prev) => {
        const map = new Map<number, User>();
        for (const u of prev) map.set(u.id, u);
        for (const u of items) map.set(u.id, u);
        return Array.from(map.values()).sort((a, b) => a.id - b.id);
      });
      setNextCursor(nc);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to load more");
    } finally {
      setLoadingMore(false);
    }
  };

  // --- View permissions
  const handleView = async (userId: number) => {
    try {
      const perms = await getUserPermissions(userId);
      setSelectedPermissions(perms ?? []);
      setShowModal(true);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to load permissions");
    }
  };

  // --- Expand user info
  const handleToggleInfo = (user: User) => {
    if (expandedUserId === user.id) {
      setExpandedUserId(null);
      setEditing(false);
    } else {
      setExpandedUserId(user.id);
      setEditableUser({ ...user, roles: user.roles ?? [] });
      setEditing(false);
    }
  };

  // --- Save edits
  const handleSave = async () => {
    try {
      setLoading(true);
      const updated = await updateUser(editableUser.id, {
        firstName: editableUser.firstName,
        lastName: editableUser.lastName,
        email: editableUser.email,
        roles: editableUser.roles ?? [],
      });
      setUsers((prev) =>
        prev.map((u) => (u.id === updated.id ? updated : u))
      );
      setEditing(false);
    } catch (e: any) {
      console.error(e);
      setError(e?.message ?? "Failed to update user");
    } finally {
      setLoading(false);
    }
  };

  // --- Toggle role in editor
  const toggleRole = (roleName: string) => {
    setEditableUser((prev) => {
      const current = prev.roles ?? [];
      const has = current.includes(roleName);
      const roles = has
        ? current.filter((r) => r !== roleName)
        : [...current, roleName];
      return { ...prev, roles };
    });
  };

  // --- Add role to system
  const handleAddRole = async () => {
    const name = prompt("New role name?")?.trim();
    if (!name) return;
    const newRole: RoleDict = { name, label: name, permissions: [] };
    setRoles((prev) =>
      prev.some((r) => r.name.toLowerCase() === name.toLowerCase())
        ? prev
        : [...prev, newRole]
    );
    if (editing && editableUser?.id != null) toggleRole(name);
  };

  // --- UI
  if (loading && users.length === 0)
    return <div className="p-4 text-gray-600">Loading users…</div>;
  if (error && users.length === 0)
    return <div className="p-4 text-red-600">{error}</div>;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-800">User Management</h1>
        {error && <span className="text-sm text-red-600">{error}</span>}
      </div>

      <table className="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
        <thead>
          <tr className="bg-gray-100 text-left text-sm font-semibold text-gray-600">
            <th className="p-3">ID</th>
            <th className="p-3">First Name</th>
            <th className="p-3">Last Name</th>
            <th className="p-3">Email</th>
            <th className="p-3">Roles</th>
            <th className="p-3">Permissions</th>
            <th className="p-3">More</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <React.Fragment key={user.id}>
              <tr className="text-sm text-gray-700 hover:bg-gray-50">
                <td className="p-3">{user.id}</td>
                <td className="p-3">{user.firstName}</td>
                <td className="p-3">{user.lastName}</td>
                <td className="p-3">{user.email}</td>
                <td className="p-3">{(user.roles ?? []).join(", ")}</td>
                <td className="p-3">
                  <button
                    onClick={() => handleView(user.id)}
                    className="text-blue-600 hover:underline"
                  >
                    View
                  </button>
                </td>
                <td className="p-3">
                  <button
                    onClick={() => handleToggleInfo(user)}
                    className="text-gray-500 hover:text-gray-800"
                    title="Expand"
                  >
                    &#x22EE;
                  </button>
                </td>
              </tr>

              {expandedUserId === user.id && (
                <tr>
                  <td colSpan={7} className="p-3 bg-gray-50">
                    {!editing ? (
                      <div className="space-y-2">
                        <p>
                          <strong>ID:</strong> {user.id}
                        </p>
                        <p>
                          <strong>Name:</strong> {user.firstName}{" "}
                          {user.lastName}
                        </p>
                        <p>
                          <strong>Email:</strong> {user.email}
                        </p>
                        <p className="flex items-center gap-2 flex-wrap">
                          <strong>Roles:</strong>
                          {(user.roles ?? []).map((role) => (
                            <span
                              key={`${user.id}-${role}`}
                              className="inline-block bg-blue-100 text-blue-700 text-xs px-2 py-0.5 rounded"
                            >
                              {role}
                            </span>
                          ))}
                        </p>
                        <div className="flex gap-2 mt-2">
                          <button
                            onClick={() => setEditing(true)}
                            className="text-blue-600 hover:underline text-sm"
                          >
                            Edit
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div>
                          <label className="block text-sm font-medium">
                            First Name
                          </label>
                          <input
                            type="text"
                            value={editableUser.firstName}
                            onChange={(e) =>
                              setEditableUser((p) => ({
                                ...p,
                                firstName: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium">
                            Last Name
                          </label>
                          <input
                            type="text"
                            value={editableUser.lastName}
                            onChange={(e) =>
                              setEditableUser((p) => ({
                                ...p,
                                lastName: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>
                        <div className="md:col-span-2">
                          <label className="block text-sm font-medium">
                            Email
                          </label>
                          <input
                            type="email"
                            value={editableUser.email}
                            onChange={(e) =>
                              setEditableUser((p) => ({
                                ...p,
                                email: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>

                        {/* Roles editor */}
                        <div className="md:col-span-2">
                          <div className="flex items-center justify-between mb-1">
                            <label className="block text-sm font-medium">
                              Roles
                            </label>
                            <button
                              type="button"
                              onClick={handleAddRole}
                              className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded border border-gray-300 hover:bg-gray-100 text-gray-700"
                              title="Add role"
                            >
                              <PlusIcon />
                              Add role
                            </button>
                          </div>

                          <div className="flex flex-wrap gap-2">
                            {roleNames.map((r) => {
                              const checked = (editableUser.roles ?? []).includes(
                                r
                              );
                              return (
                                <label
                                  key={`role-opt-${r}`}
                                  className={`cursor-pointer text-xs px-2 py-1 rounded border ${
                                    checked
                                      ? "bg-blue-100 border-blue-300 text-blue-700"
                                      : "bg-white"
                                  }`}
                                >
                                  <input
                                    type="checkbox"
                                    className="mr-1 align-middle"
                                    checked={checked}
                                    onChange={() => toggleRole(r)}
                                  />
                                  {r}
                                </label>
                              );
                            })}
                          </div>
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
                              const original = users.find(
                                (u) => u.id === editableUser.id
                              );
                              if (original)
                                setEditableUser({
                                  ...original,
                                  roles: original.roles ?? [],
                                });
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
          ))}
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