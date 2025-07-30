// // src/index.tsx
// import React, { useEffect, useState } from 'react';
// import ReactDOM from 'react-dom/client';
// import { BrowserRouter as Router, Routes, Route, useNavigate, useLocation } from 'react-router-dom';
// import {
//   initiateLogin,
//   performLogout,
//   fetchUserInfo,
//   exchangeCodeForTokens
// } from './authLogic'; // Import auth functions

// // --- Main App Component ---
// const App: React.FC = () => {
//   const [accessToken, setAccessToken] = useState<string | null>(localStorage.getItem('access_token'));
//   const [idToken, setIdToken] = useState<string | null>(localStorage.getItem('id_token'));
//   const [userInfo, setUserInfo] = useState<any>(null);

//   useEffect(() => {
//     // Only fetch user info if we have an access token and haven't fetched info yet
//     if (accessToken && !userInfo) {
//       fetchUserInfo(accessToken).then(data => {
//         setUserInfo(data);
//       });
//     }
//   }, [accessToken, userInfo]);

//   return (
//     <div>
//       <h1>React OAuth2 Integration</h1>
//       {!accessToken ? (
//         // The Login Button
//         <button onClick={initiateLogin}>
//           Login with KU-Alllogin
//         </button>
//       ) : (
//         <>
//           <p>You are logged in!</p>
//           <p><strong>Access Token (for demo, keep secure in real app):</strong> {accessToken.substring(0, 30)}...</p>
//           <p><strong>ID Token (for demo, keep secure in real app):</strong> {idToken?.substring(0, 30)}...</p>
//           {userInfo && (
//             <div>
//               <h2>User Info:</h2>
//               <pre>{JSON.stringify(userInfo, null, 2)}</pre>
//             </div>
//           )}
//           <button onClick={() => performLogout(idToken)}>Logout</button>
//         </>
//       )}
//     </div>
//   );
// };

// // --- Callback Component (integrated directly into index.tsx's routing) ---
// const CallbackPage: React.FC = () => {
//   const location = useLocation();
//   const navigate = useNavigate();

//   useEffect(() => {
//     const params = new URLSearchParams(location.search);
//     const code = params.get('code');
//     const state = params.get('state');

//     if (code && state) {
//       exchangeCodeForTokens(code, state).then(tokens => {
//         if (tokens) {
//           localStorage.setItem('access_token', tokens.accessToken);
//           if (tokens.idToken) {
//             localStorage.setItem('id_token', tokens.idToken);
//           }
//         }
//         navigate('/'); // Always navigate home after callback
//       });
//     } else {
//       console.error('Missing code or state in callback URL.');
//       navigate('/');
//     }
//   }, [location, navigate]);

//   return (
//     <div>
//       <p>Processing login...</p>
//     </div>
//   );
// };

// const root = ReactDOM.createRoot(
//   document.getElementById('root') as HTMLElement
// );

// root.render(
//   <React.StrictMode>
//     <Router>
//       <Routes>
//         <Route path="/" element={<App />} />
//         <Route path="/callback" element={<CallbackPage />} />
//       </Routes>
//     </Router>
//   </React.StrictMode>
// );