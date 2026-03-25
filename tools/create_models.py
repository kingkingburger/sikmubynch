"""
SIKMUBYNCH 고품질 다크 판타지 3D 모델 생성 (trimesh)
각 모델 15-25+ 파트, Diablo 스타일 로우폴리 스타일리쉬

사용법: cd tools && uv run python create_models.py
"""
import numpy as np
import trimesh
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "project" / "assets" / "models"


# ===================================================================
# 공통 유틸
# ===================================================================

def make_material(color, metallic=0.0, roughness=0.7):
    from trimesh.visual.material import PBRMaterial
    c = np.array(list(color[:3]) + [1.0]) * 255
    return PBRMaterial(
        baseColorFactor=c.astype(np.uint8).tolist(),
        metallicFactor=metallic,
        roughnessFactor=roughness,
    )


def cm(mesh, color, metallic=0.0, roughness=0.7):
    """color_mesh 단축어"""
    mat = make_material(color, metallic, roughness)
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def combine(parts):
    valid = [p for p in parts if p is not None and len(p.faces) > 0]
    if not valid:
        return trimesh.creation.box(extents=[0.01, 0.01, 0.01])
    return trimesh.util.concatenate(valid)


def Rx(angle):
    return trimesh.transformations.rotation_matrix(angle, [1, 0, 0])

def Ry(angle):
    return trimesh.transformations.rotation_matrix(angle, [0, 1, 0])

def Rz(angle):
    return trimesh.transformations.rotation_matrix(angle, [0, 0, 1])


def box(size, pos=(0,0,0), rot=None, color=(0.5,0.5,0.5), metal=0.0, rough=0.7):
    m = trimesh.creation.box(extents=size)
    if rot is not None:
        m.apply_transform(rot)
    m.apply_translation(pos)
    return cm(m, color, metal, rough)


def cyl(r, h, pos=(0,0,0), rot=None, segs=8, color=(0.5,0.5,0.5), metal=0.0, rough=0.7):
    m = trimesh.creation.cylinder(radius=r, height=h, sections=segs)
    if rot is not None:
        m.apply_transform(rot)
    m.apply_translation(pos)
    return cm(m, color, metal, rough)


def cone(r, h, pos=(0,0,0), rot=None, segs=6, color=(0.5,0.5,0.5), metal=0.0, rough=0.7):
    m = trimesh.creation.cone(radius=r, height=h, sections=segs)
    if rot is not None:
        m.apply_transform(rot)
    m.apply_translation(pos)
    return cm(m, color, metal, rough)


def sphere(r, pos=(0,0,0), sub=1, color=(0.5,0.5,0.5), metal=0.0, rough=0.7):
    m = trimesh.creation.icosphere(subdivisions=sub, radius=r)
    m.apply_translation(pos)
    return cm(m, color, metal, rough)


def rivets(positions, r=0.012, color=(0.6,0.6,0.65), metal=0.7, rough=0.3):
    """리벳 구 리스트 생성"""
    parts = []
    for pos in positions:
        parts.append(sphere(r, pos, sub=0, color=color, metal=metal, rough=rough))
    return parts


def save_glb(mesh, category, name):
    out_dir = MODELS_DIR / category
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.glb"
    mesh.export(str(path), file_type="glb")
    size_kb = path.stat().st_size / 1024
    print(f"  {category}/{name}.glb ({size_kb:.0f}KB)")
    return path


# ===================================================================
# 색상 팔레트 (다크 판타지)
# ===================================================================

# 솔저: 다크 블루 스틸
STEEL_DARK   = (0.18, 0.22, 0.38)
STEEL_MID    = (0.25, 0.32, 0.52)
STEEL_LIGHT  = (0.40, 0.50, 0.72)
STEEL_RIVET  = (0.55, 0.60, 0.70)
BLADE_COLOR  = (0.75, 0.78, 0.85)
SKIN_COLOR   = (0.80, 0.65, 0.50)
LEATHER_DARK = (0.22, 0.15, 0.10)

# 아처: 포레스트 그린 + 브라운
HOOD_GREEN   = (0.12, 0.28, 0.14)
CLOAK_GREEN  = (0.15, 0.32, 0.17)
LEATHER_GRN  = (0.28, 0.22, 0.12)
BOW_WOOD     = (0.40, 0.28, 0.10)

# 탱커: 골드/브론즈
GOLD_DARK    = (0.45, 0.35, 0.10)
GOLD_MID     = (0.60, 0.48, 0.15)
GOLD_LIGHT   = (0.72, 0.60, 0.22)
GOLD_RIVET   = (0.80, 0.70, 0.30)

# 봄버: 레드/브라운 누더기
BOMBER_CLOTH = (0.38, 0.22, 0.12)
BOMBER_DARK  = (0.22, 0.12, 0.06)
BARREL_WOOD  = (0.28, 0.16, 0.06)
FUSE_SPARK   = (1.00, 0.55, 0.05)

# 러셔: 크림슨 고블린
GOBLIN_DARK  = (0.42, 0.06, 0.06)
GOBLIN_MID   = (0.60, 0.10, 0.10)
CLAW_COLOR   = (0.78, 0.68, 0.55)
EYE_GLOW     = (1.00, 0.15, 0.05)

# 탱크 적: 다크 퍼플 갑충
BEETLE_DARK  = (0.22, 0.10, 0.32)
BEETLE_MID   = (0.30, 0.15, 0.42)
BEETLE_LIGHT = (0.40, 0.22, 0.55)
SPIKE_COLOR  = (0.50, 0.28, 0.65)

# 스플리터: 크리스탈 그린
CRYSTAL_DARK = (0.12, 0.42, 0.08)
CRYSTAL_MID  = (0.20, 0.60, 0.12)
CRYSTAL_GLOW = (0.45, 1.00, 0.25)
TENDRIL_COL  = (0.15, 0.50, 0.10)

# 익스플로더: 오렌지 팽창
EXPLODE_DARK = (0.55, 0.22, 0.04)
EXPLODE_MID  = (0.78, 0.35, 0.06)
PUSTULE_COL  = (1.00, 0.55, 0.12)
GLOW_CORE    = (1.00, 0.72, 0.18)

# 엘리트 러셔: 다크 크림슨
ELITE_DARK   = (0.30, 0.04, 0.06)
ELITE_MID    = (0.52, 0.06, 0.10)
ELITE_PLATE  = (0.18, 0.04, 0.06)
HORN_COLOR   = (0.20, 0.18, 0.16)

# 디스트로이어: 퍼플/블랙 데몬
DEMON_DARK   = (0.12, 0.04, 0.22)
DEMON_MID    = (0.22, 0.08, 0.35)
DEMON_PLATE  = (0.16, 0.06, 0.28)
CHAIN_COLOR  = (0.30, 0.28, 0.28)
DEMON_HORN   = (0.15, 0.13, 0.12)

# 건물: 고딕 스톤
STONE_DARK   = (0.20, 0.20, 0.22)
STONE_MID    = (0.28, 0.28, 0.32)
STONE_LIGHT  = (0.38, 0.38, 0.42)
MAGIC_BLUE   = (0.20, 0.42, 0.85)
RUNE_GLOW    = (0.30, 0.55, 1.00)
WOOD_DARK    = (0.28, 0.20, 0.12)
WOOD_MID     = (0.38, 0.28, 0.16)
IRON_COLOR   = (0.30, 0.30, 0.32)


# ===================================================================
# UNITS
# ===================================================================

