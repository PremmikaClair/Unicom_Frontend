// src/authLogic.ts

// --- OAuth2 Configuration ---
export const CLIENT_ID = 'YOUR_CLIENT_ID'; // <--- REPLACE WITH YOUR CLIENT ID
// export const CLIENT_SECRET = 'YOUR_CLIENT_SECRET'; // <-- DANGER! DO NOT USE IN FRONTEND.
export const USER_SCOPE = 'basic openid profile email';
export const REDIRECT_URI = 'http://localhost:3000/callback'; // <--- REPLACE WITH YOUR REDIRECT URI
export const LOGOUT_REDIRECT_URI = 'http://localhost:3000'; // <--- REPLACE WITH YOUR LOGOUT REDIRECT URI
export const AUTHORIZATION_ENDPOINT = 'https://alllogin.ku.ac.th/realms/KU-Alllogin/protocol/openid-connect/auth';
export const TOKEN_ENDPOINT = 'https://alllogin.ku.ac.th/realms/KU-Alllogin/protocol/openid-connect/token';
export const USER_INFO_ENDPOINT = 'https://alllogin.ku.ac.th/realms/KU-Alllogin/protocol/openid-connect/userinfo';
export const END_SESSION_ENDPOINT = 'https://alllogin.ku.ac.th/realms/KU-Alllogin/protocol/openid-connect/logout';

// --- Helper for generating a random string (PKCE state) ---
export function generateRandomString(length: number) {
  let result = '';
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const charactersLength = characters.length;
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength));
  }
  return result;
}

// --- Function to initiate Login ---
export const initiateLogin = () => {
  const state = generateRandomString(16);
  localStorage.setItem('oauth_state', state);

  const authUrl = new URL(AUTHORIZATION_ENDPOINT);
  authUrl.searchParams.append('client_id', CLIENT_ID);
  authUrl.searchParams.append('redirect_uri', REDIRECT_URI);
  authUrl.searchParams.append('response_type', 'code');
  authUrl.searchParams.append('scope', USER_SCOPE);
  authUrl.searchParams.append('state', state);

  window.location.href = authUrl.toString();
};

// --- Function to handle Logout ---
export const performLogout = (idToken: string | null) => {
  localStorage.removeItem('access_token');
  localStorage.removeItem('id_token');
  localStorage.removeItem('oauth_state');

  const logoutUrl = new URL(END_SESSION_ENDPOINT);
  logoutUrl.searchParams.append('id_token_hint', idToken || '');
  logoutUrl.searchParams.append('post_logout_redirect_uri', LOGOUT_REDIRECT_URI);
  window.location.href = logoutUrl.toString();
};

// --- Function to fetch User Info ---
export const fetchUserInfo = async (accessToken: string) => {
  try {
    const response = await fetch(USER_INFO_ENDPOINT, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Error fetching user info: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Failed to fetch user info:', error);
    return null;
  }
};

// --- Function to exchange Code for Tokens (Client-side for demo, but should be Backend) ---
// This is exposed for the CallbackComponent in index.tsx
export const exchangeCodeForTokens = async (code: string, state: string): Promise<{ accessToken: string, idToken: string | null } | null> => {
  const storedState = localStorage.getItem('oauth_state');

  if (state !== storedState) {
    console.error('State mismatch. Possible CSRF attack.');
    return null;
  }
  localStorage.removeItem('oauth_state');

  try {
    const response = await fetch(TOKEN_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: CLIENT_ID,
        // client_secret: CLIENT_SECRET, // <--- AGAIN, DO NOT USE IN FRONTEND! Use on Backend!
        code: code,
        redirect_uri: REDIRECT_URI,
      }).toString(),
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('Token exchange failed:', errorData);
      throw new Error(`Error exchanging code for tokens: ${response.statusText}`);
    }

    const data = await response.json();
    console.log('Tokens received:', data);

    return {
      accessToken: data.access_token,
      idToken: data.id_token || null
    };
  } catch (error) {
    console.error('Error during token exchange:', error);
    return null;
  }
};