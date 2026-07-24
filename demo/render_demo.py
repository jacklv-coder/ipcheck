#!/usr/bin/env python3
"""Render healthy-to-limited English and Chinese demos from the real CLI.

Requires Python 3, Pillow, and a CJK font for the Chinese demo. No live service
or credential is used.
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    "en": ROOT / "assets" / "ipcheck-demo.gif",
    "zh": ROOT / "assets" / "ipcheck-demo-zh.gif",
}
SCREENSHOTS = {
    "en": ROOT / "assets" / "ipcheck-preview.png",
    "zh": ROOT / "assets" / "ipcheck-preview-zh.png",
}
WIDTH, HEIGHT = 1200, 810
BACKGROUND = "#0d1117"
PANEL = "#161b22"
TEXT = "#c9d1d9"
MUTED = "#8b949e"
GREEN = "#3fb950"
YELLOW = "#d29922"
CYAN = "#58a6ff"
RED = "#f85149"
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


@lru_cache(maxsize=None)
def font(size: int, language: str, bold: bool = False) -> ImageFont.FreeTypeFont:
    if language == "zh":
        candidates = [
            Path("/System/Library/Fonts/Supplemental/Arial Unicode.ttf"),
            Path("/System/Library/Fonts/PingFang.ttc"),
            Path("/System/Library/Fonts/Hiragino Sans GB.ttc"),
            Path("/System/Library/Fonts/STHeiti Medium.ttc"),
            Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
            Path("/usr/share/fonts/opentype/noto/NotoSansCJKsc-Regular.otf"),
            Path("/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"),
        ]
    else:
        candidates = [
            Path("/System/Library/Fonts/Menlo.ttc"),
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
        ]
    for candidate in candidates:
        if candidate.exists():
            index = 1 if language == "en" and bold and candidate.suffix == ".ttc" else 0
            return ImageFont.truetype(str(candidate), size=size, index=index)
    if language == "zh":
        raise RuntimeError(
            "Chinese demo requires a CJK font (PingFang, Hiragino Sans GB, "
            "STHeiti, Noto Sans CJK, or WenQuanYi Micro Hei)."
        )
    return ImageFont.load_default()


def demo_output(language: str, scenario: str) -> list[str]:
    with tempfile.TemporaryDirectory(prefix="ipcheck-demo-") as directory:
        fixture = Path(directory)
        home = fixture / "home"
        codex = home / ".codex"
        claude = home / ".claude"
        codex.mkdir(parents=True)
        claude.mkdir(parents=True)
        (codex / "config.toml").write_text('model = "gpt-5.6-sol"\n', encoding="utf-8")
        (claude / "settings.json").write_text(
            '{"env":{"ANTHROPIC_BASE_URL":"https://dashscope.aliyuncs.com/apps/anthropic",'
            '"ANTHROPIC_MODEL":"deepseek-v4-flash"}}\n',
            encoding="utf-8",
        )
        curl = fixture / "curl"
        curl.write_text(
            """#!/usr/bin/env bash
is_download=0
is_upload=0
is_claude=0
for argument in "$@"; do
  case "$argument" in
    *__down*) is_download=1 ;;
    *__up*) is_upload=1 ;;
    */v1/messages) is_claude=1 ;;
  esac
done
if [ "$is_upload" -eq 1 ]; then
  if [ "${IPCHECK_DEMO_SCENARIO-}" = "limited" ]; then
    printf '200\\t1000000\\t425000'
  else
    printf '200\\t1000000\\t2000000'
  fi
elif [ "$is_download" -eq 1 ]; then
  if [ "${IPCHECK_DEMO_SCENARIO-}" = "limited" ]; then
    printf '200\\t2000000\\t400000'
  else
    printf '200\\t2000000\\t10000000'
  fi
elif [ "$is_claude" -eq 1 ]; then
  printf '403\\t0.020\\t0.040\\t0.060\\t0.220\\t0.240\\t151\\t1000'
elif [ "${IPCHECK_DEMO_SCENARIO-}" = "limited" ]; then
  printf '401\\t0.080\\t0.180\\t0.320\\t4.881\\t5.100\\t151\\t1000'
else
  printf '401\\t0.020\\t0.040\\t0.060\\t0.260\\t0.280\\t151\\t1000'
