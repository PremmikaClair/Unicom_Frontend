// import from your mock file
import { mockPermissions } from "./mocks/mockusers";
import type { User, Permission } from "./types";


export async function getUserPermissions(userId: number): Promise<Permission[]> {
  await new Promise((resolve) => setTimeout(resolve, 300));
  return mockPermissions[userId] || [];
}

const API_BASE = "http://localhost:3000/api";

export async function getUsers(): Promise<User[]> {
  try {
    console.log("[api.ts] Fetching users from:", `${API_BASE}/users`);
    
    const res = await fetch(`${API_BASE}/users`);
    
    if (!res.ok) {
      console.error(`[api.ts] Error fetching users: ${res.status} ${res.statusText}`);
      throw new Error("Failed to fetch users");
    }
    
    const data = await res.json();
    console.log("[api.ts] Users received:", data);
    return data;
  } catch (error) {
    console.error("[api.ts] Fetch users exception:", error);
    throw error;
  }
}