def make_soldier():
    """다크 블루 스틸 기사: 헬멧 바이저 슬릿, 흉갑 리벳, 폴드론,
    그리브, 크로스가드+폼멜 검, 보스 달린 카이트 실드 (22 파트)"""
    p = []

    # --- 다리 ---
    for sx in [-0.07, 0.07]:
        # 허벅지
        p.append(cyl(0.042, 0.16, (sx, 0.16, 0.0), segs=6, color=STEEL_DARK, metal=0.5))
        # 무릎 갑옷 (각진 박스)
        p.append(box((0.09, 0.06, 0.07), (sx, 0.08, 0.015), color=STEEL_MID, metal=0.6))
        # 정강이 (그리브)
        p.append(cyl(0.035, 0.12, (sx, 0.02, 0.005), segs=6, color=STEEL_DARK, metal=0.5))

    # --- 몸통 ---
    # 흉갑 본체
    p.append(box((0.26, 0.30, 0.20), (0, 0.29, 0), color=STEEL_DARK, metal=0.55, rough=0.45))
    # 흉갑 앞판 (약간 돌출)
    p.append(box((0.22, 0.22, 0.04), (0, 0.30, 0.10), color=STEEL_MID, metal=0.6, rough=0.4))
    # 흉갑 리벳 6개
    rivet_pos = [
        (-0.07, 0.36, 0.12), (0.07, 0.36, 0.12),
        (-0.07, 0.28, 0.12), (0.07, 0.28, 0.12),
        (-0.07, 0.20, 0.12), (0.07, 0.20, 0.12),
    ]
    p.extend(rivets(rivet_pos, r=0.013, color=STEEL_RIVET, metal=0.7))
    # 허리 벨트
    p.append(box((0.28, 0.04, 0.22), (0, 0.155, 0), color=LEATHER_DARK, metal=0.0))

    # --- 폴드론 (어깨갑옷) ---
    for sx in [-1, 1]:
        # 어깨 판
        p.append(box((0.09, 0.06, 0.12), (sx*0.18, 0.40, 0), color=STEEL_MID, metal=0.6))
        # 어깨 돌출 리벳
        p.append(sphere(0.016, (sx*0.18, 0.44, 0.04), sub=0, color=STEEL_RIVET, metal=0.7))
        # 팔 (상완)
        p.append(cyl(0.038, 0.18, (sx*0.17, 0.29, 0), segs=6, color=STEEL_DARK, metal=0.5))
        # 팔 (전완)
        p.append(cyl(0.032, 0.14, (sx*0.17, 0.16, 0), segs=6, color=STEEL_MID, metal=0.55))

    # --- 머리 ---
    # 얼굴
    p.append(sphere(0.085, (0, 0.495, 0), sub=1, color=SKIN_COLOR))
    # 헬멧 본체
    helm_body = trimesh.creation.icosphere(subdivisions=1, radius=0.098)
    helm_body.apply_translation((0, 0.505, 0))
    cm(helm_body, STEEL_DARK, 0.65, 0.35)
    p.append(helm_body)
    # 헬멧 바이저 슬릿 (가로 박스, 눈 부분)
    p.append(box((0.10, 0.016, 0.03), (0, 0.508, 0.085), color=LEATHER_DARK))
    # 바이저 테두리
    p.append(box((0.12, 0.024, 0.02), (0, 0.508, 0.080), color=STEEL_LIGHT, metal=0.7))
    # 헬멧 뒷판
    p.append(box((0.16, 0.06, 0.04), (0, 0.488, -0.085), color=STEEL_MID, metal=0.6))
    # 헬멧 꼭대기 크레스트
    p.append(box((0.025, 0.06, 0.075), (0, 0.570, 0.005), color=STEEL_LIGHT, metal=0.7))

    # --- 검 (오른손) ---
    # 블레이드
    p.append(box((0.022, 0.32, 0.010), (0.26, 0.30, 0.04), color=BLADE_COLOR, metal=0.85, rough=0.15))
    # 크로스가드
    p.append(box((0.11, 0.018, 0.018), (0.26, 0.15, 0.04), color=STEEL_MID, metal=0.7, rough=0.3))
    # 폼멜 (구)
    p.append(sphere(0.025, (0.26, 0.06, 0.04), sub=0, color=STEEL_MID, metal=0.7))
    # 손잡이
    p.append(cyl(0.014, 0.09, (0.26, 0.11, 0.04), segs=6, color=LEATHER_DARK))

    # --- 카이트 실드 (왼손) ---
    # 실드 본체 (육각형 실린더로 납작하게)
    shield_body = trimesh.creation.cylinder(radius=0.12, height=0.025, sections=5)
    shield_body.apply_transform(Rx(np.pi/2))
    shield_body.apply_translation((-0.24, 0.28, 0.08))
    cm(shield_body, STEEL_MID, 0.55, 0.4)
    p.append(shield_body)
    # 실드 보스 (중앙 돌출 원뿔)
    shield_boss = trimesh.creation.cone(radius=0.04, height=0.05, sections=6)
    shield_boss.apply_transform(Rx(-np.pi/2))
    shield_boss.apply_translation((-0.24, 0.28, 0.115))
    cm(shield_boss, STEEL_LIGHT, 0.7, 0.3)
    p.append(shield_boss)
    # 실드 테두리 리벳 4개
    shield_rivets = [
        (-0.24+0.09*np.cos(a), 0.28+0.09*np.sin(a), 0.095)
        for a in [np.pi/4, 3*np.pi/4, 5*np.pi/4, 7*np.pi/4]
    ]
    p.extend(rivets(shield_rivets, r=0.012, color=STEEL_RIVET, metal=0.7))

    return combine(p)


def make_archer():
    """포레스트 레인저: 후드+클oak, 퀴버+화살, 롱보우, 레더 아머 (20 파트)"""
    p = []

    # --- 다리 ---
    for sx in [-0.055, 0.055]:
        p.append(cyl(0.032, 0.18, (sx, 0.15, 0.0), segs=6, color=LEATHER_GRN))
        # 부츠
        p.append(box((0.07, 0.06, 0.09), (sx, 0.03, 0.015), color=LEATHER_DARK))

    # --- 몸통 (슬림) ---
    p.append(cyl(0.09, 0.28, (0, 0.28, 0), segs=8, color=LEATHER_GRN))
    # 가죽 흉갑
    p.append(box((0.18, 0.22, 0.04), (0, 0.30, 0.07), color=BOW_WOOD, metal=0.0, rough=0.9))
    # 벨트 + 버클
    p.append(box((0.20, 0.03, 0.12), (0, 0.17, 0), color=LEATHER_DARK))
    p.append(box((0.04, 0.04, 0.03), (0, 0.17, 0.065), color=GOLD_MID, metal=0.6))

    # --- 팔 ---
    for sx in [-1, 1]:
        p.append(cyl(0.028, 0.22, (sx*0.13, 0.30, 0), segs=6, color=LEATHER_GRN))
        # 손목 가드
        p.append(box((0.06, 0.05, 0.04), (sx*0.13, 0.18, 0), color=BOW_WOOD, metal=0.0, rough=0.8))

    # --- 클oak (등 드레이핑) ---
    p.append(box((0.22, 0.30, 0.04), (0, 0.26, -0.09), color=CLOAK_GREEN))
    p.append(box((0.18, 0.18, 0.03), (0, 0.10, -0.09), color=HOOD_GREEN))

    # --- 머리 ---
    p.append(sphere(0.075, (0, 0.49, 0), sub=1, color=SKIN_COLOR))
    # 후드 (콘 형태)
    hood = trimesh.creation.cone(radius=0.115, height=0.14, sections=7)
    hood.apply_translation((0, 0.555, -0.01))
    cm(hood, HOOD_GREEN, 0.0, 0.9)
    p.append(hood)
    # 후드 앞쪽 그림자 (스킨 보호)
    p.append(box((0.14, 0.04, 0.04), (0, 0.505, 0.065), color=HOOD_GREEN))

    # --- 퀴버 (화살통, 등 오른쪽) ---
    p.append(cyl(0.035, 0.22, (0.10, 0.32, -0.12), segs=6, color=BOW_WOOD, rot=Rx(np.pi*0.08)))
    # 화살 3개 (튀어나온 것)
    for i in range(3):
        ax = 0.10 + (i-1)*0.018
        p.append(cyl(0.005, 0.12, (ax, 0.44, -0.12), segs=4, color=BLADE_COLOR, metal=0.5))
        p.append(cone(0.01, 0.03, (ax, 0.50, -0.12), segs=3, color=(0.7, 0.2, 0.1)))

    # --- 롱보우 ---
    # 중앙 그립
    p.append(cyl(0.018, 0.16, (-0.22, 0.35, 0.06), segs=6, color=BOW_WOOD))
    # 위쪽 활 곡선 (기울인 실린더)
    bow_top = trimesh.creation.cylinder(radius=0.012, height=0.22, sections=5)
    bow_top.apply_transform(Rz(np.radians(20)))
    bow_top.apply_translation((-0.28, 0.50, 0.06))
    cm(bow_top, BOW_WOOD)
    p.append(bow_top)
    # 아래쪽 활 곡선
    bow_bot = trimesh.creation.cylinder(radius=0.012, height=0.22, sections=5)
    bow_bot.apply_transform(Rz(np.radians(-20)))
    bow_bot.apply_translation((-0.28, 0.20, 0.06))
    cm(bow_bot, BOW_WOOD)
    p.append(bow_bot)
    # 활시위 (얇은 실린더)
    p.append(cyl(0.005, 0.48, (-0.35, 0.35, 0.06), segs=4, color=STEEL_LIGHT, metal=0.3))

    return combine(p)


