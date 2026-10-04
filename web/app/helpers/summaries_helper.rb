module SummariesHelper
  MARKDOWN = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(escape_html: true, safe_links_only: true, hard_wrap: true),
    autolink: true, tables: true, fenced_code_blocks: true, strikethrough: true
  )

  def format_timestamp(seconds) = Timestamp.clock(seconds)

  # Model output is untrusted: HTML inside the markdown is escaped, not rendered.
  def render_markdown(text) = MARKDOWN.render(text.to_s).html_safe
end
