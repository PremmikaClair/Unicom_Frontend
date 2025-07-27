import { router } from 'expo-router';
import { Text, TouchableOpacity, View } from 'react-native';

export default function Profile() {
  const handleLogout = () => {
    // Navigate back to login screen (replace stack)
    router.replace('/login');
  };

  return (
    <View className="flex-1 justify-center items-center px-6 bg-white">
      <Text className="text-2xl font-semibold mb-6">Profile</Text>

      <TouchableOpacity
        onPress={handleLogout}
        className="bg-red-600 py-3 px-6 rounded-xl"
      >
        <Text className="text-white text-center font-medium">Log out</Text>
      </TouchableOpacity>
    </View>
  );
}