def make_tanker():
    """매시브 헤비 나이트: 탑 실드, 풀 플레이트, 뿔 헬멧, 두꺼운 건틀렛 (25 파트)"""
    p = []

    # --- 다리 (두꺼운 플레이트) ---
    for sx in [-0.09, 0.09]:
        # 허벅지 아머
        p.append(box((0.12, 0.18, 0.14), (sx, 0.18, 0), color=GOLD_DARK, metal=0.6, rough=0.4))
        # 무릎 원형 플레이트
        knee = trimesh.creation.cylinder(radius=0.07, height=0.04, sections=8)
        knee.apply_transform(Rx(np.pi/2))
        knee.apply_translation((sx, 0.10, 0.07))
        cm(knee, GOLD_MID, 0.65, 0.35)
        p.append(knee)
        # 정강이 그리브
        p.append(box((0.10, 0.14, 0.12), (sx, 0.04, 0.01), color=GOLD_DARK, metal=0.6))
        # 무릎 리벳
        p.append(sphere(0.018, (sx, 0.10, 0.09), sub=0, color=GOLD_RIVET, metal=0.75))

    # --- 몸통 ---
    p.append(box((0.36, 0.34, 0.28), (0, 0.30, 0), color=GOLD_DARK, metal=0.60, rough=0.40))
    # 앞 흉갑 (계단식 두겹)
    p.append(box((0.30, 0.28, 0.05), (0, 0.30, 0.14), color=GOLD_MID, metal=0.65, rough=0.35))
    p.append(box((0.22, 0.20, 0.04), (0, 0.32, 0.185), color=GOLD_LIGHT, metal=0.70, rough=0.30))
    # 흉갑 중앙 문장 (원형)
    emblem = trimesh.creation.cylinder(radius=0.06, height=0.03, sections=8)
    emblem.apply_transform(Rx(np.pi/2))
    emblem.apply_translation((0, 0.32, 0.22))
    cm(emblem, GOLD_RIVET, 0.8, 0.2)
    p.append(emblem)
    # 허리 플레이트
    p.append(box((0.38, 0.06, 0.30), (0, 0.15, 0), color=GOLD_DARK, metal=0.6))

    # --- 폴드론 (과장된 어깨갑옷) ---
    for sx in [-1, 1]:
        p.append(box((0.14, 0.10, 0.18), (sx*0.25, 0.42, 0), color=GOLD_MID, metal=0.65, rough=0.35))
        # 어깨 위쪽 가장자리 판
        p.append(box((0.16, 0.04, 0.20), (sx*0.25, 0.47, 0), color=GOLD_LIGHT, metal=0.70))
        # 어깨 리벳
        for rz in [-0.06, 0, 0.06]:
            p.append(sphere(0.020, (sx*0.25, 0.48, rz), sub=0, color=GOLD_RIVET, metal=0.75))
        # 건틀렛 (두꺼운 주먹)
        p.append(box((0.10, 0.12, 0.10), (sx*0.25, 0.20, 0), color=GOLD_DARK, metal=0.65))
        # 건틀렛 손가락 리지
        p.append(box((0.10, 0.02, 0.12), (sx*0.25, 0.145, 0.01), color=GOLD_MID, metal=0.7))

    # --- 머리 ---
    p.append(sphere(0.09, (0, 0.515, 0), sub=1, color=SKIN_COLOR))
    # 헬멧 박스 (전면)
    p.append(box((0.26, 0.16, 0.22), (0, 0.535, 0), color=GOLD_DARK, metal=0.65, rough=0.35))
    p.append(box((0.20, 0.08, 0.06), (0, 0.530, 0.12), color=LEATHER_DARK))  # 바이저 슬릿
    # 좌우 뿔
    for sx in [-1, 1]:
        horn = trimesh.creation.cone(radius=0.028, height=0.16, sections=5)
        horn.apply_transform(Rz(sx * np.radians(25)))
        horn.apply_translation((sx*0.11, 0.65, 0))
        cm(horn, GOLD_LIGHT, 0.5, 0.5)
        p.append(horn)

    # --- 타워 실드 ---
    p.append(box((0.32, 0.50, 0.040), (0, 0.28, 0.24), color=GOLD_DARK, metal=0.6, rough=0.4))
    # 실드 테두리 (약간 돌출)
    p.append(box((0.36, 0.54, 0.020), (0, 0.28, 0.25), color=GOLD_MID, metal=0.65, rough=0.35))
    # 실드 보스 (중앙 십자)
    p.append(box((0.06, 0.40, 0.035), (0, 0.28, 0.27), color=GOLD_LIGHT, metal=0.7))
    p.append(box((0.30, 0.06, 0.035), (0, 0.28, 0.27), color=GOLD_LIGHT, metal=0.7))
    # 실드 중앙 원형 보스
    boss = trimesh.creation.cylinder(radius=0.055, height=0.05, sections=8)
    boss.apply_transform(Rx(np.pi/2))
    boss.apply_translation((0, 0.28, 0.290))
    cm(boss, GOLD_RIVET, 0.8, 0.2)
    p.append(boss)

    return combine(p)


def make_bomber():
    """웅크린 봄버: 등에 큰 폭발 배럴 + 퓨즈, 누더기 옷 (18 파트)"""
    p = []

    # --- 다리 (짧고 구부러진) ---
    for sx in [-0.065, 0.065]:
        p.append(cyl(0.038, 0.12, (sx, 0.09, 0.01), segs=6, color=BOMBER_CLOTH))
        p.append(box((0.08, 0.055, 0.09), (sx, 0.03, 0.015), color=BOMBER_DARK))  # 낡은 신발

    # --- 몸통 (통통, 웅크림) ---
    body = trimesh.creation.icosphere(subdivisions=1, radius=0.15)
    body.apply_translation((0, 0.25, 0.01))
    cm(body, BOMBER_CLOTH)
    p.append(body)
    # 누더기 옷 패치 1
    p.append(box((0.12, 0.10, 0.04), (0.02, 0.28, 0.12), color=BOMBER_DARK))
    # 누더기 옷 패치 2
    p.append(box((0.10, 0.08, 0.03), (-0.04, 0.20, 0.12), color=(0.45, 0.30, 0.18)))
    # 어깨 (불균형하게 웅크린)
    p.append(box((0.10, 0.06, 0.10), (-0.17, 0.34, 0), color=BOMBER_CLOTH))
    p.append(box((0.08, 0.05, 0.09), (0.16, 0.32, 0), color=BOMBER_DARK))

    # --- 머리 (앞으로 숙임) ---
    head = trimesh.creation.icosphere(subdivisions=1, radius=0.082)
    head.apply_translation((0, 0.425, 0.04))
    cm(head, SKIN_COLOR)
    p.append(head)
    # 덥수룩한 머리카락
    p.append(box((0.14, 0.05, 0.12), (0, 0.460, -0.01), color=BOMBER_DARK))
    # 눈 (불안한 표정)
    p.append(sphere(0.018, (-0.03, 0.432, 0.075), sub=0, color=(0.9, 0.15, 0.05)))
    p.append(sphere(0.018, (0.03, 0.432, 0.075), sub=0, color=(0.9, 0.15, 0.05)))

    # --- 등 폭발 배럴 ---
    barrel = trimesh.creation.cylinder(radius=0.09, height=0.22, sections=10)
    barrel.apply_transform(Rx(np.pi*0.1))
    barrel.apply_translation((0, 0.30, -0.18))
    cm(barrel, BARREL_WOOD, 0.0, 0.9)
    p.append(barrel)
    # 배럴 철 후프 밴드 3개
    for by in [0.20, 0.28, 0.36]:
        hoop = trimesh.creation.cylinder(radius=0.095, height=0.018, sections=10)
        hoop.apply_transform(Rx(np.pi*0.1))
        hoop.apply_translation((0, by, -0.18))
        cm(hoop, IRON_COLOR, 0.5, 0.5)
        p.append(hoop)
    # 배럴 뚜껑
    lid = trimesh.creation.cylinder(radius=0.092, height=0.025, sections=10)
    lid.apply_transform(Rx(np.pi*0.1))
    lid.apply_translation((0, 0.42, -0.18))
    cm(lid, IRON_COLOR, 0.5, 0.5)
    p.append(lid)
    # 퓨즈 (꼬인 코드)
    p.append(cyl(0.012, 0.14, (0.03, 0.50, -0.16), segs=4, rot=Rx(np.pi*0.15), color=LEATHER_DARK))
    # 퓨즈 불꽃 (구)
    p.append(sphere(0.028, (0.04, 0.62, -0.14), sub=0, color=FUSE_SPARK, metal=0.0, rough=0.2))
    # 불꽃 코어
    p.append(sphere(0.018, (0.04, 0.625, -0.135), sub=0, color=(1.0, 0.90, 0.5), metal=0.0, rough=0.1))
    # 배럴 연결 스트랩
    p.append(box((0.05, 0.22, 0.03), (0.09, 0.27, -0.08), color=LEATHER_DARK))
    p.append(box((0.05, 0.22, 0.03), (-0.09, 0.27, -0.08), color=LEATHER_DARK))

    return combine(p)


# ===================================================================
# ENEMIES
# ===================================================================

def make_rusher():
    """고블린형 러셔: 긴 발톱, 웅크린 공격 자세, 등 스파이크, 빛나는 눈 (20 파트)"""
    p = []

    # --- 다리 (짧고 굽은) ---
    for sx in [-0.065, 0.065]:
        # 넓적다리
        p.append(cyl(0.035, 0.12, (sx, 0.12, 0.02), segs=5, color=GOBLIN_DARK))
        # 발
        p.append(box((0.08, 0.04, 0.12), (sx, 0.03, 0.03), color=GOBLIN_MID))
        # 발톱 (클로) 3개
        for ci in range(3):
            angle = np.radians(-30 + ci*30)
            cx = sx + np.sin(angle)*0.05
            cz = 0.09 + ci*0.01
            claw_m = trimesh.creation.cone(radius=0.014, height=0.10, sections=3)
            claw_m.apply_transform(Rx(-np.pi/2))
            claw_m.apply_translation((cx, 0.025, cz))
            cm(claw_m, CLAW_COLOR, 0.2, 0.5)
            p.append(claw_m)

    # --- 몸통 (웅크림, 앞으로 기울어짐) ---
    body = trimesh.creation.cone(radius=0.13, height=0.22, sections=5)
    body.apply_transform(Rx(np.radians(-15)))
    body.apply_translation((0, 0.19, 0.02))
    cm(body, GOBLIN_DARK)
    p.append(body)

    # --- 팔 (길고 위협적) ---
    for sx in [-1, 1]:
        # 상완 (앞으로 뻗은)
        arm_upper = trimesh.creation.cylinder(radius=0.028, height=0.20, sections=5)
        arm_upper.apply_transform(Rz(sx * np.radians(40)))
        arm_upper.apply_transform(Rx(np.radians(-30)))
        arm_upper.apply_translation((sx*0.18, 0.28, 0.10))
        cm(arm_upper, GOBLIN_MID)
        p.append(arm_upper)
        # 전완
        arm_lower = trimesh.creation.cylinder(radius=0.022, height=0.18, sections=5)
        arm_lower.apply_transform(Rx(np.radians(-50)))
        arm_lower.apply_translation((sx*0.25, 0.18, 0.18))
        cm(arm_lower, GOBLIN_DARK)
        p.append(arm_lower)
        # 큰 클로 (손)
        for ci in range(3):
            angle = np.radians(-20 + ci*20)
            hclaw = trimesh.creation.cone(radius=0.018, height=0.12, sections=3)
            hclaw.apply_transform(Rx(-np.pi/2 + angle * 0.4))
            hclaw.apply_translation((sx*0.30 + ci*sx*0.01, 0.10, 0.25))
            cm(hclaw, CLAW_COLOR, 0.3, 0.4)
            p.append(hclaw)

    # --- 머리 ---
    head = trimesh.creation.icosphere(subdivisions=0, radius=0.09)
    head.apply_translation((0, 0.37, 0.06))
    cm(head, GOBLIN_MID)
    p.append(head)
    # 빛나는 눈 (작은 구)
    p.append(sphere(0.022, (-0.032, 0.382, 0.135), sub=0, color=EYE_GLOW, metal=0.0, rough=0.1))
    p.append(sphere(0.022, (0.032, 0.382, 0.135), sub=0, color=EYE_GLOW, metal=0.0, rough=0.1))
    # 뿔 2개
    for sx in [-0.04, 0.04]:
        horn = trimesh.creation.cone(radius=0.016, height=0.07, sections=4)
        horn.apply_transform(Rz(sx * 25))
        horn.apply_translation((sx, 0.445, 0.05))
        cm(horn, GOBLIN_MID)
        p.append(horn)
    # 이빨 (삼각형 콘)
    for tx in [-0.02, 0, 0.02]:
        fang = trimesh.creation.cone(radius=0.010, height=0.04, sections=3)
        fang.apply_transform(Rx(np.pi))
        fang.apply_translation((tx, 0.345, 0.14))
        cm(fang, (0.90, 0.88, 0.82))
        p.append(fang)

    # --- 등 스파이크 ---
    for i, (bx, by, bz, ang) in enumerate([
        (0, 0.32, -0.10, 0), (-0.05, 0.28, -0.10, -15), (0.05, 0.28, -0.10, 15),
        (0, 0.22, -0.10, 0),
    ]):
        sp = trimesh.creation.cone(radius=0.018, height=0.09, sections=4)
        sp.apply_transform(Rx(np.pi * 0.9))
        sp.apply_transform(Rz(np.radians(ang)))
        sp.apply_translation((bx, by, bz))
        cm(sp, GOBLIN_MID, 0.2, 0.6)
        p.append(sp)

    return combine(p)


