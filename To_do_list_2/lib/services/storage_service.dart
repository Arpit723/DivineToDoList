import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class StorageService {
  static const String _tasksKey = 'tasks';

  // Save tasks to local storage
  static Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, jsonEncode(tasksJson));
  }

  // Load tasks from local storage
  static Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksString = prefs.getString(_tasksKey);
    
    if (tasksString == null || tasksString.isEmpty) {
      return [];
    }

    try {
      final tasksJson = jsonDecode(tasksString) as List;
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  // Clear all tasks
  static Future<void> clearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tasksKey);
  }
}
