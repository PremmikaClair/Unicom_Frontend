// App.tsx
import { Routes, Route, Navigate } from "react-router-dom";
import RequireAuth from "./features/auth/RequireAuth";
import Login from "./features/auth/Login";
import UsersPage from "./features/users/UserPage";
import RolesPage from "./features/roles/RolesPage";
import PostPage from "./features/posts/PostPage";
import EventsPage from "./features/events/EventsPage";
import AdminLayout from "./layouts/AdminLayout";

export default function App() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/login" element={<Login />} />

      {/* Protected */}
      <Route element={<RequireAuth />}>
        <Route element={<AdminLayout />}>
          <Route index element={<UsersPage />} />           {/* default under / */}
          <Route path="/users" element={<UsersPage />} />
          <Route path="/roles" element={<RolesPage />} />
          <Route path="/post"  element={<PostPage />} />
          <Route path="/events"  element={<EventsPage />} />
          {/* optional: catch-all back to home */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Route>
    </Routes>
  );
}