def make_tank_enemy():
    """장갑 딱정벌레/게: 겹친 갑옷 플레이트, 작은 머리, 거대 몸, 스파이크 (22 파트)"""
    p = []

    # --- 다리 (6개, 게처럼) ---
    for i, (lx, lz, ang) in enumerate([
        (-0.28, 0.12, 40), (-0.28, 0, 50), (-0.28, -0.12, 40),
        (0.28, 0.12, -40), (0.28, 0, -50), (0.28, -0.12, -40),
    ]):
        leg = trimesh.creation.cylinder(radius=0.025, height=0.18, sections=5)
        leg.apply_transform(Rz(np.radians(ang)))
        leg.apply_translation((lx, 0.10, lz))
        cm(leg, BEETLE_MID)
        p.append(leg)
        # 발끝 클로
        foot = trimesh.creation.cone(radius=0.020, height=0.08, sections=4)
        foot.apply_transform(Rx(-np.pi/2))
        foot.apply_transform(Rz(np.radians(ang * 0.3)))
        foot.apply_translation((lx * 1.3, 0.03, lz * 1.1))
        cm(foot, BEETLE_DARK)
        p.append(foot)

    # --- 몸통 (거대한 껍데기) ---
    # 메인 껍데기
    p.append(box((0.50, 0.30, 0.50), (0, 0.22, 0), color=BEETLE_DARK, metal=0.4, rough=0.5))
    # 앞 갑옷 플레이트 (겹치는 층)
    p.append(box((0.44, 0.08, 0.14), (0, 0.33, 0.22), color=BEETLE_MID, metal=0.45, rough=0.45))
    p.append(box((0.40, 0.07, 0.14), (0, 0.25, 0.23), color=BEETLE_MID, metal=0.45))
    p.append(box((0.36, 0.06, 0.14), (0, 0.18, 0.24), color=BEETLE_LIGHT, metal=0.5))
    # 측면 추가 갑판
    for sx in [-1, 1]:
        p.append(box((0.06, 0.22, 0.42), (sx*0.26, 0.22, 0), color=BEETLE_MID, metal=0.45))
        p.append(box((0.04, 0.28, 0.38), (sx*0.30, 0.22, 0), color=BEETLE_DARK, metal=0.4))

    # --- 등 스파이크 (여러개) ---
    spike_positions = [
        (0, 0.40, 0.10), (-0.12, 0.40, 0.05), (0.12, 0.40, 0.05),
        (-0.20, 0.38, -0.05), (0.20, 0.38, -0.05),
        (0, 0.40, -0.12), (-0.10, 0.39, -0.18), (0.10, 0.39, -0.18),
    ]
    for sp_pos in spike_positions:
        sp = trimesh.creation.cone(radius=0.022, height=0.10, sections=4)
        sp.apply_translation(sp_pos)
        cm(sp, SPIKE_COLOR, 0.3, 0.5)
        p.append(sp)

    # --- 머리 (작고 앞에 달린) ---
    p.append(box((0.20, 0.18, 0.16), (0, 0.25, 0.30), color=BEETLE_DARK, metal=0.4))
    # 눈 (복안, 작은 구 2개)
    p.append(sphere(0.03, (-0.07, 0.28, 0.37), sub=0, color=EYE_GLOW, metal=0.0, rough=0.1))
    p.append(sphere(0.03, (0.07, 0.28, 0.37), sub=0, color=EYE_GLOW, metal=0.0, rough=0.1))
    # 집게 (집게발)
    for sx in [-1, 1]:
        pincer = trimesh.creation.cone(radius=0.030, height=0.16, sections=4)
        pincer.apply_transform(Rx(-np.pi/2))
        pincer.apply_transform(Rz(sx * np.radians(20)))
        pincer.apply_translation((sx*0.09, 0.22, 0.44))
        cm(pincer, BEETLE_MID, 0.5, 0.4)
        p.append(pincer)

    return combine(p)


def make_splitter():
    """크리스탈 다이아몬드: 균열선, 내부 발광 코어, 유기적 촉수 (18 파트)"""
    p = []

    # --- 메인 크리스탈 몸체 (팔면체) ---
    # 위 콘
    top = trimesh.creation.cone(radius=0.18, height=0.28, sections=4)
    top.apply_translation((0, 0.28, 0))
    cm(top, CRYSTAL_DARK, 0.2, 0.3)
    p.append(top)
    # 아래 콘
    bot = trimesh.creation.cone(radius=0.18, height=0.22, sections=4)
    bot.apply_transform(Rx(np.pi))
    bot.apply_translation((0, 0.12, 0))
    cm(bot, CRYSTAL_DARK, 0.2, 0.3)
    p.append(bot)

    # --- 크리스탈 페이스 (밝은 면) ---
    for angle in [0, 90, 180, 270]:
        rad = np.radians(angle)
        face_x = np.cos(rad) * 0.12
        face_z = np.sin(rad) * 0.12
        face = trimesh.creation.box(extents=[0.08, 0.22, 0.04])
        face.apply_transform(Ry(rad))
        face.apply_translation((face_x, 0.20, face_z))
        cm(face, CRYSTAL_MID, 0.1, 0.2)
        p.append(face)

    # --- 균열 / 시임 라인 ---
    # 수평 메인 시임
    p.append(box((0.28, 0.018, 0.28), (0, 0.185, 0), color=CRYSTAL_GLOW, metal=0.0, rough=0.1))
    # 수직 시임 (X축)
    p.append(box((0.018, 0.40, 0.018), (0, 0.22, 0), color=CRYSTAL_GLOW, metal=0.0, rough=0.1))
    # 대각 균열 라인들
    for angle in [45, 135]:
        rad = np.radians(angle)
        crack = trimesh.creation.box(extents=[0.28, 0.012, 0.012])
        crack.apply_transform(Ry(rad))
        crack.apply_translation((0, 0.185, 0))
        cm(crack, CRYSTAL_GLOW, 0.0, 0.1)
        p.append(crack)

    # --- 내부 발광 코어 ---
    core_inner = trimesh.creation.icosphere(subdivisions=1, radius=0.06)
    core_inner.apply_translation((0, 0.20, 0))
    cm(core_inner, CRYSTAL_GLOW, 0.0, 0.05)
    p.append(core_inner)
    core_outer = trimesh.creation.icosphere(subdivisions=1, radius=0.10)
    core_outer.apply_translation((0, 0.20, 0))
    cm(core_outer, CRYSTAL_MID, 0.0, 0.2)
    p.append(core_outer)

    # --- 유기적 촉수 (아래 부분) ---
    tendril_configs = [
        (-0.12, 0.02, 0.10, -30), (0.12, 0.02, 0.10, 30),
        (-0.08, 0.02, -0.12, -20), (0.08, 0.02, -0.12, 20),
        (0, 0.02, 0.14, 0), (0, 0.02, -0.14, 0),
    ]
    for tx, ty, tz, ta in tendril_configs:
        tend = trimesh.creation.cone(radius=0.022, height=0.12, sections=4)
        tend.apply_transform(Rx(np.pi))
        tend.apply_transform(Rz(np.radians(ta)))
        tend.apply_translation((tx, ty, tz))
        cm(tend, TENDRIL_COL, 0.1, 0.6)
        p.append(tend)

    # --- 작은 크리스탈 파편 (주변) ---
    shard_configs = [
        (-0.14, 0.30, 0.08, 20), (0.16, 0.28, -0.06, -15), (-0.10, 0.15, -0.14, 10),
    ]
    for sx, sy, sz, sa in shard_configs:
        shard = trimesh.creation.cone(radius=0.04, height=0.10, sections=3)
        shard.apply_transform(Ry(np.radians(sa * 10)))
        shard.apply_translation((sx, sy, sz))
        cm(shard, CRYSTAL_MID, 0.2, 0.3)
        p.append(shard)

    return combine(p)


