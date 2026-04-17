import 'package:flutter/material.dart';

class PageDetailScreen extends StatelessWidget {
  final String pageId;
  final String title;

  const PageDetailScreen({
    super.key,
    required this.pageId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = [
      'Block 1: Xin chào PKM',
      'Block 2: Đây là ghi chú dạng block',
      'Block 3: Flutter navigation demo',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Page ID: $pageId'),
            const SizedBox(height: 16),
            const Text(
              'Danh sách block:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...blocks.map((block) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('• $block'),
                )),
          ],
        ),
      ),
    );
  }
}