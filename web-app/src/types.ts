// src/types.ts

// Permission (simple)
export type Permission = {
  id?: string;
  key: string;          // e.g. "user:read"
  label?: string;
  category?: string;
};

// Role
export type Role = {
  id?: string;
  name: string;         // e.g. "student", "econ", "badminton"
  label: string;
  permissions: string[]; // array of permission keys
};

// User
export type User = {
  _id?: string;
  id: number;           // required: your mock data always has it
  firstName: string;
  lastName: string;
  thaiprefix?: string;
  gender?: string;
  type_person?: string;
  student_id?: string;
  advisor_id?: string;
  email: string;
  roles: string[];      // just strings — simple & flexible
  createdAt?: string;
  updatedAt?: string;
};

// Role binding (optional if you need scopes later)
export type RoleBinding = {
  id?: string;
  userId: string;
  student_id?: string;
  roleName: string;
  scope: { type: "global" | "faculty" | "club"; [k: string]: any };
};