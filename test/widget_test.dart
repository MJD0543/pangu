// 盘古影视 — 基础 Widget 冒烟测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:newplayer/main.dart';

void main() {
  testWidgets('App starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // 验证 App 至少渲染出导航结构
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
