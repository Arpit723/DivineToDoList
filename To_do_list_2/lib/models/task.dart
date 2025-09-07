
enum TaskCategory {
  transportation('Transportation'),
  food('Food'),
  bills('Bills'),
  bigExpenditure('Big expenditure'),
  medicines('Medicines');

  const TaskCategory(this.name);
  final String name;
}

enum TaskStatus {
  assigned('Assigned'),
  started('Started'),
  completed('Completed');

  const TaskStatus(this.name);
  final String name;
}

class Task {
  String id;        // Unique identifier for each task
  String title;     // The main task text
  String description; // Optional extra details
  TaskStatus status; // Task status (Assigned, Started, Completed)
  DateTime createdAt; // When the task was created
  DateTime? dueDate; // Optional due date and time
  TaskCategory category; // Task category

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.assigned,
    required this.createdAt,
    this.dueDate,
    this.category = TaskCategory.transportation,
  });

  // Convert Task to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'category': category.name,
    };
  }

  // Create Task from JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      status: _parseStatus(json['status']) ?? _parseOldStatus(json['isCompleted']),
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      category: _parseCategory(json['category']),
    );
  }

  // Helper method to parse status from string
  static TaskStatus? _parseStatus(String? statusString) {
    if (statusString == null) return null;
    
    switch (statusString.toLowerCase()) {
      case 'assigned':
        return TaskStatus.assigned;
      case 'started':
        return TaskStatus.started;
      case 'completed':
        return TaskStatus.completed;
      default:
        return null;
    }
  }

  // Helper method for backward compatibility with old boolean isCompleted
  static TaskStatus _parseOldStatus(bool? isCompleted) {
    if (isCompleted == true) {
      return TaskStatus.completed;
    }
    return TaskStatus.assigned;
  }

  // Helper method to parse category from string
  static TaskCategory _parseCategory(String? categoryString) {
    if (categoryString == null) return TaskCategory.transportation;
    
    switch (categoryString.toLowerCase()) {
      case 'transportation':
        return TaskCategory.transportation;
      case 'food':
        return TaskCategory.food;
      case 'bills':
        return TaskCategory.bills;
      case 'big expenditure':
        return TaskCategory.bigExpenditure;
      case 'medicines':
        return TaskCategory.medicines;
      default:
        return TaskCategory.transportation;
    }
  }

  // Helper method to check if task is overdue
  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  // Helper method to check if task is completed
  bool get isCompleted => status == TaskStatus.completed;

  // Helper method to format due date for display
  String get dueDateDisplay {
    if (dueDate == null) return 'No due date';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    
    final timeStr = '${dueDate!.hour}:${dueDate!.minute.toString().padLeft(2, '0')}';
    
    if (dueDay == today) {
      return 'Today at $timeStr';
    } else if (dueDay == tomorrow) {
      return 'Tomorrow at $timeStr';
    } else {
      return '${dueDate!.day}/${dueDate!.month}/${dueDate!.year} at $timeStr';
    }
  }
}