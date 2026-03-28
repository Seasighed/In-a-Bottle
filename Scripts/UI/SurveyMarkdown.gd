class_name SurveyMarkdown
extends RefCounted

static func to_bbcode(markdown_text: String) -> String:
	var source := markdown_text.replace("\r\n", "\n").replace("\r", "\n")
	if source.strip_edges().is_empty():
		return "[i]No additional notes were provided for this question.[/i]"

	var output_lines: Array[String] = []
	var in_code_block := false
	for raw_line in source.split("\n", false):
		var trimmed := raw_line.strip_edges()
		if trimmed.begins_with("```"):
			output_lines.append("[/code]" if in_code_block else "[code]")
			in_code_block = not in_code_block
			continue
		if in_code_block:
			output_lines.append(_escape_bbcode(raw_line))
			continue
		if trimmed.begins_with("# "):
			output_lines.append("[b][font_size=22]%s[/font_size][/b]" % _parse_inline_markdown(trimmed.substr(2)))
			continue
		if trimmed.begins_with("## "):
			output_lines.append("[b][font_size=18]%s[/font_size][/b]" % _parse_inline_markdown(trimmed.substr(3)))
			continue
		if trimmed.begins_with("### "):
			output_lines.append("[b]%s[/b]" % _parse_inline_markdown(trimmed.substr(4)))
			continue
		if trimmed.begins_with("- ") or trimmed.begins_with("* "):
			output_lines.append("• %s" % _parse_inline_markdown(trimmed.substr(2)))
			continue
		if trimmed.begins_with("> "):
			output_lines.append("[i]%s[/i]" % _parse_inline_markdown(trimmed.substr(2)))
			continue
		output_lines.append(_parse_inline_markdown(raw_line))
	if in_code_block:
		output_lines.append("[/code]")
	return "\n".join(output_lines)

static func _parse_inline_markdown(text: String) -> String:
	var parsed := _escape_bbcode(text)
	parsed = _replace_regex(parsed, "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", "[url=$2]$1[/url]")
	parsed = _replace_regex(parsed, "`([^`]+)`", "[code]$1[/code]")
	parsed = _replace_regex(parsed, "\\*\\*([^*]+)\\*\\*", "[b]$1[/b]")
	parsed = _replace_regex(parsed, "__([^_]+)__", "[b]$1[/b]")
	parsed = _replace_regex(parsed, "(?<!\\*)\\*([^*]+)\\*(?!\\*)", "[i]$1[/i]")
	parsed = _replace_regex(parsed, "(?<!_)_([^_]+)_(?!_)", "[i]$1[/i]")
	return parsed

static func _replace_regex(source: String, pattern: String, replacement: String) -> String:
	var regex := RegEx.new()
	var compile_error := regex.compile(pattern)
	if compile_error != OK:
		return source
	return regex.sub(source, replacement, true)

static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")
