import type { Permission } from "../types";

type Props = {
  visible: boolean;
  onClose: () => void;
  permissions: Permission[];
};

const PermissionModal = ({ visible, onClose, permissions }: Props) => {
  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/20 backdrop-blur-sm flex justify-center items-center">
      <div className="bg-white p-4 rounded-lg shadow-md max-w-md w-full">
        <h2 className="text-xl font-bold mb-4">User Permissions</h2>
        <table className="w-full text-sm">
          <thead>
            <tr>
              <th className="text-left p-2">Resource</th>
              <th className="text-left p-2">Action</th>
            </tr>
          </thead>
          <tbody>
            {permissions.map((perm) => (
              <tr key={perm.id}>
                <td className="p-2">{perm.resource}</td>
                <td className="p-2">{perm.action}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <button
          onClick={onClose}
          className="mt-4 px-4 py-2 bg-gray-200 rounded hover:bg-gray-300"
        >
          Close
        </button>
      </div>
    </div>
  );
};

export default PermissionModal;