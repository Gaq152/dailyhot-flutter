/// HTML 文本处理工具
class HtmlUtils {
  /// 移除 HTML 标签
  static String removeHtmlTags(String html) {
    if (html.isEmpty) return html;

    // 移除所有 HTML 标签
    String result = html.replaceAll(RegExp(r'<[^>]*>'), '');

    // 解码常见的 HTML 实体
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&hellip;', '...')
        .replaceAll('&mdash;', '—');

    // 移除多余空白
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}
