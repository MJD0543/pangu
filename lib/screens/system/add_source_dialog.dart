// lib/screens/system/add_source_dialog.dart
import 'package:flutter/material.dart';
import '../../models/source_model.dart';
import '../../services/movie_api_service.dart';
import '../../services/tv_source_service.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';

class AddSourceDialog extends StatefulWidget {
  final SourceType type;
  final VideoSource? existing;
  final Future<void> Function(VideoSource) onAdd;
  /// 检测 URL 是否已存在（用于新增时去重，编辑时不检查）
  final Future<bool> Function(String url)? onCheckExists;

  const AddSourceDialog({
    super.key,
    required this.type,
    required this.onAdd,
    this.existing,
    this.onCheckExists,
  });

  @override
  State<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<AddSourceDialog> {
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _urlFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isValidating = false;
  String? _validationResult;
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _urlFocus.addListener(() => setState(() {}));
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _urlCtrl.text = widget.existing!.url;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _nameFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  Future<void> _validate() async {
    if (_urlCtrl.text.trim().isEmpty) return;
    setState(() { _isValidating = true; _validationResult = null; _isValid = null; });

    bool valid;
    final url = _urlCtrl.text.trim();
    if (widget.type == SourceType.movie) {
      valid = await MovieApiService().validateMovieSource(url);
    } else {
      valid = await TvSourceService().validateTvSource(url);
    }

    setState(() {
      _isValidating = false;
      _isValid = valid;
      _validationResult = valid ? '✓ 源有效，可以添加' : '✗ 源无效或无法访问';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    // ── 新增时检测 URL 是否已存在 ──
    if (!_isEditing && widget.onCheckExists != null) {
      final exists = await widget.onCheckExists!(url);
      if (exists) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('重复源'),
            content: Text('该地址已存在，是否覆盖更新？\n\n$url',
              style: const TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(_, false),
                child: Text(S.cancel)),
              TextButton(
                onPressed: () => Navigator.pop(_, true),
                child: const Text('覆盖',
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (overwrite != true) return; // 用户取消
      }
    }

    // ── 验证 URL 可达性（仅首次）──
    if (_isValid == null) {
      await _validate();
      if (_isValid != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('源验证失败，请检查URL是否正确'), backgroundColor: AppTheme.accentColor),
          );
        }
        return;
      }
    } else if (_isValid == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('源不可用，无法添加'), backgroundColor: AppTheme.accentColor),
        );
      }
      return;
    }

    final source = VideoSource(
      id: _isEditing ? widget.existing!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.isEmpty ? _generateName(url) : name,
      url: url,
      type: widget.type,
      isAvailable: true,
      lastChecked: DateTime.now(),
    );

    await widget.onAdd(source);
    if (mounted) Navigator.of(context).pop();
  }

  String _generateName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return '未命名源';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMovie = widget.type == SourceType.movie;
    return Dialog(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing
                    ? '${S.edit}${isMovie ? S.movieSource : S.tvSource}'
                    : '${S.add}${isMovie ? S.movieSource : S.tvSource}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  decoration: InputDecoration(
                    labelText: S.sourceName,
                    hintText: '留空则自动生成',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(_nameFocus.hasFocus ? 0.0 : 0.35),
                    ),
                    prefixIcon: const Icon(Icons.label_outline),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _urlCtrl,
                  focusNode: _urlFocus,
                  decoration: InputDecoration(
                    labelText: isMovie
                      ? '苹果CMS API地址'
                      : '电视源地址 (.m3u/.txt/URL)',
                    hintText: isMovie
                      ? 'http://example.com/api.php/provide/vod'
                      : 'https://example.com/tv.m3u',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(_urlFocus.hasFocus ? 0.0 : 0.35),
                    ),
                    prefixIcon: const Icon(Icons.link),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _isValidating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: Icon(
                            _isValid == null ? Icons.wifi_tethering
                              : _isValid! ? Icons.check_circle : Icons.cancel,
                            color: _isValid == null ? null
                              : _isValid! ? AppTheme.successColor : AppTheme.accentColor,
                          ),
                          tooltip: S.check,
                          onPressed: _validate,
                        ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入URL';
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null || !uri.hasScheme) return '请输入有效的URL';
                    return null;
                  },
                  onChanged: (_) => setState(() { _isValid = null; _validationResult = null; }),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),

                if (_validationResult != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isValid == true ? AppTheme.successColor : AppTheme.accentColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _validationResult!,
                      style: TextStyle(
                        color: _isValid == true ? AppTheme.successColor : AppTheme.accentColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(S.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isValidating ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isValidating
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(_isEditing ? '保存' : S.add),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
