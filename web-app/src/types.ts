

export type Role = {
  id: string;
  name: string;            // e.g., 'admin', 'staff', 'student'
  label: string;
  permissions: Permission[];
};

export type User = {
    id: number;
    firstName: string;
    lastName: string;
    thaiprefix: string;
    gender : string;
    type_person : string;
    student_id: string;
    advisor_id: string;
    email: string;
    roles: string[]; // list of roles
  };



  
  export type Permission = {
    id: number;
    resource: string;
    action: string;
  };

export type LoginResult = {
  user: User;
  accessToken: string;     // short-lived
  // refresh token stays in HttpOnly cookie set by server
};