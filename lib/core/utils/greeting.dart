/// Time-of-day greeting based on the device's local time.
String greetingFor(DateTime localTime) {
  final h = localTime.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  if (h >= 17 && h < 22) return 'Good evening';
  return 'Hello';
}

/// Short greeting for the Home headline: "Morning", "Afternoon", "Evening".
String shortGreetingFor(DateTime localTime) {
  final h = localTime.hour;
  if (h >= 5 && h < 12) return 'Morning';
  if (h >= 12 && h < 17) return 'Afternoon';
  if (h >= 17 && h < 22) return 'Evening';
  return 'Hello';
}
