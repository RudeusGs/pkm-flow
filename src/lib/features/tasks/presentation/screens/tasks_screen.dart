import 'package:flutter/material.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = ['Write report', 'Study Flutter', 'Review block editor'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.check_box_outline_blank),
            title: Text(tasks[index]),
          );
        },
      ),
    );
  }
}