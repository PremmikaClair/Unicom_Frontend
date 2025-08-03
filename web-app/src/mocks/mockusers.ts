import type { User, Permission } from "../types";

export const mockUsers: User[] = [
  {
    id: 1,
    firstName: "Alice",
    lastName: "Smith",
    email: "alice@example.com",
    roles: ["Admin", "Editor"],
  },
  {
    id: 2,
    firstName: "Bob",
    lastName: "Brown",
    email: "bob@example.com",
    roles: ["Viewer"],
  },
  {
    id: 3,
    firstName: "Charlie",
    lastName: "Johnson",
    email: "charlie@example.com",
    roles: ["Moderator"],
  },
];

export const mockPermissions: Record<number, Permission[]> = {
  1: [
    { id: 1, resource: "dashboard", action: "view" },
    { id: 2, resource: "users", action: "edit" },
  ],
  2: [{ id: 3, resource: "dashboard", action: "view" }],
  3: [],
};