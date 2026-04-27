import 'package:flutter/material.dart';
import '../../../../core/routes/app_routes.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> categories = [
      {'id': 'cat_1', 'name': 'Học tập', 'icon': 'school'},
      {'id': 'cat_2', 'name': 'Công việc', 'icon': 'work'},
      {'id': 'cat_3', 'name': 'Sức khoẻ', 'icon': 'favorite'},
      {'id': 'cat_4', 'name': 'Giải trí', 'icon': 'sports_esports'},
    ];

    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'school': return Icons.school;
        case 'work': return Icons.work;
        case 'favorite': return Icons.favorite;
        case 'sports_esports': return Icons.sports_esports;
        default: return Icons.category;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(getIcon(category['icon']!), color: Theme.of(context).primaryColor),
              ),
              title: Text(
                category['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Xem nội dung chi tiết'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.categoryContent,
                  arguments: {
                    'categoryId': category['id'],
                    'categoryName': category['name'],
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