def make_exploder():
    """부풀어 오른 생명체: 가시/농포, 내부 발광, 터지기 직전 (20 파트)"""
    p = []

    # --- 메인 몸체 (불균칙하게 팽창) ---
    body = trimesh.creation.icosphere(subdivisions=2, radius=0.22)
    body.apply_translation((0, 0.26, 0))
    cm(body, EXPLODE_DARK, 0.0, 0.9)
    p.append(body)
    # 팽창 부분 (불규칙 돌출)
    bulge_configs = [
        (0.14, 0.32, 0.16, 0.06), (-0.16, 0.30, 0.10, 0.05),
        (0.05, 0.44, 0.14, 0.05), (-0.08, 0.16, 0.18, 0.06),
    ]
    for bx, by, bz, br in bulge_configs:
        b = trimesh.creation.icosphere(subdivisions=1, radius=br)
        b.apply_translation((bx, by, bz))
        cm(b, EXPLODE_MID, 0.0, 0.8)
        p.append(b)

    # --- 내부 발광 코어 ---
    glow_core = trimesh.creation.icosphere(subdivisions=1, radius=0.10)
    glow_core.apply_translation((0, 0.26, 0))
    cm(glow_core, GLOW_CORE, 0.0, 0.05)
    p.append(glow_core)
    # 발광 중간층
    glow_mid = trimesh.creation.icosphere(subdivisions=1, radius=0.15)
    glow_mid.apply_translation((0, 0.26, 0))
    cm(glow_mid, PUSTULE_COL, 0.0, 0.15)
    p.append(glow_mid)

    # --- 가시/스파인 (균일하게 분포) ---
    angles_az = np.linspace(0, 2*np.pi, 10, endpoint=False)
    elevs = [0.2, 0.4, 0.6]
    for elev in elevs:
        for az in angles_az:
            r_body = 0.22
            sx_p = r_body * np.cos(az) * np.sin(np.pi * elev)
            sy_p = r_body * np.cos(np.pi * elev) + 0.26
            sz_p = r_body * np.sin(az) * np.sin(np.pi * elev)
            spine_len = 0.08 + np.random.RandomState(int(az*100+elev*10)).random() * 0.04
            sp = trimesh.creation.cone(radius=0.018, height=spine_len, sections=3)
            # 표면 법선 방향으로 회전
            ndir = np.array([sx_p, sy_p - 0.26, sz_p])
            if np.linalg.norm(ndir) > 0:
                ndir = ndir / np.linalg.norm(ndir)
                up = np.array([0, 1, 0])
                axis = np.cross(up, ndir)
                if np.linalg.norm(axis) > 0.001:
                    axis = axis / np.linalg.norm(axis)
                    ang = np.arccos(np.clip(np.dot(up, ndir), -1, 1))
                    sp.apply_transform(trimesh.transformations.rotation_matrix(ang, axis))
            sp.apply_translation((sx_p, sy_p, sz_p))
            cm(sp, PUSTULE_COL, 0.0, 0.6)
            p.append(sp)

    # --- 농포 (작은 구 돌출) ---
    pustule_pos = [
        (0.18, 0.32, 0.12), (-0.14, 0.28, 0.15), (0.10, 0.44, 0.12),
        (-0.08, 0.18, 0.18), (0.16, 0.22, -0.12),
    ]
    for pos in pustule_pos:
        pus = trimesh.creation.icosphere(subdivisions=0, radius=0.035)
        pus.apply_translation(pos)
        cm(pus, (1.0, 0.65, 0.20), 0.0, 0.7)
        p.append(pus)

    # --- 다리 (흔적적인, 짧은) ---
    for sx in [-0.10, 0.10]:
        p.append(cyl(0.04, 0.08, (sx, 0.04, 0.02), segs=5, color=EXPLODE_DARK))

    return combine(p)


def make_elite_rusher():
    """아머드 고블린 엘리트: 뿔 왕관, 흉갑, 듀얼 클로, 케이프 (22 파트)"""
    p = []

    # --- 다리 ---
    for sx in [-0.07, 0.07]:
        p.append(cyl(0.038, 0.14, (sx, 0.13, 0.01), segs=5, color=ELITE_DARK))
        p.append(box((0.09, 0.05, 0.10), (sx, 0.035, 0.02), color=ELITE_MID))

    # --- 몸통 ---
    body = trimesh.creation.cone(radius=0.14, height=0.26, sections=6)
    body.apply_transform(Rx(np.radians(-10)))
    body.apply_translation((0, 0.22, 0.01))
    cm(body, ELITE_DARK)
    p.append(body)

    # --- 흉갑 (다크 플레이트) ---
    p.append(box((0.22, 0.20, 0.05), (0, 0.24, 0.09), color=ELITE_PLATE, metal=0.6, rough=0.4))
    # 흉갑 리벳 4개
    p.extend(rivets([
        (-0.07, 0.30, 0.115), (0.07, 0.30, 0.115),
        (-0.07, 0.20, 0.115), (0.07, 0.20, 0.115),
    ], r=0.012, color=(0.5, 0.05, 0.08), metal=0.5))

    # --- 어깨 스파이크 ---
    for sx in [-1, 1]:
        p.append(box((0.08, 0.06, 0.09), (sx*0.18, 0.32, 0), color=ELITE_MID, metal=0.5))
        sp = trimesh.creation.cone(radius=0.022, height=0.09, sections=4)
        sp.apply_transform(Rz(sx * np.radians(30)))
        sp.apply_translation((sx*0.22, 0.38, 0))
        cm(sp, HORN_COLOR, 0.3, 0.5)
        p.append(sp)
        # 듀얼 클로 팔
        arm = trimesh.creation.cylinder(radius=0.028, height=0.20, sections=5)
        arm.apply_transform(Rx(np.radians(-35)))
        arm.apply_transform(Rz(sx * np.radians(35)))
        arm.apply_translation((sx*0.22, 0.22, 0.12))
        cm(arm, ELITE_DARK)
        p.append(arm)
        # 클로 세트 (듀얼)
        for ci in range(3):
            cang = np.radians(-20 + ci * 20)
            claw_m = trimesh.creation.cone(radius=0.015, height=0.13, sections=3)
            claw_m.apply_transform(Rx(-np.pi/2 + cang*0.5))
            claw_m.apply_translation((sx*0.30 + ci*0.01*sx, 0.10, 0.22))
            cm(claw_m, CLAW_COLOR, 0.4, 0.35)
            p.append(claw_m)

    # --- 머리 ---
    head = trimesh.creation.icosphere(subdivisions=0, radius=0.092)
    head.apply_translation((0, 0.40, 0.04))
    cm(head, ELITE_MID)
    p.append(head)
    # 빛나는 눈
    p.append(sphere(0.024, (-0.03, 0.414, 0.115), sub=0, color=EYE_GLOW, rough=0.05))
    p.append(sphere(0.024, (0.03, 0.414, 0.115), sub=0, color=EYE_GLOW, rough=0.05))

    # --- 뿔 왕관 (5개, 위로 솟은) ---
    horn_configs = [
        (0, 0.50, 0.04, 0),
        (-0.05, 0.495, 0.035, -18), (0.05, 0.495, 0.035, 18),
        (-0.09, 0.487, 0.025, -35), (0.09, 0.487, 0.025, 35),
    ]
    for hx, hy, hz, ha in horn_configs:
        horn = trimesh.creation.cone(radius=0.020, height=0.10 - abs(ha)*0.001, sections=4)
        horn.apply_transform(Rz(np.radians(ha)))
        horn.apply_translation((hx, hy, hz))
        cm(horn, HORN_COLOR, 0.2, 0.6)
        p.append(horn)

    # --- 케이프/꼬리 (등) ---
    p.append(box((0.18, 0.26, 0.035), (0, 0.22, -0.10), color=ELITE_DARK))
    # 케이프 하단 (뾰족하게 분리)
    for cx in [-0.05, 0.05]:
        tail_p = trimesh.creation.cone(radius=0.05, height=0.10, sections=3)
        tail_p.apply_transform(Rx(np.pi))
        tail_p.apply_translation((cx, 0.05, -0.10))
        cm(tail_p, ELITE_MID)
        p.append(tail_p)

    return combine(p)


