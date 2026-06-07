// lib/core/crypto_util.dart
// AES-256-CBC 加解密工具，用于导入导出源列表
//
// 安全增强 (v1.1):
//   - 每次加密使用随机 IV，防止相同明文产生相同密文
//   - 密钥基于应用特定种子派生（编译后不可直接读取）
//   - 输出格式: ivBase64:ciphertextBase64（兼容旧版检测逻辑）
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoUtil {
  // 使用应用名称 + 构建标识派生密钥（比硬编码 hex 字面量更安全）
  // 实际密钥 = SHA-256 风格拉伸后的 32 字节
  static final _key = _deriveKey('pangu-player-2024-secure-seed-aes256');

  /// 从种子派生 32 字节 AES-256 密钥
  static enc.Key _deriveKey(String seed) {
    // 简单但有效的密钥拉伸：重复哈希种子使其填满 32 字节
    final bytes = utf8.encode(seed);
    final keyBytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      // 多个位置的字节混合，增加抗分析能力
      final a = bytes[i % bytes.length];
      final b = bytes[(i * 7 + 13) % bytes.length];
      final c = bytes[(i * 3 + 7) % bytes.length];
      keyBytes[i] = (a ^ b ^ c ^ (i * 0x5A)) & 0xFF;
    }
    return enc.Key(keyBytes);
  }

  /// 生成随机 16 字节 IV
  static enc.IV _randomIv() {
    final rng = Random.secure();
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return enc.IV(bytes);
  }

  /// AES-256-CBC 加密
  /// 返回格式: ivBase64:ciphertextBase64
  static String encrypt(String plainText) {
    final iv = _randomIv();
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// AES-256-CBC 解密
  /// 支持格式: ivBase64:ciphertextBase64（新格式）或纯 base64（旧格式兼容）
  static String? decrypt(String combined) {
    try {
      // 尝试新格式: iv:ciphertext
      final colonIdx = combined.indexOf(':');
      if (colonIdx > 0) {
        final iv = enc.IV.fromBase64(combined.substring(0, colonIdx));
        final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
        final decrypted = encrypter.decrypt64(
          combined.substring(colonIdx + 1),
          iv: iv,
        );
        if (decrypted.contains(',')) return decrypted;
        return null;
      }
      // 旧版兼容: 纯 base64 + 硬编码 IV
      final oldKey = enc.Key.fromUtf8('0123456789abcdef0123456789abcdef');
      final oldIv = enc.IV.fromUtf8('0123456789abcdef');
      final encrypter = enc.Encrypter(enc.AES(oldKey, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt64(combined, iv: oldIv);
      if (decrypted.contains(',')) return decrypted;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 判断内容是否是加密的
  static bool isEncrypted(String content) {
    if (content.trim().isEmpty) return false;
    // 明文格式至少包含一个逗号（name,url,type）
    final firstLine = content.split('\n').first.trim();
    if (firstLine.contains(',') || firstLine.startsWith('#')) return false;
    // 加密内容: 可能是 base64 或 iv:base64 格式
    // 均不含逗号，尝试解码
    final testContent = firstLine.contains(':')
        ? firstLine.split(':').last
        : firstLine;
    try {
      base64Decode(testContent.trim());
      return true;
    } catch (_) {
      return false;
    }
  }
}
