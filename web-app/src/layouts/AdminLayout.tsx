import { Outlet } from "react-router-dom";
import AdminSideBar from "../components/AdminSideBar";
import AdminHeader from "../components/Header";

const AdminLayout = () => {
  return (
    <div className="flex">
      <AdminSideBar />
      <div className="flex-1 min-h-screen bg-gray-50">
        <AdminHeader />
        <main className="p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default AdminLayout;