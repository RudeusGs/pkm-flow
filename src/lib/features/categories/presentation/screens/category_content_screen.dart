import 'package:flutter/material.dart';

class CategoryContentScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const CategoryContentScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> allContents = [
      {'id': '1', 'categoryId': 'cat_1', 'title': 'Lập trình Flutter cơ bản', 'desc': 'Bài 1: Giới thiệu về Flutter'},
      {'id': '2', 'categoryId': 'cat_1', 'title': 'Lập trình Flutter nâng cao', 'desc': 'Bài 2: Quản lý trạng thái (State Management)'},
      {'id': '3', 'categoryId': 'cat_2', 'title': 'Báo cáo tháng 10', 'desc': 'Tổng hợp số liệu dự án A'},
      {'id': '4', 'categoryId': 'cat_3', 'title': 'Lịch tập gym', 'desc': 'Các bài tập phát triển cơ tay và ngực'},
      {'id': '5', 'categoryId': 'cat_4', 'title': 'Danh sách game hay', 'desc': 'Top 10 game đáng chơi nhất 2024'},
    ];

    final filteredContents = allContents.where((c) => c['categoryId'] == categoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        centerTitle: true,
      ),
      body: filteredContents.isEmpty
          ? const Center(child: Text('Chưa có nội dung trong danh mục này.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: filteredContents.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final content = filteredContents[index];
                return ListTile(
                  leading: const Icon(Icons.article_outlined, color: Colors.blueGrey),
                  title: Text(
                    content['title']!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(content['desc']!),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bạn vừa bấm vào: ${content['title']}')),
                    );
                  },
                );
              },
            ),
    );
  }
}
