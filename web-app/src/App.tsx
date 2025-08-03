// App.tsx
import { Routes, Route } from "react-router-dom";
import Login from "./pages/Login";
import Main from "./pages/Main";
import UserPage from "./pages/UserPage";
import RolesPage from "./pages/RolesPage";
import PostPage from "./pages/PostPage";
import AdminLayout from "./layouts/AdminLayout";

function App() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />

      {/* Admin layout wraps admin routes */}
      <Route path="/" element={<AdminLayout />}>
        <Route path="main" element={<Main />} />
        <Route path="users" element={<UserPage />} />
        <Route path="roles" element={<RolesPage />} />
        <Route path="post" element={<PostPage />} />
      </Route>
    </Routes>
  );
}

export default App;