def make_destroyer():
    """거대 데몬 군주: 뿔 달린 해골 머리, 넓은 폴드론, 체인, 무거운 다리 (25 파트)"""
    p = []

    # --- 다리 (거대하고 묵직) ---
    for sx in [-0.13, 0.13]:
        p.append(box((0.18, 0.24, 0.20), (sx, 0.19, 0), color=DEMON_DARK, metal=0.35, rough=0.6))
        # 무릎 판
        p.append(box((0.20, 0.06, 0.22), (sx, 0.10, 0), color=DEMON_MID, metal=0.4))
        # 발 (넓게 퍼진)
        p.append(box((0.22, 0.08, 0.26), (sx, 0.03, 0.02), color=DEMON_DARK, metal=0.35))
        # 무릎 스파이크
        sp = trimesh.creation.cone(radius=0.025, height=0.10, sections=4)
        sp.apply_transform(Rx(-np.pi/2))
        sp.apply_translation((sx, 0.12, 0.12))
        cm(sp, SPIKE_COLOR, 0.4, 0.5)
        p.append(sp)

    # --- 몸통 (거대) ---
    p.append(box((0.56, 0.48, 0.44), (0, 0.38, 0), color=DEMON_DARK, metal=0.35, rough=0.55))
    # 흉갑 (검은 판)
    p.append(box((0.44, 0.36, 0.06), (0, 0.40, 0.22), color=DEMON_PLATE, metal=0.5, rough=0.4))
    # 흉부 문장
    emblem = trimesh.creation.cone(radius=0.08, height=0.04, sections=6)
    emblem.apply_transform(Rx(np.pi/2))
    emblem.apply_translation((0, 0.42, 0.26))
    cm(emblem, (0.6, 0.10, 0.70), 0.5, 0.3)
    p.append(emblem)
    # 허리 (두꺼운 벨트)
    p.append(box((0.58, 0.08, 0.46), (0, 0.21, 0), color=LEATHER_DARK, metal=0.0))

    # --- 거대 폴드론 ---
    for sx in [-1, 1]:
        # 어깨 메인
        p.append(box((0.20, 0.14, 0.24), (sx*0.38, 0.58, 0), color=DEMON_MID, metal=0.45, rough=0.45))
        # 어깨 위 판
        p.append(box((0.22, 0.06, 0.26), (sx*0.38, 0.66, 0), color=DEMON_MID, metal=0.45))
        # 어깨 스파이크 (3개)
        for spz in [-0.08, 0, 0.08]:
            sp = trimesh.creation.cone(radius=0.022, height=0.12, sections=4)
            sp.apply_translation((sx*0.38, 0.76, spz))
            cm(sp, SPIKE_COLOR, 0.35, 0.5)
            p.append(sp)
        # 팔 (두꺼운 상완)
        p.append(box((0.16, 0.22, 0.18), (sx*0.38, 0.40, 0), color=DEMON_DARK, metal=0.4))
        # 팔 (전완, 더 두꺼운 클로)
        p.append(box((0.18, 0.18, 0.20), (sx*0.38, 0.22, 0), color=DEMON_MID, metal=0.45))

    # --- 체인 (양쪽에서 드리워짐) ---
    for sx in [-0.18, 0.18]:
        for cy_h in [0.48, 0.40, 0.32, 0.24]:
            link = trimesh.creation.cylinder(radius=0.018, height=0.06, sections=6)
            link.apply_transform(Rx(np.pi/2 * (cy_h % 0.2 > 0.1)))
            link.apply_translation((sx*1.0, cy_h, -0.05))
            cm(link, CHAIN_COLOR, 0.4, 0.6)
            p.append(link)

    # --- 머리 (해골형) ---
    # 해골 주 형태
    skull = trimesh.creation.box(extents=[0.28, 0.26, 0.28])
    skull.apply_translation((0, 0.75, 0.04))
    cm(skull, DEMON_MID, 0.3, 0.6)
    p.append(skull)
    # 광대뼈 (돌출)
    for sx in [-0.12, 0.12]:
        p.append(box((0.06, 0.05, 0.06), (sx, 0.74, 0.16), color=DEMON_MID, metal=0.3))
    # 눈 소켓 (어두운 구멍)
    p.append(box((0.07, 0.06, 0.04), (-0.07, 0.78, 0.17), color=DEMON_DARK))
    p.append(box((0.07, 0.06, 0.04), (0.07, 0.78, 0.17), color=DEMON_DARK))
    # 눈 발광 (붉은 구)
    p.append(sphere(0.026, (-0.07, 0.780, 0.19), sub=0, color=(1.0, 0.10, 0.0), rough=0.05))
    p.append(sphere(0.026, (0.07, 0.780, 0.19), sub=0, color=(1.0, 0.10, 0.0), rough=0.05))

    # --- 뿔 (거대) ---
    for sx in [-1, 1]:
        # 메인 큰 뿔
        horn_big = trimesh.creation.cone(radius=0.04, height=0.28, sections=5)
        horn_big.apply_transform(Rz(sx * np.radians(22)))
        horn_big.apply_transform(Rx(np.radians(-8)))
        horn_big.apply_translation((sx*0.11, 0.90, 0.02))
        cm(horn_big, DEMON_HORN, 0.3, 0.7)
        p.append(horn_big)
        # 작은 보조 뿔
        horn_small = trimesh.creation.cone(radius=0.025, height=0.14, sections=4)
        horn_small.apply_transform(Rz(sx * np.radians(45)))
        horn_small.apply_translation((sx*0.14, 0.86, 0.01))
        cm(horn_small, DEMON_HORN, 0.3, 0.7)
        p.append(horn_small)

    return combine(p)


# ===================================================================
# BUILDINGS
# ===================================================================

def make_hq():
    """고딕 성 본거지: 4 코너 타워, 성첩, 문, 빛나는 창문, 룬 마크 (28 파트)"""
    p = []

    # --- 메인 본관 (키프) ---
    p.append(box((1.00, 0.80, 0.90), (0, 0.40, 0), color=STONE_DARK, metal=0.1, rough=0.9))
    # 키프 전면 (약간 밝게)
    p.append(box((1.00, 0.80, 0.04), (0, 0.40, 0.47), color=STONE_MID, metal=0.1, rough=0.85))

    # --- 성첩 (배틀먼트 이빨) ---
    for tooth_x in np.linspace(-0.40, 0.40, 5):
        # 앞쪽 성첩
        p.append(box((0.10, 0.10, 0.08), (tooth_x, 0.85, 0.47), color=STONE_MID, metal=0.1))
        # 뒤쪽 성첩
        p.append(box((0.10, 0.10, 0.08), (tooth_x, 0.85, -0.47), color=STONE_DARK, metal=0.1))
    for tooth_z in np.linspace(-0.35, 0.35, 4):
        p.append(box((0.08, 0.10, 0.10), (-0.52, 0.85, tooth_z), color=STONE_DARK, metal=0.1))
        p.append(box((0.08, 0.10, 0.10), (0.52, 0.85, tooth_z), color=STONE_DARK, metal=0.1))

    # --- 코너 타워 (4개) ---
    for tx, tz in [(-0.45, -0.40), (0.45, -0.40), (-0.45, 0.40), (0.45, 0.40)]:
        # 타워 몸통
        tower = trimesh.creation.cylinder(radius=0.13, height=1.10, sections=8)
        tower.apply_translation((tx, 0.55, tz))
        cm(tower, STONE_DARK, 0.1, 0.85)
        p.append(tower)
        # 타워 꼭대기 (작은 원뿔 지붕)
        turret_top = trimesh.creation.cone(radius=0.16, height=0.20, sections=8)
        turret_top.apply_translation((tx, 1.15, tz))
        cm(turret_top, (0.12, 0.14, 0.28), 0.1, 0.8)
        p.append(turret_top)
        # 타워 성첩
        for ta in range(4):
            rad = ta * np.pi / 2 + np.pi/4
            tooth_x2 = tx + np.cos(rad) * 0.13
            tooth_z2 = tz + np.sin(rad) * 0.13
            p.append(box((0.06, 0.08, 0.06), (tooth_x2, 1.12, tooth_z2), color=STONE_MID))
        # 창문 (화살 슬릿, 빛나는)
        arrow_slit = trimesh.creation.box(extents=[0.04, 0.14, 0.03])
        arrow_slit.apply_translation((tx + np.sign(tx)*0.12, 0.65, tz + np.sign(tz)*0.12))
        cm(arrow_slit, MAGIC_BLUE, 0.0, 0.2)
        p.append(arrow_slit)

    # --- 문 (아치형) ---
    p.append(box((0.20, 0.32, 0.06), (0, 0.22, 0.48), color=LEATHER_DARK))
    # 문 아치
    door_arch = trimesh.creation.cylinder(radius=0.10, height=0.06, sections=8)
    door_arch.apply_transform(Rx(np.pi/2))
    door_arch.apply_translation((0, 0.38, 0.485))
    cm(door_arch, STONE_LIGHT, 0.1, 0.8)
    p.append(door_arch)
    # 문 테두리 (석재)
    p.append(box((0.24, 0.36, 0.04), (0, 0.22, 0.495), color=STONE_MID))

    # --- 창문 (빛나는 파란색) ---
    win_pos = [
        (-0.28, 0.52, 0.475), (0.28, 0.52, 0.475),
        (-0.28, 0.68, 0.475), (0.28, 0.68, 0.475),
    ]
    for wpos in win_pos:
        win = trimesh.creation.box(extents=[0.10, 0.12, 0.04])
        win.apply_translation(wpos)
        cm(win, MAGIC_BLUE, 0.0, 0.1)
        p.append(win)
        # 창문 테두리
        wframe = trimesh.creation.box(extents=[0.13, 0.15, 0.02])
        wframe.apply_translation(wpos)
        cm(wframe, STONE_MID, 0.1, 0.8)
        p.append(wframe)

    # --- 마법 룬 (전면 하단) ---
    for rx_pos in [-0.35, 0, 0.35]:
        rune = trimesh.creation.cylinder(radius=0.04, height=0.02, sections=6)
        rune.apply_transform(Rx(np.pi/2))
        rune.apply_translation((rx_pos, 0.10, 0.48))
        cm(rune, RUNE_GLOW, 0.0, 0.1)
        p.append(rune)
        # 룬 십자
        rune_v = trimesh.creation.box(extents=[0.01, 0.06, 0.02])
        rune_v.apply_translation((rx_pos, 0.10, 0.490))
        cm(rune_v, RUNE_GLOW, 0.0, 0.1)
        p.append(rune_v)

    return combine(p)


