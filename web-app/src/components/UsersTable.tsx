import { useEffect, useState } from "react";
import type { User, Permission } from "../types";
import { getUsers, getUserPermissions } from "../api";
import PermissionModal from "./PermissionModal";

const UsersTable = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [selectedPermissions, setSelectedPermissions] = useState<Permission[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [expandedUserId, setExpandedUserId] = useState<number | null>(null);
  const [editing, setEditing] = useState(false);
  const [editableUser, setEditableUser] = useState<User>({} as User);

  useEffect(() => {
    getUsers().then(setUsers).catch(console.error);
  }, []);

  const handleView = async (userId: number) => {
    const perms = await getUserPermissions(userId);
    setSelectedPermissions(perms);
    setShowModal(true);
  };

  const handleToggleInfo = (user: User) => {
    if (expandedUserId === user.id) {
      setExpandedUserId(null);
      setEditing(false);
    } else {
      setExpandedUserId(user.id);
      setEditableUser(user);
      setEditing(false);
    }
  };

  const handleSave = () => {
    setUsers((prev) =>
      prev.map((u) => (u.id === editableUser.id ? editableUser : u))
    );
    setEditing(false);
  };

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold text-gray-800">User Management</h1>
      <table className="min-w-full bg-white border border-gray-200 rounded-lg shadow-sm">
        <thead>
          <tr className="bg-gray-100 text-left text-sm font-semibold text-gray-600">
            <th className="p-3">ID</th>
            <th className="p-3">First Name</th>
            <th className="p-3">Last Name</th>
            <th className="p-3">Email</th>
            <th className="p-3">Roles</th>
            <th className="p-3">Permissions</th>
            <th className="p-3">More Info</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <>
              <tr key={user.id} className="text-sm text-gray-700 hover:bg-gray-50">
                <td className="p-3">{user.id}</td>
                <td className="p-3">{user.firstName}</td>
                <td className="p-3">{user.lastName}</td>
                <td className="p-3">{user.email}</td>
                <td className="p-3">{user.roles.join(", ")}</td>
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
                        <p><strong>ID:</strong> {user.id}</p>
                        <p><strong>Name:</strong> {user.firstName} {user.lastName}</p>
                        <p><strong>Email:</strong> {user.email}</p>
                        <p className="flex items-center gap-2">
                            <strong>Roles:</strong>
                            {user.roles.map((role) => (
                                <span
                                key={role}
                                className="inline-block bg-blue-100 text-blue-700 text-xs px-2 py-0.5 rounded"
                                >
                                {role}
                                </span>
                            ))}
                              <button className="bg-gray-200 px-2 py-1 rounded text-xs">
                        Edit Roles
                    </button>
                        </p>
                        <button
                          onClick={() => setEditing(true)}
                          className="mt-2 text-blue-600 hover:underline text-sm"
                        >
                          Edit
                        </button>
                      </div>
                    ) : (
                      <div className="space-y-2">
                        <div>
                          <label className="block text-sm font-medium">First Name</label>
                          <input
                            type="text"
                            value={editableUser.firstName}
                            onChange={(e) =>
                              setEditableUser((prev) => ({
                                ...prev,
                                firstName: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium">Last Name</label>
                          <input
                            type="text"
                            value={editableUser.lastName}
                            onChange={(e) =>
                              setEditableUser((prev) => ({
                                ...prev,
                                lastName: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium">Email</label>
                          <input
                            type="email"
                            value={editableUser.email}
                            onChange={(e) =>
                              setEditableUser((prev) => ({
                                ...prev,
                                email: e.target.value,
                              }))
                            }
                            className="border rounded p-1 w-full text-sm"
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium">Roles</label>
                          <button className="bg-gray-200 px-2 py-1 rounded text-xs">
                            Edit Roles
                          </button>
                        </div>

                        <div className="flex gap-2 mt-2">
                          <button
                            onClick={handleSave}
                            className="px-3 py-1 bg-green-500 text-white rounded text-sm"
                          >
                            Save
                          </button>
                          <button
                            onClick={() => setEditing(false)}
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
            </>
          ))}
        </tbody>
      </table>

      <PermissionModal
        visible={showModal}
        onClose={() => setShowModal(false)}
        permissions={selectedPermissions}
      />
    </div>
  );
};

export default UsersTable;