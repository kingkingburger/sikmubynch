"""AI 생성 이미지 → 게임 스프라이트 임포터.

원본(assets_src/)에 넣은 PNG/JPG를 게임 규격(project/assets/sprites/)으로 정리한다.
  - 배경 제거: 알파가 있으면 그대로, 없으면 모서리 색을 크로마키로 뺀다 (마젠타·흰색·검정 등 단색 배경)
  - 여백 자르기, 규격 크기로 리사이즈(LANCZOS), 발 위치 앵커 정렬
  - 적: 정사각 캔버스, 몸통은 위 78%, 바닥에 그림자 타원 베이크 (렌더러 레이아웃과 동일)
  - 적 시트: <이름>_sheet.png (한 줄에 포즈 4개: 걷기A, 걷기B, 물기 준비, 물기)가 있으면 그것을 우선 쓴다.
    마젠타 틈으로 포즈를 나눠 같은 배율로 맞추고, 정사각 셀을 가로로 이어 붙인 스트립을 만든다.
    렌더러는 가로/세로 비율로 프레임 수를 안다 (1이면 정지 이미지).
  - 건물: 가로 폭 기준 리사이즈, 캔버스 바닥 중앙 = 발자국 마름모 아래 꼭짓점
  - 지면: 1024×1024로 맞추고 가장자리를 교차 페이드해 이음새를 줄인다

사용: uv run import_sprites.py            (assets_src/ 전체)
      uv run import_sprites.py rusher hq  (이름 지정)
원본 파일명은 아래 SPEC의 키와 같아야 한다 (확장자 png/jpg/webp).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).parent.parent
SRC = ROOT / "assets_src"
OUT = ROOT / "project" / "assets" / "sprites"

# 이름 → (카테고리, 규격). 크기는 줌 1.0 기준 픽셀.
#   enemy:    size = 정사각 캔버스 한 변. 렌더러가 캔버스 크기를 그대로 쓴다
#   building: width = 스프라이트 가로 폭(1칸 = 64px 마름모보다 조금 넓게), tiles = 발자국 한 변
#   ground:   seamless 1024×1024
SPEC = {
    "rusher":   {"cat": "enemy", "size": 38},
    "mini":     {"cat": "enemy", "size": 22},
    "splitter": {"cat": "enemy", "size": 42},
    "tank":     {"cat": "enemy", "size": 58},
    # 건물 원본은 받침판이 가장 넓다. 받침판 폭 = 발자국(1칸 64px, 3칸 192px)보다 약간 크게 잡아 칸을 덮는 느낌을 낸다
    "hq":       {"cat": "building", "width": 212, "tiles": 3},
    "barricade": {"cat": "building", "width": 72, "tiles": 1},
    "wall":     {"cat": "building", "width": 72, "tiles": 1},
    "gun_tower": {"cat": "building", "width": 72, "tiles": 1},
    "cannon_tower": {"cat": "building", "width": 76, "tiles": 1},
    "frost_tower": {"cat": "building", "width": 72, "tiles": 1},
    "flame_tower": {"cat": "building", "width": 72, "tiles": 1},
    "tesla_tower": {"cat": "building", "width": 72, "tiles": 1},
    "sniper_tower": {"cat": "building", "width": 72, "tiles": 1},
    "ground":   {"cat": "ground", "size": 1024},
}

CHROMA_TOLERANCE = 60      # 배경색과의 거리(0~441). 크면 더 많이 뺀다
EDGE_SOFTEN = 1.0          # 키잉 후 가장자리 부드럽게
SHADOW_ALPHA = 0.45
SHEET_GAP_MIN = 6          # 시트에서 포즈를 나누는 빈 열의 최소 폭(px)
SHEET_MIN_FRAME_FRAC = 0.04  # 이보다 좁은 조각은 노이즈로 보고 버린다 (전체 폭 대비)
ENEMY_MIN_MEAN_LUM = 80.0  # 적 몸통 평균 밝기 하한(0~255). 어두운 지면에 묻히지 않게 끌어올린다
ENEMY_MAX_GAIN = 1.8


def find_source(name: str) -> Path | None:
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        p = SRC / f"{name}{ext}"
        if p.exists():
            return p
    return None


def find_sheet(name: str) -> Path | None:
    return find_source(f"{name}_sheet")


def has_real_alpha(img: Image.Image) -> bool:
    if img.mode != "RGBA":
        return False
    a = img.getchannel("A")
    lo, hi = a.getextrema()
    return lo < 250


def chroma_key(img: Image.Image) -> Image.Image:
    """모서리 4곳의 평균색을 배경으로 보고 거리 기반 알파를 만든다.
    반투명 가장자리는 배경색 기여분을 빼서(despill) 핑크 테두리를 없앤다."""
    rgb = np.asarray(img.convert("RGB"), dtype=np.float32)
    h, w, _ = rgb.shape
    corners = np.stack([rgb[0, 0], rgb[0, w - 1], rgb[h - 1, 0], rgb[h - 1, w - 1]])
    bg = corners.mean(axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    tol = float(CHROMA_TOLERANCE)
    alpha = np.clip((dist - tol) / tol, 0.0, 1.0)
    # despill: c = a*fg + (1-a)*bg → fg = (c - (1-a)*bg) / a
    a3 = alpha[..., None]
    safe = np.where(a3 > 0.02, a3, 1.0)
    fg = np.where(a3 > 0.02, (rgb - (1.0 - a3) * bg) / safe, rgb)
    fg = np.clip(fg, 0.0, 255.0)
    out = np.concatenate([fg, alpha[..., None] * 255.0], axis=2).astype(np.uint8)
    result = Image.fromarray(out, "RGBA")
    if EDGE_SOFTEN > 0:
        soft = result.getchannel("A").filter(ImageFilter.GaussianBlur(EDGE_SOFTEN))
        result.putalpha(soft)
    return result


def load_cutout(path: Path) -> Image.Image:
    img = Image.open(path)
    img = img.convert("RGBA") if img.mode in ("RGBA", "LA", "P") else img.convert("RGB")
    if isinstance(img, Image.Image) and has_real_alpha(img):
        cut = img
    else:
        cut = chroma_key(img)
    bbox = cut.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError(f"{path.name}: 배경 제거 후 남는 픽셀이 없다 (배경색 톨러런스 확인)")
    return cut.crop(bbox)


def fit_into(img: Image.Image, max_w: int, max_h: int) -> Image.Image:
    scale = min(max_w / img.width, max_h / img.height)
    size = (max(1, int(round(img.width * scale))), max(1, int(round(img.height * scale))))
    return img.resize(size, Image.LANCZOS)


def bake_shadow(canvas: Image.Image, cx: float, cy: float, rx: float, ry: float) -> None:
    """바닥 그림자 타원 (렌더러 폴백과 같은 규칙). 몸통을 그리기 전 빈 캔버스에 넣는다."""
    w, h = canvas.size
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    sx = (xs + 0.5 - cx) / rx
    sy = (ys + 0.5 - cy) / ry
    d = sx * sx + sy * sy
    a = np.where(d <= 1.0, SHADOW_ALPHA * (1.0 - d * 0.5), 0.0)
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[..., 3] = (a * 255.0).astype(np.uint8)
    canvas.paste(Image.fromarray(arr, "RGBA"))


def lift_brightness(img: Image.Image, min_mean: float, max_gain: float) -> Image.Image:
    """불투명 픽셀의 평균 밝기가 하한보다 낮으면 RGB를 균일하게 키운다 (색조 유지)."""
    a = np.asarray(img.convert("RGBA"), dtype=np.float32)
    body = a[..., 3] > 200
    if body.sum() == 0:
        return img
    rgb = a[body][:, :3]
    lum = (0.2126 * rgb[:, 0] + 0.7152 * rgb[:, 1] + 0.0722 * rgb[:, 2]).mean()
    if lum >= min_mean:
        return img
    gain = min(max_gain, min_mean / max(lum, 1.0))
    a[..., :3] = np.clip(a[..., :3] * gain, 0.0, 255.0)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _enemy_cell(body: Image.Image, size: int) -> Image.Image:
    """정사각 셀 하나: 그림자 + 바닥 정렬된 몸통 (몸통은 이미 규격에 맞게 리사이즈된 상태)."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bake_shadow(canvas, size * 0.5, size * 0.86, size * 0.36, size * 0.13)
    x = (size - body.width) // 2
    y = int(size * 0.80) - body.height
    canvas.alpha_composite(body, (max(0, x), max(0, y)))
    return canvas


