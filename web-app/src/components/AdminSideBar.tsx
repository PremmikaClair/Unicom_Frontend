import { useMemo, useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import {
  LogOutIcon,
  Menu as MenuIcon,
  X as CloseIcon,
  Users2 as UsersIcon,
  Shield as ShieldIcon,
  Newspaper as PostIcon,
  CalendarDays as EventsIcon,
} from "lucide-react";
import { useAuth } from "../features/auth/AuthContext";


const AdminSideBar = () => {
  const [isOpen, setIsOpen] = useState(true); // Sidebar defaults to open
  const navigate = useNavigate();
  const { logout } = useAuth();

  const handleLogout = async () => {
    await logout();               // clears token + user
    navigate("/login", { replace: true });
  };

  const items = useMemo(() => ([
    { to: "/users", label: "Users", icon: UsersIcon },
    { to: "/roles", label: "Roles", icon: ShieldIcon },
    { to: "/post",  label: "Posts", icon: PostIcon },    
  ]), []);

  return (
    <>
      {/* Sidebar */}
      <aside
        className={`transition-all duration-300 ${isOpen ? "w-64" : "w-16"} h-screen sticky top-0 z-20`}
     >
        <div className="h-full bg-emerald-50/70 dark:bg-emerald-900 backdrop-blur border-r border-emerald-100 dark:border-emerald-800 shadow-sm flex flex-col overflow-y-auto">
          {/* Header */}
          <div className="flex items-center justify-between px-3 py-3 bg-emerald-700 text-white">
            <div className="flex items-center gap-2 overflow-hidden">
              {isOpen && (
                <div className="font-semibold flex items-center gap-2">
                  Admin Panel
                  <span className="inline-flex items-center rounded-full bg-emerald-500 text-white text-[11px] px-2 py-0.5">●</span>
                </div>
              )}
            </div>
            <button
              onClick={() => setIsOpen((v) => !v)}
              className="p-2 rounded-full text-white/90 hover:bg-emerald-600"
              aria-label={isOpen ? "Collapse sidebar" : "Expand sidebar"}
            >
              {isOpen ? <CloseIcon className="w-4 h-4"/> : <MenuIcon className="w-4 h-4"/>}
            </button>
          </div>

          {/* Nav */}
          <nav className="mt-2 flex-1 px-2">
            <ul className="space-y-1">
              {items.map(({ to, label, icon: Icon }) => (
                <li key={to}>
                  <NavLink
                    to={to}
                    title={label}
                    className={({ isActive }) =>
                      `group flex items-center gap-3 rounded-lg px-2 ${isOpen ? "py-2" : "py-2.5 justify-center"} transition
                       ${isActive ? "bg-emerald-100/70 text-emerald-800 dark:bg-emerald-800/60 dark:text-emerald-100" : "text-emerald-900/80 dark:text-emerald-100/70 hover:bg-emerald-100/50 dark:hover:bg-emerald-800/40"}`
                    }
                  >
                    <Icon className={`w-4 h-4 ${isOpen ? "opacity-90" : ""}`} />
                    {isOpen && <span className="truncate text-sm">{label}</span>}
                  </NavLink>
                </li>
              ))}

              {/* Events group */}
              <li>
                <div className={`flex items-center gap-3 rounded-lg px-2 ${isOpen ? "py-2" : "py-2.5 justify-center"} text-emerald-900/80 dark:text-emerald-100/70`}>
                  <EventsIcon className={`w-4 h-4 ${isOpen ? "opacity-90" : ""}`} />
                  {isOpen && <span className="truncate text-sm font-medium">Events</span>}
                </div>
                {/* sub links */}
                <div className={isOpen ? "pl-7" : "pl-2"}>
                  <NavLink
                    to="/events"
                    title="All Events"
                    className={({ isActive }) =>
                      `block rounded-lg ${isOpen ? "px-2 py-1.5" : "px-0 py-1.5 text-center"} text-sm transition
                      ${isActive ? "bg-emerald-100/70 text-emerald-800 dark:bg-emerald-800/60 dark:text-emerald-100" : "text-emerald-900/80 dark:text-emerald-100/70 hover:bg-emerald-100/50 dark:hover:bg-emerald-800/40"}`
                    }
                  >
                    {isOpen ? "All Events" : "All"}
                  </NavLink>         

                  <NavLink
                    to="/events/participants"
                    title="Participant Management"
                    className={({ isActive }) =>
                      `block rounded-lg ${isOpen ? "px-2 py-1.5" : "px-0 py-1.5 text-center"} text-sm transition
                      ${isActive ? "bg-emerald-100/70 text-emerald-800 dark:bg-emerald-800/60 dark:text-emerald-100" : "text-emerald-900/80 dark:text-emerald-100/70 hover:bg-emerald-100/50 dark:hover:bg-emerald-800/40"}`
                    }
                  >
                    {isOpen ? "Participant Management" : "Manage"}
                  </NavLink>
                </div>
              </li>
            </ul>
          </nav>

          {/* Footer actions */}
          <div className="px-2 pb-3">
            <button
              type="button"
              onClick={handleLogout}
              className={`w-full inline-flex items-center ${isOpen ? "justify-center gap-2" : "justify-center"} rounded-full px-3 py-2 text-sm text-red-700 bg-red-50 hover:bg-red-100 transition`}
            >
              <LogOutIcon className="w-4 h-4" />
              {isOpen && <span>Logout</span>}
            </button>
          </div>
        </div>
      </aside>

      {/* No extra spacing wrapper here; layout handles content */}
    </>
  );
};

export default AdminSideBar;
