import 'package:flutter/material.dart';

// Enum for room names to ensure type safety and consistency
enum RoomName {
  livingRoom('Living Room'),
  bedroom('Bedroom'),
  kitchen('Kitchen'),
  garage('Garage');

  final String displayName;
  const RoomName(this.displayName);
}

// Data model for a single room
class Room {
  final RoomName roomName;
  bool lightOn;
  Color ambientColor;
  double temperature;
  bool tvOn;
  bool garageGateOpen;

  Room({
    required this.roomName,
    this.lightOn = false,
    this.ambientColor = Colors.red,
    this.temperature = 22.0,
    this.tvOn = false,
    this.garageGateOpen = false,
  });

  String get name => roomName.displayName;
}
