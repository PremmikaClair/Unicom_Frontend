// App.tsx
import { Routes, Route } from "react-router-dom";
import RequireAuth from "./features/auth/RequireAuth";
import Login from "./features/auth/Login";
import UsersPage from "./features/users/UserPage";
import RolesPage from "./features/roles/RolesPage";
import PostPage from "./features/posts/PostPage";
import AdminLayout from "./layouts/AdminLayout";
export default function App() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/login" element={<Login />} />

      {/* Protected */}
      <Route element={<RequireAuth />}>
        <Route element={<AdminLayout />}>
          <Route path="/users" element={<UsersPage />} />
          <Route path="/roles" element={<RolesPage />} />
          <Route path="/post" element={<PostPage />} />
          {/* default protected landing */}
          <Route path="/" element={<UsersPage />} />
        </Route>
      </Route>
    </Routes>
  );
}