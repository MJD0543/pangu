// lib/core/strings.dart
// Simplified: Chinese-only strings (locale switching removed)
class S {
  // Generic
  static const cancel = '取消';
  static const confirm = '确认';
  static const delete = '删除';
  static const retry = '重试';
  static const close = '关闭';
  static const clear = '清空';
  static const selectAll = '全选';
  static const edit = '编辑';
  static const search = '搜索';
  static const import = '导入';
  static const export = '导出';
  static const exportFailed = '导出失败';
  static const importFailed = '导入失败';
  static const check = '检测';
  static const checking = '正在检测...';
  static const available = '可用';
  static const unavailable = '不可用';
  static const justNow = '刚刚';
  static const minutesAgo = '分钟前';
  static const hoursAgo = '小时前';
  static const daysAgo = '天前';
  static const loading = '加载中...';
  static const loadFailed = '加载失败';
  static const noData = '暂无数据';
  static const add = '添加';
  static const addMovieSourceOption = '添加影视源';
  static const addTvSourceOption = '添加电视源';
  static const selectSourceType = '选择源类型';

  // Main Navigation
  static const movie = '影视';
  static const tv = '电视';
  static const system = '系统';

  // Movie Screen
  static const searchMovie = '搜索影视...';
  static const noMovieSource = '暂无影视源';
  static const addMovieSource = '请在「设置」中添加影视源';
  static const noResult = '没有找到相关内容';
  static const allCategories = '全部';
  static const categories = '所有分类';
  static const pinyinSearch = '拼音首字母搜索';
  static const singleLetterSearch = '字母/数字搜索';
  static const browseHistory = '浏览记录';
  static const noHistory = '暂无浏览记录';

  // Movie Player
  static const noPlayUrl = '暂无播放地址';
  static const noEpisodes = '暂无剧集信息';
  static const selectEpisode = '选集';
  static const synopsis = '简介';
  static const director = '导演';
  static const actor = '演员';
  static const unknownEpisode = '未知集数';
  static const sourceLabel = '源';
  static const episodeLabel = '集数';

  // TV Screen
  static const loadingChannels = '加载频道列表...';
  static const selectChannel = '请选择频道';
  static const channelList = '频道列表';
  static const noTvSource = '暂无电视源';
  static const addTvSource = '请在「设置」中添加电视源';
  static const channelEmpty = '频道列表为空';
  static const switchToTvTab = '切换到电视标签以播放';
  static const ungrouped = '未分组';

  // System / Settings
  static const settings = '设置';
  static const appearance = '外观';
  static const language = '语言';
  static const watchHistory = '浏览记录';
  static const server = '服务器';
  static const resourceLibrary = '资源库';
  static const player = '播放器';
  static const core = '内核';
  static const about = '关于';
  static const homepage = '软件主页';
  static const license = '软件协议';
  static const sponsor = '赞助';
  static const sponsorSupport = '赞助支持';
  static const sponsorContent = '感谢您对 盘古影视 的支持！\n\n本项目为开源免费软件，如果您觉得有帮助，欢迎通过以下方式赞助开发者：\n\n• GitHub Sponsors\n• 支付宝 / 微信支付\n\n您的支持是我们持续改进的动力。';
  static const appName = '盘古影视';
  static const clearCache = '清理缓存';
  static const cacheCleared = '缓存已清理';
  static const version = '版本号';
  static const auto = '自动';
  static const light = '浅色';
  static const dark = '深色';

  // Resource Library
  static const movieSource = '影视源';
  static const tvSource = '电视源';
  static const noSource = '暂无源';
  static const tapAdd = '点击右下角 + 添加';
  static const batchAction = '批量操作';
  static const importSource = '导入';
  static const exportSource = '导出';
  static const checkAll = '检测所有';
  static const exportAll = '导出全部';
  static const importFromFile = '从本地文件导入（TXT）';
  static const selected = '已选';
  static const checkSelected = '检测选中';
  static const exportSelected = '导出选中';
  static const deleteSelected = '删除选中';
  static const confirmDelete = '确认删除';
  static const addSource = '添加源';
  static const editSource = '编辑源';
  static const sourceName = '源名称';
  static const sourceUrl = '源地址';
  static const lastChecked = '检测';
  // Export dialog
  static const selectExportSources = '选择要导出的源';
  static const exportCount = '导出选中';
  static const saveTo = '保存位置';
  // TVBOX
  static const tvboxSubscribe = 'TVBOX订阅导入';
  static const tvboxSubscribeUrl = '订阅链接';
  static const tvboxSubscribeHint = 'https://example.com/zy.json';
  static const tvboxImporting = '正在解析并检测源...';
  static const tvboxImportStart = '开始导入';
  static const tvboxImportNoValidSource = '未找到有效的源地址';
  static const tvboxParseError = '解析失败，请检查链接是否正确';

  // History
  static const clearHistory = '清空记录';
  static const confirmClearHistory = '确定要清空所有浏览记录吗？此操作不可恢复。';

  // Video Player
  static const videoInfo = '视频信息';
  static const noVideoInfo = '暂无法获取视频信息';
  static const resolution = '分辨率';
  static const videoCodec = '视频编码';
  static const pixelFormat = '像素格式';
  static const audioCodec = '音频编码';
  static const sampleRate = '采样率';
  static const channels = '声道';
  static const audioBitrate = '音频码率';
  static const duration = '时长';

  static String formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return justNow;
    if (diff.inHours < 1) return '${diff.inMinutes}$minutesAgo';
    if (diff.inDays < 1) return '${diff.inHours}$hoursAgo';
    if (diff.inDays < 7) return '${diff.inDays}$daysAgo';
    return '${dt.month}-${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String formatEpisodeCount(int count) => '选集 ($count集)';
  static String formatChannelCount(int count) => '频道列表 ($count)';
  static String formatSelectedCount(int count) => '已选 $count 个';
  static String formatDeleteCount(int count) => '确定要删除 $count 个源吗？';
  static String formatImportResult(int added, int updated, int failed) =>
      '导入完成：新增 $added 个，覆盖 $updated 个，跳过(不可用) $failed 个';
  static String formatExportResult(int added, int skipped) =>
      '导入完成：新增 $added 个，跳过重复 $skipped 个';
  static String formatExportedTo(int count, String path) =>
      '已导出 $count 个源到:\n$path';
  static String formatCheckResult(String name, bool ok) =>
      '$name: ${ok ? "✓ 可用" : "✗ 不可用"}';
  static String formatSourceLabel(String sourceName) => '源: $sourceName';
  static String formatEpisodeLabel(String epName) => '集数: $epName';
  static String formatDirector(String name) => '导演: $name';
  static String formatActor(String name) => '演员: $name';
  static String formatTvboxResult(int added, int updated, int failed) =>
      'TVBOX导入完成：新增 $added 个，覆盖 $updated 个，不可用跳过 $failed 个';
}