def make_tower():
    """석재 감시탑: 플랫폼, 성첩, 화살 슬릿, 계단 (18 파트)"""
    p = []

    # --- 기단부 ---
    p.append(box((0.50, 0.12, 0.50), (0, 0.06, 0), color=STONE_DARK, metal=0.1, rough=0.95))
    # 기단 테두리
    p.append(box((0.54, 0.04, 0.54), (0, 0.13, 0), color=STONE_LIGHT, metal=0.1, rough=0.9))

    # --- 타워 본체 ---
    tower_body = trimesh.creation.cylinder(radius=0.22, height=0.70, sections=8)
    tower_body.apply_translation((0, 0.50, 0))
    cm(tower_body, STONE_DARK, 0.1, 0.9)
    p.append(tower_body)
    # 타워 표면 디테일 (수직 리지)
    for ta in range(8):
        rad = ta * np.pi / 4
        ridge_x = np.cos(rad) * 0.22
        ridge_z = np.sin(rad) * 0.22
        ridge = trimesh.creation.box(extents=[0.03, 0.68, 0.03])
        ridge.apply_transform(Ry(rad))
        ridge.apply_translation((ridge_x, 0.50, ridge_z))
        cm(ridge, STONE_MID, 0.1, 0.85)
        p.append(ridge)

    # --- 화살 슬릿 (4방향) ---
    for ta in [0, np.pi/2, np.pi, 3*np.pi/2]:
        sx = np.cos(ta) * 0.22
        sz = np.sin(ta) * 0.22
        slit = trimesh.creation.box(extents=[0.04, 0.16, 0.04])
        slit.apply_transform(Ry(ta))
        slit.apply_translation((sx, 0.48, sz))
        cm(slit, LEATHER_DARK)
        p.append(slit)

    # --- 상부 플랫폼 ---
    platform = trimesh.creation.cylinder(radius=0.30, height=0.08, sections=8)
    platform.apply_translation((0, 0.88, 0))
    cm(platform, STONE_LIGHT, 0.15, 0.85)
    p.append(platform)

    # --- 성첩 (6개) ---
    for ta in range(6):
        rad = ta * np.pi / 3
        tx = np.cos(rad) * 0.27
        tz = np.sin(rad) * 0.27
        tooth = trimesh.creation.box(extents=[0.10, 0.12, 0.10])
        tooth.apply_transform(Ry(rad))
        tooth.apply_translation((tx, 0.98, tz))
        cm(tooth, STONE_MID, 0.1, 0.9)
        p.append(tooth)

    # --- 지붕 콘 ---
    roof = trimesh.creation.cone(radius=0.28, height=0.25, sections=8)
    roof.apply_translation((0, 1.05, 0))
    cm(roof, (0.15, 0.16, 0.30), 0.1, 0.8)
    p.append(roof)

    return combine(p)


def make_tower_turret():
    """회전포탑: 둥근 터릿 본체, 포신 2개, 장갑 플레이트 (10 파트)"""
    p = []
    # 터릿 기저
    base = trimesh.creation.cylinder(radius=0.13, height=0.06, sections=8)
    base.apply_translation((0, 0.03, 0))
    cm(base, STONE_DARK, 0.3, 0.6)
    p.append(base)
    # 터릿 본체
    body = trimesh.creation.cylinder(radius=0.10, height=0.12, sections=8)
    body.apply_translation((0, 0.12, 0))
    cm(body, IRON_COLOR, 0.55, 0.45)
    p.append(body)
    # 포신 메인
    barrel1 = trimesh.creation.cylinder(radius=0.028, height=0.24, sections=6)
    barrel1.apply_transform(Rx(np.pi/2))
    barrel1.apply_translation((0, 0.15, 0.15))
    cm(barrel1, STEEL_DARK, 0.65, 0.35)
    p.append(barrel1)
    # 포신 링 (디테일)
    for rz in [0.04, 0.18]:
        ring = trimesh.creation.cylinder(radius=0.032, height=0.018, sections=6)
        ring.apply_transform(Rx(np.pi/2))
        ring.apply_translation((0, 0.15, rz))
        cm(ring, STEEL_LIGHT, 0.7, 0.3)
        p.append(ring)
    # 전면 장갑 플레이트
    p.append(box((0.18, 0.14, 0.04), (0, 0.14, 0.10), color=IRON_COLOR, metal=0.5, rough=0.5))
    # 측면 플레이트
    for sx in [-0.10, 0.10]:
        p.append(box((0.04, 0.12, 0.14), (sx, 0.14, 0.08), color=STONE_DARK, metal=0.3))
    # 포구 (원형 링)
    muzzle = trimesh.creation.cylinder(radius=0.032, height=0.04, sections=8)
    muzzle.apply_transform(Rx(np.pi/2))
    muzzle.apply_translation((0, 0.15, 0.27))
    cm(muzzle, STEEL_DARK, 0.65, 0.3)
    p.append(muzzle)
    return combine(p)


def make_barracks():
    """군사 롱하우스: 뾰족 지붕, 문, 창문, 굴뚝, 목재 골조 (20 파트)"""
    p = []

    # --- 기단 ---
    p.append(box((0.80, 0.06, 0.60), (0, 0.03, 0), color=STONE_DARK, metal=0.0, rough=0.95))

    # --- 메인 건물 ---
    p.append(box((0.76, 0.44, 0.56), (0, 0.25, 0), color=WOOD_DARK, metal=0.0, rough=0.9))
    # 앞 벽 (약간 밝게)
    p.append(box((0.76, 0.44, 0.04), (0, 0.25, 0.30), color=WOOD_MID, metal=0.0, rough=0.88))

    # --- 목재 골조 (X자형 보강) ---
    for bx_pos in [-0.25, 0, 0.25]:
        # 수직 기둥
        p.append(box((0.04, 0.44, 0.04), (bx_pos, 0.25, 0.295), color=WOOD_DARK))
    # 수평 보
    p.append(box((0.76, 0.04, 0.04), (0, 0.08, 0.295), color=WOOD_DARK))
    p.append(box((0.76, 0.04, 0.04), (0, 0.30, 0.295), color=WOOD_DARK))
    # 대각 보 (X자)
    for sx in [-1, 1]:
        diag = trimesh.creation.box(extents=[0.40, 0.03, 0.03])
        diag.apply_transform(Rz(sx * np.radians(32)))
        diag.apply_translation((sx*0.12, 0.20, 0.295))
        cm(diag, WOOD_DARK)
        p.append(diag)

    # --- 뾰족 지붕 (박공 지붕) ---
    for rx_pos in np.linspace(-0.35, 0.35, 6):
        rafter = trimesh.creation.box(extents=[0.06, 0.30, 0.04])
        rafter.apply_transform(Rx(np.radians(52)))
        rafter.apply_translation((rx_pos, 0.56, 0.15))
        cm(rafter, (0.18, 0.14, 0.10))
        p.append(rafter)
        rafter2 = trimesh.creation.box(extents=[0.06, 0.30, 0.04])
        rafter2.apply_transform(Rx(np.radians(-52)))
        rafter2.apply_translation((rx_pos, 0.56, -0.15))
        cm(rafter2, (0.18, 0.14, 0.10))
        p.append(rafter2)
    # 지붕 마루 (릿지빔)
    p.append(box((0.80, 0.04, 0.05), (0, 0.70, 0), color=WOOD_DARK))

    # --- 문 ---
    p.append(box((0.16, 0.26, 0.04), (0, 0.17, 0.31), color=LEATHER_DARK))
    # 문 테두리
    p.append(box((0.20, 0.30, 0.03), (0, 0.17, 0.315), color=WOOD_MID))
    # 문 손잡이
    p.append(sphere(0.018, (0.07, 0.17, 0.33), sub=0, color=IRON_COLOR, metal=0.5))

    # --- 창문 (양옆) ---
    for wx in [-0.28, 0.28]:
        p.append(box((0.14, 0.12, 0.03), (wx, 0.30, 0.31), color=MAGIC_BLUE, metal=0.0, rough=0.2))
        p.append(box((0.18, 0.16, 0.02), (wx, 0.30, 0.315), color=WOOD_MID))

    # --- 굴뚝 ---
    chimney = trimesh.creation.cylinder(radius=0.055, height=0.30, sections=6)
    chimney.apply_translation((0.28, 0.82, -0.10))
    cm(chimney, STONE_MID, 0.1, 0.9)
    p.append(chimney)
    # 굴뚝 모자
    chimney_cap = trimesh.creation.cylinder(radius=0.075, height=0.04, sections=6)
    chimney_cap.apply_translation((0.28, 0.975, -0.10))
    cm(chimney_cap, STONE_DARK, 0.1, 0.9)
    p.append(chimney_cap)
    # 연기 (반투명 구 2개)
    p.append(sphere(0.04, (0.28, 1.02, -0.10), sub=1, color=(0.45, 0.45, 0.48), rough=0.95))
    p.append(sphere(0.055, (0.30, 1.07, -0.09), sub=1, color=(0.40, 0.40, 0.44), rough=0.95))

    # --- 측면 난간 ---
    for sx in [-0.40, 0.40]:
        p.append(box((0.04, 0.22, 0.56), (sx, 0.25, 0), color=WOOD_MID))

    return combine(p)


