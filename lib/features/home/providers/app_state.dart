import 'package:flutter/material.dart';

import '../models/room_model.dart';

// Application state management
class AppState extends ChangeNotifier {
  final List<Room> rooms = [
    Room(roomName: RoomName.livingRoom),
    Room(roomName: RoomName.bedroom),
    Room(roomName: RoomName.kitchen),
    Room(roomName: RoomName.garage),
  ];

  // Method to update a room and notify listeners
  void updateRoom(Room room) {
    // This is a simple way to trigger a rebuild. For more complex apps,
    // you might want to find the specific room and update it.
    notifyListeners();
  }
}
