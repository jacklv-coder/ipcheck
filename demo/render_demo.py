#!/usr/bin/env python3
"""Render English and Chinese README GIFs from the real ipcheck CLI.

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
WIDTH, HEIGHT = 1200, 720
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


def demo_output(language: str) -> list[str]:
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
  printf '200\\t1000000\\t2000000'
elif [ "$is_download" -eq 1 ]; then
  printf '200\\t2000000\\t10000000'
elif [ "$is_claude" -eq 1 ]; then
  printf '403\\t0.020\\t0.040\\t0.060\\t0.220\\t0.240\\t151\\t1000'
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
            }
        )
        process = subprocess.run(
            [str(ROOT / "bin" / "ipcheck"), "all", "--samples", "1", "--no-color", "--explain-score"],
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
                "开发建议",
                "  现在适合开发吗？",
                "  开发适配分：",
                "  评分依据：",
                "  当前网络",
                "检测到的客户端",
                "  Codex",
                "  Claude Code",
                "AI 服务延迟",
                "  首字节延迟",
                "  正常",
                "AI 服务结论",
                "网络带宽",
                "  下载",
                "  上传",
                "  建议",
                "结果：",
                "说明：",
            )
        else:
            report_prefixes = (
                "ipcheck v",
                "Developer verdict",
                "  Ready to code?",
                "  Readiness score:",
                "  Score breakdown:",
                "  This network",
                "Detected clients",
                "  Codex",
                "  Claude Code",
                "AI service latency",
                "  Time to first byte",
                "  OK",
                "AI service results",
                "Network bandwidth",
                "  Download",
                "  Upload",
                "  Advice",
                "Result:",
                "Interpretation:",
            )
        report = [line for line in process.stdout.splitlines() if line.startswith(report_prefixes)]
        return [ANSI_RE.sub("", line).removeprefix("⌨ ") for line in progress + report]


def line_color(line: str) -> str:
    if any(token in line for token in ("100/100", "GOOD", "FAST", "Ready to code? YES", "适合", "舒适", " 快 ")):
        return GREEN
    if line.startswith(("Developer verdict", "Detected clients", "AI service latency", "AI service results", "Network bandwidth", "开发建议", "检测到的客户端", "AI 服务延迟", "AI 服务结论", "网络带宽")):
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

    max_lines = 24
    visible = lines[-max_lines:]
    y = 138
    for line in visible:
        clipped = clip_line(draw, line, body_font)
        draw.text((48, y), clipped, font=body_font, fill=line_color(clipped))
        y += 23
    return image


def render_demo(language: str) -> None:
    output = demo_output(language)
    command = "ipcheck --lang zh --explain-score" if language == "zh" else "ipcheck --explain-score"
    frames: list[Image.Image] = []
    durations: list[int] = []

    for index in range(0, len(command) + 1, 2):
        frames.append(frame(command[:index] + ("▋" if index < len(command) else ""), [], language))
        durations.append(80)
    frames.append(frame(command, [], language))
    durations.append(350)

    for index in range(1, len(output) + 1):
        frames.append(frame(command, output[:index], language))
        durations.append(95 if output[index - 1] else 45)
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
    print(f"Rendered {output_path} ({output_path.stat().st_size / 1024:.0f} KiB, {len(frames)} frames)")


def main() -> None:
    for language in OUTPUTS:
        render_demo(language)


if __name__ == "__main__":
    main()
