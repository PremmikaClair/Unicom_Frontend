// ---------- Existing ----------
// Org tree node
export type OrgUnitNode = {
  org_path: string;                 // "/faculty/eng/com"
  label?: string;                   // "Computer Engineering"
  short_name?: string;              // "COM"
  children?: OrgUnitNode[];
};

// Policy (scoped, prefix-based)
export type Policy = {
  _id?: string;
  key?: string;
  position_key: string;             // "head" | "member" | "student"
  where: { org_prefix: string };    // "/faculty/" or "/club/"
  scope: "exact" | "subtree";
  effect: "allow" | "deny";         // MVP: allow
  actions: string[];                // e.g. ["post:create", "event:create"]
  enabled: boolean;
  created_at?: string;
};

export type Position = {
  key: string;
  display?: { [lang: string]: string };
  rank?: number;
  scope?: { org_path?: string; inherit?: boolean };
  constraints?: { exclusive_per_org?: boolean };
  status?: "active" | "inactive";
};

export type MembershipDoc = {
  _id?: string;                // membership id (ObjectId)
  org_path: string;            // "/club/cpsk"
  position_key: string;        // "head"
  status?: "active" | "inactive";        // legacy enum (optional)
  active?: boolean;           // preferred boolean (BE normalization)
  user_id?: string;            // owner id
  joined_at?: string;          // ISO
  created_at?: string;         // ISO (if provided)
  org_ancestors?: string[];    // e.g., ["/", "/faculty", "/faculty/eng"]
};
// FE shape already used across the app
export type Membership = {
  _id?: string;
  org_path: string;
  position_key: string;
  active?: boolean;
};

export type UserBrief = {
  _id?: string;
  id?: number;
  firstName?: string;
  lastName?: string;
  email?: string;
  student_id?: string;
};

export type MembershipWithUser = Membership & {
  user?: UserBrief;
  user_id?: string;
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
  media?: string[];
  commentCount?: number;

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


// A single permission key (derived from policies). Simple alias for clarity in UI.
export type Permission = {
  key: string;            // e.g., "users:read"
  label?: string;
};



export type OrgUnit = {
  _id?: string;
  path: string;                // "/faculty/eng/com"
  parent_path?: string;        // "/faculty/eng"
  ancestors?: string[];        // ["/", "/faculty", "/faculty/eng"]
  depth?: number;
  slug?: string;
  type?: string;               // "faculty" | "club" | ...
  name?: Record<string, string>;
  short_name?: Record<string, string>;
  sort?: number;
  status?: "active" | "archived";
  visibility?: "public" | "private";
};

// -------- Events --------
export type EventDoc = {
  id?: string;                 // ObjectId hex
  _id?: string;                // compatibility if list returns _id
  node_id?: string;
  topic: string;
  description?: string;
  max_participation?: number;
  posted_as?: { org_path?: string; position_key?: string; label?: string };
  visibility?: { access?: string; audience?: any[] };
  org_of_content?: string;
  status?: "active" | "hidden" | string;
  have_form?: boolean;
  created_at?: string;
  updated_at?: string;
  schedules?: Array<{ date: string; start_time?: string; end_time?: string; time_start?: string; time_end?: string; location?: string; description?: string }>;
};

// -------- Comments --------
export type CommentDoc = {
  id?: string;
  _id?: string;             // not expected, but safe
  postId?: string;
  userId?: string;
  text: string;
  createdAt?: string;
  updatedAt?: string;
  likeCount?: number;
};
