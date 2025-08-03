const AdminHeader = () => {
    return (
      <header className="bg-white shadow-sm px-6 py-4 flex justify-between items-center sticky top-0 z-10">
        <h1 className="text-xl font-bold text-gray-800">Admin Dashboard</h1>
        <div className="flex items-center gap-4">
          {/* Placeholder for future: user avatar, dark mode toggle, etc. */}
          <span className="text-sm text-gray-600">Hello, Admin</span>
        </div>
      </header>
    );
  };
  
  export default AdminHeader;