def split_sheet(cut: Image.Image) -> list[Image.Image]:
    """배경을 뺀 시트를 빈 열(알파 0) 기준으로 가로 조각으로 나눈다. 각 조각은 bbox로 자른다."""
    a = np.asarray(cut.getchannel("A"))
    occupied = (a > 30).any(axis=0)
    w = occupied.size
    segments: list[tuple[int, int]] = []
    start = None
    gap = 0
    for x in range(w):
        if occupied[x]:
            if start is None:
                start = x
            gap = 0
        else:
            if start is not None:
                gap += 1
                if gap >= SHEET_GAP_MIN:
                    segments.append((start, x - gap + 1))
                    start = None
                    gap = 0
    if start is not None:
        segments.append((start, w))
    min_w = int(w * SHEET_MIN_FRAME_FRAC)
    segments = [(s, e) for s, e in segments if e - s >= min_w]
    frames = []
    for s, e in segments:
        piece = cut.crop((s, 0, e, cut.height))
        bbox = piece.getchannel("A").getbbox()
        if bbox:
            frames.append(piece.crop(bbox))
    return frames


def import_enemy(name: str, src: Path, size: int, sheet: Path | None = None) -> Path:
    out = OUT / "enemies" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    if sheet is None:
        cut = lift_brightness(load_cutout(src), ENEMY_MIN_MEAN_LUM, ENEMY_MAX_GAIN)
        body = fit_into(cut, int(size * 0.80), int(size * 0.78))
        _enemy_cell(body, size).save(out)
        return out
    # 시트: 포즈를 나누고 모든 포즈에 같은 배율을 써서 크기가 튀지 않게 한다
    cut = lift_brightness(load_cutout(sheet), ENEMY_MIN_MEAN_LUM, ENEMY_MAX_GAIN)
    frames = split_sheet(cut)
    if len(frames) < 2:
        raise ValueError(f"{sheet.name}: 포즈를 {len(frames)}개밖에 못 나눴다 (포즈 사이 마젠타 틈이 필요)")
    max_w = max(f.width for f in frames)
    max_h = max(f.height for f in frames)
    scale = min(int(size * 0.80) / max_w, int(size * 0.78) / max_h)
    strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        body = f.resize((max(1, int(round(f.width * scale))), max(1, int(round(f.height * scale)))), Image.LANCZOS)
        strip.alpha_composite(_enemy_cell(body, size), (k * size, 0))
    strip.save(out)
    return out


