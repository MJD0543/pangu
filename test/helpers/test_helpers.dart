// test/helpers/test_helpers.dart
/// 测试工具集：初始化 sqflite FFI + 内存数据库
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 初始化 sqflite 以支持桌面/无头环境下的单元测试（使用内存数据库）
/// 每个 test 文件的 main() 中调用一次即可
void initTestDb() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
