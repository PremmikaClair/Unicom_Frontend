import { router } from 'expo-router';
import React, { useState } from 'react';
import { Text, TextInput, TouchableOpacity, View } from 'react-native';
import {
  initiateLogin,
  performLogout,
  fetchUserInfo,
  exchangeCodeForTokens
} from './authLogic'; // Import auth functions
export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleMockLogin = () => {
    router.replace('/home'); // Navigate to home tab (mock)
  };

  const handleSSOLogin = () => {
    // Placeholder for OAuth2
    router.replace('/home');
  };

  return (
    <View className="flex-1 justify-center items-center px-6 bg-white">
      <Text className="text-2xl font-semibold text-center text-green-700 mb-6">
        KU Student Login
      </Text>

      <TouchableOpacity
        onPress={initiateLogin}
        className="w-full bg-green-700 py-3 rounded-xl mb-4"
      >
        <Text className="text-white text-center font-medium">Login with KU ALL‑Login</Text>

      </TouchableOpacity>

      <Text className="text-gray-500 my-2">or</Text>

      <TextInput
        className="w-full border border-gray-300 rounded-lg px-4 py-3 mb-3 text-base"
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
      />
      <TextInput
        className="w-full border border-gray-300 rounded-lg px-4 py-3 mb-4 text-base"
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />

      <TouchableOpacity
        onPress={handleMockLogin}
        className="w-full bg-blue-600 py-3 rounded-xl"
      >
        <Text className="text-white text-center font-medium">Login (Mock)</Text>
      </TouchableOpacity>

      <Text className="text-xs text-gray-400 mt-6">
        Having trouble? Visit KU IT support.
      </Text>
    </View>
  );
}