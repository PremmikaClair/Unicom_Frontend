import { Tabs } from 'expo-router';

export default function TabsLayout() {
  return (
    <Tabs>
      <Tabs.Screen
        name="home"
        options={{
            title : "Home",
          headerShown: false, // 👈 Hide header only for home tab
        }}
      />
      <Tabs.Screen
        name="events"
        options={{
          title: 'Events',
          headerShown: false, // 👈 Header visible here
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          headerShown: false, // 👈 Header visible here
        }}
      />
    </Tabs>
  );
}