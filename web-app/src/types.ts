// ---------- Existing ----------
export type Position = {
  key: string;
  display?: { [lang: string]: string };
  rank?: number;
  scope?: { org_path?: string; inherit?: boolean };
  constraints?: { exclusive_per_org?: boolean };
  status?: "active" | "inactive";
};

export type Membership = {
  org_path: string;            // "/club/cpsk"
  position_key: string;        // "head"
  joined_at?: string;          // ISO
};

export type RolesSummary = {
  user_id: string;
  memberships: Membership[];
  updated_at?: string;
};

export type User = {
  _id?: string;
  id: number;                  // SeqID (numeric app id)
  firstName: string;
  lastName: string;
  email: string;
  password_hash?: string;
  student_id?: string;
  advisor_id?: string;
  gender?: string;
  type_person?: string;        // "student" | "faculty" | ...
  status?: "active" | "suspended";

  // convenience (may be populated by API)
  memberships?: Membership[];
  permissions?: string[];
};

// ---------- Add these ----------
export type TagItem = {
  org_path: string;
  position_key: string;
  position_display?: string;
  org_short?: string;
  tag: string;                 // e.g., "Head • CPSK"
};

export type AbilitiesResp = {
  org_path: string;
  abilities: Record<string, boolean>; // e.g., { "event:create": true, "post:create": true }
  version?: string;
};

export type PostDoc = {
  _id: string;
  uid: string;
  name?: string;
  username?: string;
  message: string;
  timestamp: string;
  likes: number;
  likedBy: string[];

  posted_as?: {                 // posting “as”
    org_path?: string;
    position_key?: string;
    label?: string;             // or tag, either is fine
    tag?: string;
  };

  visibility?: {
    access?: "public" | "org" | "custom";
    audience?: { org_path: string; scope: "exact" | "subtree" }[];
    include_positions?: string[];
    exclude_positions?: string[];
    allow_user_ids?: string[];
    deny_user_ids?: string[];
  };

  org_of_content?: string;
  status?: "active" | "hidden" | "deleted";
  created_at?: string;
  updated_at?: string;
};

// Optional helpers for common API payloads
export type Paged<T> = { items: T[]; nextCursor?: string };