def import_building(name: str, src: Path, width: int, tiles: int) -> Path:
    cut = load_cutout(src)
    scale = width / cut.width
    body = cut.resize((width, max(1, int(round(cut.height * scale)))), Image.LANCZOS)
    # 캔버스: 가로 = width, 세로 = 몸통 높이. 바닥 중앙이 발자국 마름모 아래 꼭짓점.
    out = OUT / "buildings" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    body.save(out)
    return out


def import_ground(name: str, src: Path, size: int) -> Path:
    img = Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)
    # 이음새 줄이기: 반 칸 옮긴 사본과 가장자리 교차 페이드
    shifted = Image.new("RGB", (size, size))
    half = size // 2
    shifted.paste(img.crop((half, half, size, size)), (0, 0))
    shifted.paste(img.crop((0, half, half, size)), (half, 0))
    shifted.paste(img.crop((half, 0, size, half)), (0, half))
    shifted.paste(img.crop((0, 0, half, half)), (half, half))
    band = size // 6
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    d = np.minimum(np.minimum(xs, size - 1 - xs), np.minimum(ys, size - 1 - ys))
    m = np.where(d >= band, 0.0, 1.0 - d / band) * 255.0
    mask = Image.fromarray(m.astype(np.uint8), "L")
    blended = Image.composite(shifted, img, mask)
    out = OUT / "ground" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    blended.save(out)
    return out


def main() -> None:
    names = sys.argv[1:] or list(SPEC.keys())
    SRC.mkdir(parents=True, exist_ok=True)
    done = 0
    for name in names:
        spec = SPEC.get(name)
        if spec is None:
            print(f"  ? {name}: SPEC에 없는 이름")
            continue
        src = find_source(name)
        sheet = find_sheet(name) if spec["cat"] == "enemy" else None
        if src is None and sheet is None:
            if sys.argv[1:]:
                print(f"  - {name}: 원본 없음 ({SRC / (name + '.png')})")
            continue
        try:
            if spec["cat"] == "enemy":
                out = import_enemy(name, src, spec["size"], sheet)
                if sheet is not None:
                    src = sheet
            elif spec["cat"] == "building":
                out = import_building(name, src, spec["width"], spec["tiles"])
            else:
                out = import_ground(name, src, spec["size"])
        except Exception as exc:  # noqa: BLE001
            print(f"  ! {name}: {exc}")
            continue
        img = Image.open(out)
        frames = f", {img.width // img.height}프레임" if spec["cat"] == "enemy" and img.width > img.height else ""
        print(f"  ✓ {name}: {src.name} → {out.relative_to(ROOT)} ({img.width}×{img.height}{frames})")
        done += 1
    print(f"완료: {done}개. 이후 Godot에서 --headless --import 로 임포트한다.")


if __name__ == "__main__":
    main()
