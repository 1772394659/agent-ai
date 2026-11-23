import json
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CFG = ROOT / "config.json"
REPORT = ROOT / "artifacts" / "friend_name_report.txt"


def describe(value: str) -> str:
    lines = []
    lines.append("长度=%d  strip后长度=%d  首尾有无空白=%s" % (
        len(value), len(value.strip()), "是" if value != value.strip() else "否"))
    for index, ch in enumerate(value):
        code = ord(ch)
        category = unicodedata.category(ch)
        try:
            label = unicodedata.name(ch)
        except ValueError:
            label = "UNNAMED"
        flags = []
        if ch.isspace():
            flags.append("空白字符")
        if category.startswith("C"):
            flags.append("控制/格式字符-高风险")
        if code > 0xFFFF:
            flags.append("emoji或增补平面字符")
        if code in (0x200B, 0x200C, 0x200D, 0xFEFF, 0x00A0):
            flags.append("零宽或不换行空格-高风险")
        if 0xFF01 <= code <= 0xFF5E:
            flags.append("全角字符")
        lines.append("  [%d] U+%04X  %s  %s  %s" % (
            index, code, repr(ch), label, ("::" + ",".join(flags)) if flags else ""))
    return "\n".join(lines)


def report(text: str) -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(text, encoding="utf-8")


def load_names() -> list[str]:
    cfg = json.loads(CFG.read_text(encoding="utf-8"))
    friends = cfg.get("friends")
    if isinstance(friends, list) and friends:
        return [str(x) for x in friends]
    targets = cfg.get("targets", [])
    return [str(x.get("name", "")) for x in targets if isinstance(x, dict)]


def check() -> None:
    names = load_names()
    chunks = ["模式: check", "config.json: %s" % CFG, "好友数: %d" % len(names), ""]
    for name in names:
        chunks.append("=== %r ===" % name)
        chunks.append(describe(name))
        chunks.append("")
    chunks.append("匹配规则: 程序用 inner_text().strip() 与上述字符串做严格相等比较。")
    chunks.append("网页版显示名必须与之逐字符一致（emoji、空格、全半角、群聊人数后缀都算差异）。")
    report("\n".join(chunks))
    print("check written")


def set_names(names: list[str]) -> None:
    cfg = json.loads(CFG.read_text(encoding="utf-8"))
    old = cfg.get("friends")
    cfg.pop("targets", None)
    cfg["friends"] = names
    CFG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    back = json.loads(CFG.read_text(encoding="utf-8"))
    chunks = ["模式: set", "原值: %r" % (old,), "写入值: %r" % (names,), ""]
    chunks.append("回读一致: %s" % (back.get("friends") == names))
    chunks.append("文件编码: UTF-8 无 BOM（ensure_ascii=False）")
    chunks.append("")
    for name in names:
        chunks.append("=== %r ===" % name)
        chunks.append(describe(name))
        chunks.append("")
    report("\n".join(chunks))
    print("set written")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: friend_name.py check | set <name> [name...]")
        raise SystemExit(2)
    mode = sys.argv[1]
    if mode == "check":
        check()
    elif mode == "set":
        args = sys.argv[2:]
        if not args:
            print("set requires at least one name")
            raise SystemExit(2)
        set_names(args)
    else:
        print("unknown mode")
        raise SystemExit(2)