fi
""",
            encoding="utf-8",
        )
        curl.chmod(0o755)
        environment = os.environ.copy()
        for key in (
            "ANTHROPIC_AUTH_TOKEN",
            "ANTHROPIC_API_KEY",
            "ANTHROPIC_BASE_URL",
            "ANTHROPIC_MODEL",
            "OPENAI_API_KEY",
            "CODEX_API_KEY",
            "CODEX_NETWORK_ENDPOINTS",
            "CLAUDE_NETWORK_ENDPOINTS",
            "IPCHECK_ENDPOINTS",
            "IPCHECK_SERVICES",
            "HTTP_PROXY",
            "http_proxy",
            "https_proxy",
            "ALL_PROXY",
            "all_proxy",
        ):
            environment.pop(key, None)
        environment.update(
            {
                "PATH": f"{fixture}{os.pathsep}{environment['PATH']}",
                "HOME": str(home),
                "CODEX_HOME": str(codex),
                "CLAUDE_CONFIG_DIR": str(claude),
                "HTTPS_PROXY": "http://127.0.0.1:1080",
                "IPCHECK_LANG": language,
                "IPCHECK_PROGRESS": "always",
                "IPCHECK_DEMO_SCENARIO": scenario,
                "COLUMNS": "100",
            }
        )
        process = subprocess.run(
            [str(ROOT / "bin" / "ipcheck"), "all", "--samples", "1", "--no-color"],
            cwd=ROOT,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        progress = [line for line in process.stderr.splitlines() if "Ctrl+C" in line]
        if language == "zh":
            report_prefixes = (
                "ipcheck v",
                "━",
                "─",
                "  ✓  现在适合开发吗？",
                "  ✕  现在适合开发吗？",
                "  100/100",
                "  9",
                "  8",
                "  7",
                "  6",
                "  5",
                "  4",
                "  3",
                "  2",
                "  1",
                "  0/100",
                "  █",
                "  AI 交互",
                "  评分构成",
                "    AI 交互",
                "    下行工程传输",
                "    上行工程传输",
                "  当前网络",
                "  可以正常开发",
                "  建议先",
                "  !",
                "◆ 检测到的客户端",
                "  Codex",
                "  Claude Code",
                "◆ AI 服务延迟",
                "  TTFB",
                "  ✓ 可达",
                "    HTTP",
                "◆ AI 服务结论",
                "  ●",
                "◆ 代理链路参考传输",
                "  下行样本",
                "  上行样本",
                "  范围",
                "  建议",
            )
        else:
            report_prefixes = (
                "ipcheck v",
                "━",
                "─",
                "  ✓  Ready to code?",
                "  ✕  Ready to code?",
                "  100/100",
                "  9",
                "  8",
                "  7",
                "  6",
                "  5",
                "  4",
                "  3",
                "  2",
                "  1",
                "  0/100",
                "  █",
                "  AI interaction",
                "  Score breakdown",
                "    AI interaction",
                "    Download engineering",
                "    Upload engineering",
                "  This network",
                "  You can work normally",
                "  Switch proxy routes",
                "  !",
                "◆ Detected clients",
                "  Codex",
                "  Claude Code",
                "◆ AI service latency",
                "  TTFB",
                "  ✓ REACH",
                "    HTTP",
                "◆ AI service results",
                "  ●",
                "◆ Proxy-path reference transfer",
                "  Down sample",
                "  Up sample",
                "  Scope",
                "  Advice",
            )
        report = [line for line in process.stdout.splitlines() if line.startswith(report_prefixes)]
        return [ANSI_RE.sub("", line).removeprefix("⌨ ") for line in progress + report]


def line_color(line: str) -> str:
    score_match = re.search(r"\b(\d+)/100\b", line)
    if score_match:
        score = int(score_match.group(1))
        return GREEN if score >= 90 else YELLOW if score >= 65 else RED
    if any(token in line for token in ("Ready to code? YES", "现在适合开发吗？适合")):
        return GREEN
    if line.startswith(("◆ Detected clients", "◆ AI service latency", "◆ AI service results", "◆ Proxy-path reference transfer", "◆ 检测到的客户端", "◆ AI 服务延迟", "◆ AI 服务结论", "◆ 代理链路参考传输", "ipcheck v")):
        return CYAN
    if line.startswith(("Checking", "Press Ctrl+C", "按 Ctrl+C")):
        return MUTED
    if "!" in line or "WARNING" in line or "注意" in line:
        return YELLOW
    if "BLOCKED" in line or "POOR" in line or "阻断" in line or "较差" in line:
        return RED
    return TEXT


def clip_line(draw: ImageDraw.ImageDraw, line: str, body_font: ImageFont.ImageFont) -> str:
    if draw.textlength(line, font=body_font) <= WIDTH - 96:
        return line
    clipped = line
    while clipped and draw.textlength(clipped + "...", font=body_font) > WIDTH - 96:
        clipped = clipped[:-1]
    return clipped + "..."


def wrap_lines(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    body_font: ImageFont.ImageFont,
) -> list[str]:
    wrapped: list[str] = []
    max_width = WIDTH - 96
    for original in lines:
        if original and set(original) in ({"━"}, {"─"}):
            wrapped.append(original)
            continue
        line = original
        indent = line[: len(line) - len(line.lstrip())]
        while draw.textlength(line, font=body_font) > max_width:
            split_at = len(line)
            while split_at > len(indent) and draw.textlength(line[:split_at], font=body_font) > max_width:
                split_at -= 1
            word_break = line.rfind(" ", len(indent) + 1, split_at)
            if word_break > len(indent) + 12:
                split_at = word_break
            wrapped.append(line[:split_at].rstrip())
            line = f"{indent}  {line[split_at:].lstrip()}"
        wrapped.append(line)
    return wrapped


def draw_status_line(
    draw: ImageDraw.ImageDraw,
    line: str,
    position: tuple[int, int],
    body_font: ImageFont.ImageFont,
) -> bool:
    dot_color = GREEN
    if any(token in line for token in ("POOR", "BLOCKED", "较差", "阻断")):
        dot_color = RED
    elif any(token in line for token in ("FAIR", "一般")):
        dot_color = YELLOW
    colors = {"✓": GREEN, "●": dot_color, "✕": RED, "!": YELLOW}
    if not any(symbol in line for symbol in colors):
        return False
    x, y = position
    for segment in re.split(r"([✓●✕!])", line):
        if not segment:
            continue
        draw.text((x, y), segment, font=body_font, fill=colors.get(segment, TEXT))
        x += int(draw.textlength(segment, font=body_font))
    return True


def frame(command: str, lines: list[str], language: str) -> Image.Image:
    body_font = font(21, language)
    body_bold = font(21, language, bold=True)
    title_font = font(17, language, bold=True)
    image = Image.new("RGB", (WIDTH, HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((22, 18, WIDTH - 22, HEIGHT - 18), radius=16, fill=PANEL, outline="#30363d", width=2)
    draw.ellipse((48, 42, 66, 60), fill="#ff5f56")
    draw.ellipse((76, 42, 94, 60), fill="#ffbd2e")
    draw.ellipse((104, 42, 122, 60), fill="#27c93f")
    title = "ipcheck — 终端" if language == "zh" else "ipcheck — terminal"
    draw.text((WIDTH // 2, 51), title, font=title_font, fill=MUTED, anchor="mm")
    draw.line((44, 78, WIDTH - 44, 78), fill="#30363d", width=1)
    draw.text((48, 98), "$", font=body_bold, fill=GREEN)
    draw.text((76, 98), command, font=body_font, fill=TEXT)

    max_lines = 28
    wrapped = wrap_lines(draw, lines, body_font)
    if len(wrapped) > max_lines:
        visible = wrapped[:10] + ["  ⋯"] + wrapped[-17:]
    else:
        visible = wrapped
    score_color = GREEN
    for candidate in lines:
        score_match = re.search(r"\b(\d+)/100\b", candidate)
        if score_match:
            score = int(score_match.group(1))
            score_color = GREEN if score >= 90 else YELLOW if score >= 65 else RED
    y = 138
    for line in visible:
        if line and set(line) in ({"━"}, {"─"}):
            draw.line((48, y + 10, WIDTH - 48, y + 10), fill=MUTED, width=2)
            y += 23
            continue
        clipped = clip_line(draw, line, body_font)
        if clipped.strip().startswith(("█", "░")):
            draw.text((48, y), clipped, font=body_font, fill=score_color)
            y += 23
            continue
        if not draw_status_line(draw, clipped, (48, y), body_font):
            draw.text((48, y), clipped, font=body_font, fill=line_color(clipped))
        y += 23
    return image


def render_demo(language: str) -> None:
    healthy_output = demo_output(language, "healthy")
    limited_output = demo_output(language, "limited")
    command = "ipcheck --lang zh" if language == "zh" else "ipcheck"
    frames: list[Image.Image] = []
    durations: list[int] = []

    for index in range(0, len(command) + 1, 2):
        frames.append(frame(command[:index] + ("▋" if index < len(command) else ""), [], language))
        durations.append(80)
    frames.append(frame(command, [], language))
    durations.append(350)

    for index in range(1, len(healthy_output) + 1):
        frames.append(frame(command, healthy_output[:index], language))
        durations.append(85 if healthy_output[index - 1] else 45)
    durations[-1] = 1800

    frames.append(frame(command, [], language))
    durations.append(450)
    for index in range(1, len(limited_output) + 1):
        frames.append(frame(command, limited_output[:index], language))
        durations.append(85 if limited_output[index - 1] else 45)
    durations[-1] = 3200

    output_path = OUTPUTS[language]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=1,
    )
    screenshot_path = SCREENSHOTS[language]
    frame(command, limited_output, language).save(screenshot_path, optimize=True)
    print(f"Rendered {output_path} ({output_path.stat().st_size / 1024:.0f} KiB, {len(frames)} frames)")
    print(f"Rendered {screenshot_path} ({screenshot_path.stat().st_size / 1024:.0f} KiB)")


def main() -> None:
    for language in OUTPUTS:
        render_demo(language)


if __name__ == "__main__":
    main()