def make_miner():
    """산업용 드릴 굴착기: 기어, 드릴비트, 지지 프레임, 크리스탈 광석 (22 파트)"""
    p = []

    # --- 기저 플레이트 ---
    p.append(box((0.50, 0.08, 0.50), (0, 0.04, 0), color=IRON_COLOR, metal=0.55, rough=0.6))
    # 기저 볼트 (코너)
    for bx, bz in [(-0.20, -0.20), (0.20, -0.20), (-0.20, 0.20), (0.20, 0.20)]:
        p.append(sphere(0.022, (bx, 0.09, bz), sub=0, color=STEEL_RIVET, metal=0.7))

    # --- 메인 바디 (박스) ---
    p.append(box((0.38, 0.30, 0.38), (0, 0.23, 0), color=STONE_DARK, metal=0.3, rough=0.7))
    # 전면 패널
    p.append(box((0.38, 0.30, 0.04), (0, 0.23, 0.20), color=IRON_COLOR, metal=0.45, rough=0.55))

    # --- 지지 프레임 (A자형) ---
    for sx in [-1, 1]:
        # 경사 지지대
        frame_leg = trimesh.creation.cylinder(radius=0.022, height=0.44, sections=5)
        frame_leg.apply_transform(Rz(sx * np.radians(20)))
        frame_leg.apply_translation((sx*0.18, 0.42, 0.06))
        cm(frame_leg, IRON_COLOR, 0.5, 0.6)
        p.append(frame_leg)
        # 수직 지지대
        frame_v = trimesh.creation.cylinder(radius=0.018, height=0.50, sections=5)
        frame_v.apply_translation((sx*0.20, 0.45, 0.06))
        cm(frame_v, IRON_COLOR, 0.5, 0.6)
        p.append(frame_v)

    # --- 기어 메커니즘 (측면) ---
    for gx in [-0.22, 0.22]:
        gear = trimesh.creation.cylinder(radius=0.10, height=0.04, sections=10)
        gear.apply_transform(Rx(np.pi/2))
        gear.apply_translation((gx, 0.36, 0.08))
        cm(gear, IRON_COLOR, 0.6, 0.4)
        p.append(gear)
        # 기어 이빨 (8개)
        for ta in range(8):
            rad = ta * np.pi / 4
            tooth_x = gx + np.cos(rad) * 0.10
            tooth_y = 0.36 + np.sin(rad) * 0.10
            tooth = trimesh.creation.box(extents=[0.022, 0.022, 0.04])
            tooth.apply_transform(Ry(rad))
            tooth.apply_translation((tooth_x, tooth_y, 0.08))
            cm(tooth, STEEL_MID, 0.55, 0.45)
            p.append(tooth)
        # 기어 중심 허브
        hub = trimesh.creation.cylinder(radius=0.03, height=0.06, sections=6)
        hub.apply_transform(Rx(np.pi/2))
        hub.apply_translation((gx, 0.36, 0.08))
        cm(hub, STEEL_DARK, 0.65, 0.35)
        p.append(hub)

    # --- 드릴 암 ---
    drill_arm = trimesh.creation.cylinder(radius=0.05, height=0.36, sections=6)
    drill_arm.apply_translation((0, 0.52, 0))
    cm(drill_arm, IRON_COLOR, 0.5, 0.55)
    p.append(drill_arm)
    # 드릴 암 링 (강화)
    for dy in [0.36, 0.50, 0.64]:
        ring = trimesh.creation.cylinder(radius=0.056, height=0.025, sections=6)
        ring.apply_translation((0, dy, 0))
        cm(ring, STEEL_MID, 0.6, 0.4)
        p.append(ring)

    # --- 드릴 비트 (나선형 콘) ---
    bit_base = trimesh.creation.cone(radius=0.08, height=0.06, sections=8)
    bit_base.apply_transform(Rx(np.pi))
    bit_base.apply_translation((0, 0.69, 0))
    cm(bit_base, STEEL_DARK, 0.7, 0.3)
    p.append(bit_base)
    # 드릴 메인 포인트
    bit_tip = trimesh.creation.cone(radius=0.04, height=0.22, sections=4)
    bit_tip.apply_translation((0, 0.78, 0))
    cm(bit_tip, STEEL_LIGHT, 0.8, 0.2)
    p.append(bit_tip)
    # 드릴 날 (가로 날개)
    for ta in range(4):
        rad = ta * np.pi / 2
        blade_bit = trimesh.creation.box(extents=[0.10, 0.06, 0.015])
        blade_bit.apply_transform(Ry(rad))
        blade_bit.apply_translation((0, 0.73, 0))
        cm(blade_bit, BLADE_COLOR, 0.8, 0.2)
        p.append(blade_bit)

    # --- 크리스탈 광석 (주변) ---
    crystal_configs = [
        (0.20, 0.02, 0.15, 20), (-0.22, 0.02, 0.12, -15),
        (0.15, 0.02, -0.20, 10), (-0.18, 0.02, -0.18, -25),
    ]
    for cx, cy, cz, cang in crystal_configs:
        crystal = trimesh.creation.cone(radius=0.04, height=0.12, sections=4)
        crystal.apply_transform(Rz(np.radians(cang)))
        crystal.apply_translation((cx, cy, cz))
        cm(crystal, CRYSTAL_MID, 0.2, 0.3)
        p.append(crystal)
        # 크리스탈 베이스
        c_base = trimesh.creation.cylinder(radius=0.05, height=0.03, sections=5)
        c_base.apply_translation((cx, cy + 0.015, cz))
        cm(c_base, CRYSTAL_DARK, 0.1, 0.5)
        p.append(c_base)

    return combine(p)


# ===================================================================
# EFFECTS
# ===================================================================

def make_projectile():
    """에너지 발사체: 발광 코어, 궤적 트레일 (6 파트)"""
    p = []
    core = trimesh.creation.icosphere(subdivisions=1, radius=0.06)
    cm(core, (1.0, 0.82, 0.28), 0.0, 0.05)
    p.append(core)
    mid = trimesh.creation.icosphere(subdivisions=1, radius=0.04)
    cm(mid, (1.0, 0.95, 0.7), 0.0, 0.02)
    p.append(mid)
    # 트레일
    trail1 = trimesh.creation.cone(radius=0.045, height=0.14, sections=6)
    trail1.apply_translation((0, -0.09, 0))
    cm(trail1, (1.0, 0.55, 0.10), 0.0, 0.3)
    p.append(trail1)
    trail2 = trimesh.creation.cone(radius=0.030, height=0.10, sections=4)
    trail2.apply_translation((0, -0.17, 0))
    cm(trail2, (0.8, 0.35, 0.05), 0.0, 0.5)
    p.append(trail2)
    # 가로 스파크 (십자)
    for ta in [0, np.pi/2]:
        spark = trimesh.creation.box(extents=[0.12, 0.012, 0.012])
        spark.apply_transform(Ry(ta))
        cm(spark, (1.0, 0.9, 0.4), 0.0, 0.1)
        p.append(spark)
    return combine(p)


def make_mineral_orb():
    """광물 오브: 팔면체 크리스탈, 내부 발광 (5 파트)"""
    p = []
    # 외부 크리스탈 (팔면체)
    outer = trimesh.creation.icosphere(subdivisions=0, radius=0.08)
    cm(outer, CRYSTAL_MID, 0.1, 0.2)
    p.append(outer)
    # 내부 발광
    inner = trimesh.creation.icosphere(subdivisions=0, radius=0.05)
    cm(inner, CRYSTAL_GLOW, 0.0, 0.05)
    p.append(inner)
    # 주변 파편 (작은 크리스탈 3개)
    for i in range(3):
        rad = i * 2 * np.pi / 3
        fx = np.cos(rad) * 0.10
        fz = np.sin(rad) * 0.10
        frag = trimesh.creation.cone(radius=0.025, height=0.06, sections=3)
        frag.apply_translation((fx, 0.02, fz))
        cm(frag, CRYSTAL_DARK, 0.1, 0.3)
        p.append(frag)
    return combine(p)


# ===================================================================
# MAIN
# ===================================================================

GENERATORS = {
    ("units",     "soldier"):      make_soldier,
    ("units",     "archer"):       make_archer,
    ("units",     "tanker"):       make_tanker,
    ("units",     "bomber"):       make_bomber,
    ("enemies",   "rusher"):       make_rusher,
    ("enemies",   "tank"):         make_tank_enemy,
    ("enemies",   "splitter"):     make_splitter,
    ("enemies",   "exploder"):     make_exploder,
    ("enemies",   "elite_rusher"): make_elite_rusher,
    ("enemies",   "destroyer"):    make_destroyer,
    ("buildings", "hq"):           make_hq,
    ("buildings", "tower"):        make_tower,
    ("buildings", "tower_turret"): make_tower_turret,
    ("buildings", "barracks"):     make_barracks,
    ("buildings", "miner"):        make_miner,
    ("effects",   "projectile"):   make_projectile,
    ("effects",   "mineral_orb"):  make_mineral_orb,
}


def main():
    print(f"SIKMUBYNCH 고품질 3D 모델 생성 ({len(GENERATORS)}개)")
    print(f"출력: {MODELS_DIR}\n")

    success = 0
    for (category, name), gen_func in GENERATORS.items():
        try:
            mesh = gen_func()
            save_glb(mesh, category, name)
            success += 1
        except Exception as e:
            import traceback
            print(f"  FAIL {category}/{name}: {e}")
            traceback.print_exc()

    print(f"\n완료: {success}/{len(GENERATORS)}")


if __name__ == "__main__":
    main()
