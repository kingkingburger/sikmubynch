"""
SIKMUBYNCH 로우폴리 3D 모델 생성 (trimesh)
Hunyuan3D-2 없이 프로그래밍적으로 GLB 모델 생성

사용법: cd tools && uv run python create_models.py
"""
import numpy as np
import trimesh
from pathlib import Path

MODELS_DIR = Path(__file__).parent.parent / "project" / "assets" / "models"


def make_material(color, metallic=0.0, roughness=0.7):
    """PBR 머티리얼 생성"""
    from trimesh.visual.material import PBRMaterial
    c = np.array(color[:3] + [1.0] if len(color) == 3 else color) * 255
    return PBRMaterial(
        baseColorFactor=c.astype(np.uint8).tolist(),
        metallicFactor=metallic,
        roughnessFactor=roughness,
    )


def color_mesh(mesh, color, metallic=0.0, roughness=0.7):
    """메쉬에 색상 적용"""
    mat = make_material(color, metallic, roughness)
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def combine(parts):
    """여러 메쉬를 하나로 합치기"""
    return trimesh.util.concatenate(parts)


def save_glb(mesh, category, name):
    """GLB 파일 저장"""
    out_dir = MODELS_DIR / category
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.glb"
    mesh.export(str(path), file_type="glb")
    size_kb = path.stat().st_size / 1024
    print(f"  {category}/{name}.glb ({size_kb:.0f}KB)")
    return path


# ===================================================================
# UNITS (4종)
# ===================================================================

def make_soldier():
    parts = []
    # Body (torso)
    body = trimesh.creation.cylinder(radius=0.12, height=0.3, sections=8)
    body.apply_translation([0, 0.25, 0])
    color_mesh(body, [0.2, 0.35, 0.7], metallic=0.3)
    parts.append(body)
    # Head
    head = trimesh.creation.icosphere(subdivisions=1, radius=0.09)
    head.apply_translation([0, 0.48, 0])
    color_mesh(head, [0.85, 0.7, 0.55])
    parts.append(head)
    # Helmet
    helmet = trimesh.creation.icosphere(subdivisions=1, radius=0.1)
    helmet.apply_translation([0, 0.5, 0])
    # Cut bottom half by keeping only top vertices
    color_mesh(helmet, [0.3, 0.3, 0.4], metallic=0.6)
    parts.append(helmet)
    # Left arm
    larm = trimesh.creation.cylinder(radius=0.04, height=0.22, sections=6)
    larm.apply_translation([-0.16, 0.28, 0])
    color_mesh(larm, [0.2, 0.35, 0.7], metallic=0.3)
    parts.append(larm)
    # Right arm
    rarm = trimesh.creation.cylinder(radius=0.04, height=0.22, sections=6)
    rarm.apply_translation([0.16, 0.28, 0])
    color_mesh(rarm, [0.2, 0.35, 0.7], metallic=0.3)
    parts.append(rarm)
    # Legs
    for x in [-0.06, 0.06]:
        leg = trimesh.creation.cylinder(radius=0.045, height=0.18, sections=6)
        leg.apply_translation([x, 0.09, 0])
        color_mesh(leg, [0.15, 0.15, 0.25])
        parts.append(leg)
    # Sword (right hand)
    blade = trimesh.creation.box(extents=[0.02, 0.3, 0.01])
    blade.apply_translation([0.2, 0.35, 0.08])
    color_mesh(blade, [0.8, 0.8, 0.85], metallic=0.8, roughness=0.2)
    parts.append(blade)
    # Shield (left hand)
    shield = trimesh.creation.cylinder(radius=0.1, height=0.02, sections=6)
    shield.apply_translation([-0.18, 0.28, 0.1])
    R = trimesh.transformations.rotation_matrix(np.pi/2, [1, 0, 0])
    shield.apply_transform(R)
    shield.apply_translation([0, 0, 0.05])
    color_mesh(shield, [0.5, 0.4, 0.2], metallic=0.4)
    parts.append(shield)
    return combine(parts)


def make_archer():
    parts = []
    # Slender body
    body = trimesh.creation.cylinder(radius=0.09, height=0.32, sections=8)
    body.apply_translation([0, 0.26, 0])
    color_mesh(body, [0.2, 0.45, 0.25])
    parts.append(body)
    # Head
    head = trimesh.creation.icosphere(subdivisions=1, radius=0.08)
    head.apply_translation([0, 0.5, 0])
    color_mesh(head, [0.85, 0.7, 0.55])
    parts.append(head)
    # Hood
    hood = trimesh.creation.cone(radius=0.11, height=0.12, sections=6)
    hood.apply_translation([0, 0.55, 0])
    color_mesh(hood, [0.15, 0.35, 0.15])
    parts.append(hood)
    # Arms
    for x in [-0.13, 0.13]:
        arm = trimesh.creation.cylinder(radius=0.03, height=0.24, sections=6)
        arm.apply_translation([x, 0.28, 0])
        color_mesh(arm, [0.2, 0.45, 0.25])
        parts.append(arm)
    # Legs
    for x in [-0.05, 0.05]:
        leg = trimesh.creation.cylinder(radius=0.04, height=0.16, sections=6)
        leg.apply_translation([x, 0.08, 0])
        color_mesh(leg, [0.25, 0.2, 0.15])
        parts.append(leg)
    # Bow (curved cylinder)
    bow = trimesh.creation.cylinder(radius=0.015, height=0.35, sections=6)
    bow.apply_translation([-0.18, 0.35, 0.05])
    color_mesh(bow, [0.45, 0.3, 0.1])
    parts.append(bow)
    # Quiver on back
    quiver = trimesh.creation.cylinder(radius=0.03, height=0.2, sections=6)
    quiver.apply_translation([0, 0.35, -0.12])
    color_mesh(quiver, [0.4, 0.25, 0.1])
    parts.append(quiver)
    return combine(parts)


def make_tanker():
    parts = []
    # Wide body
    body = trimesh.creation.box(extents=[0.28, 0.3, 0.22])
    body.apply_translation([0, 0.25, 0])
    color_mesh(body, [0.6, 0.55, 0.3], metallic=0.5)
    parts.append(body)
    # Head
    head = trimesh.creation.icosphere(subdivisions=1, radius=0.1)
    head.apply_translation([0, 0.48, 0])
    color_mesh(head, [0.85, 0.7, 0.55])
    parts.append(head)
    # Heavy helmet
    helmet = trimesh.creation.box(extents=[0.22, 0.1, 0.18])
    helmet.apply_translation([0, 0.52, 0])
    color_mesh(helmet, [0.5, 0.45, 0.2], metallic=0.7, roughness=0.3)
    parts.append(helmet)
    # Shoulder pads
    for x in [-0.18, 0.18]:
        pad = trimesh.creation.box(extents=[0.08, 0.06, 0.1])
        pad.apply_translation([x, 0.38, 0])
        color_mesh(pad, [0.5, 0.45, 0.2], metallic=0.6)
        parts.append(pad)
    # Legs
    for x in [-0.08, 0.08]:
        leg = trimesh.creation.cylinder(radius=0.055, height=0.16, sections=6)
        leg.apply_translation([x, 0.08, 0])
        color_mesh(leg, [0.35, 0.3, 0.15], metallic=0.3)
        parts.append(leg)
    # Big shield
    shield = trimesh.creation.box(extents=[0.25, 0.3, 0.03])
    shield.apply_translation([0, 0.25, 0.16])
    color_mesh(shield, [0.55, 0.5, 0.25], metallic=0.5, roughness=0.3)
    parts.append(shield)
    return combine(parts)


def make_bomber():
    parts = []
    # Round body
    body = trimesh.creation.icosphere(subdivisions=1, radius=0.14)
    body.apply_translation([0, 0.22, 0])
    color_mesh(body, [0.7, 0.35, 0.15])
    parts.append(body)
    # Head
    head = trimesh.creation.icosphere(subdivisions=1, radius=0.08)
    head.apply_translation([0, 0.42, 0])
    color_mesh(head, [0.85, 0.7, 0.55])
    parts.append(head)
    # Legs
    for x in [-0.06, 0.06]:
        leg = trimesh.creation.cylinder(radius=0.04, height=0.12, sections=6)
        leg.apply_translation([x, 0.06, 0])
        color_mesh(leg, [0.3, 0.2, 0.1])
        parts.append(leg)
    # Bomb barrel on back
    barrel = trimesh.creation.cylinder(radius=0.08, height=0.15, sections=8)
    barrel.apply_translation([0, 0.28, -0.14])
    color_mesh(barrel, [0.3, 0.15, 0.05])
    parts.append(barrel)
    # Fuse
    fuse = trimesh.creation.cylinder(radius=0.01, height=0.1, sections=4)
    fuse.apply_translation([0, 0.38, -0.14])
    color_mesh(fuse, [1.0, 0.6, 0.1])
    parts.append(fuse)
    # Fuse tip
    tip = trimesh.creation.icosphere(subdivisions=0, radius=0.025)
    tip.apply_translation([0, 0.43, -0.14])
    color_mesh(tip, [1.0, 0.4, 0.0])
    parts.append(tip)
    return combine(parts)


# ===================================================================
# ENEMIES (6종)
# ===================================================================

def make_rusher():
    parts = []
    # Angular body
    body = trimesh.creation.cone(radius=0.12, height=0.25, sections=4)
    body.apply_translation([0, 0.15, 0])
    color_mesh(body, [0.75, 0.15, 0.1])
    parts.append(body)
    # Head with glowing eyes
    head = trimesh.creation.icosphere(subdivisions=0, radius=0.08)
    head.apply_translation([0, 0.32, 0.04])
    color_mesh(head, [0.6, 0.1, 0.05])
    parts.append(head)
    # Claws (2)
    for x in [-0.1, 0.1]:
        claw = trimesh.creation.cone(radius=0.02, height=0.12, sections=3)
        claw.apply_translation([x, 0.15, 0.1])
        R = trimesh.transformations.rotation_matrix(-np.pi/4, [1, 0, 0])
        claw.apply_transform(R)
        color_mesh(claw, [0.9, 0.2, 0.1])
        parts.append(claw)
    # Legs
    for x in [-0.06, 0.06]:
        leg = trimesh.creation.cylinder(radius=0.03, height=0.1, sections=4)
        leg.apply_translation([x, 0.05, 0])
        color_mesh(leg, [0.5, 0.1, 0.05])
        parts.append(leg)
    return combine(parts)


def make_tank_enemy():
    parts = []
    # Heavy box body
    body = trimesh.creation.box(extents=[0.35, 0.3, 0.35])
    body.apply_translation([0, 0.2, 0])
    color_mesh(body, [0.35, 0.25, 0.4], metallic=0.4)
    parts.append(body)
    # Armor plates
    for x in [-0.2, 0.2]:
        plate = trimesh.creation.box(extents=[0.04, 0.25, 0.3])
        plate.apply_translation([x, 0.22, 0])
        color_mesh(plate, [0.3, 0.2, 0.35], metallic=0.6)
        parts.append(plate)
    # Head
    head = trimesh.creation.box(extents=[0.18, 0.12, 0.15])
    head.apply_translation([0, 0.42, 0.02])
    color_mesh(head, [0.4, 0.3, 0.5], metallic=0.3)
    parts.append(head)
    # Spikes on top
    for x in [-0.08, 0, 0.08]:
        spike = trimesh.creation.cone(radius=0.02, height=0.08, sections=4)
        spike.apply_translation([x, 0.5, 0])
        color_mesh(spike, [0.5, 0.3, 0.6])
        parts.append(spike)
    return combine(parts)


def make_splitter():
    parts = []
    # Diamond body (two cones)
    top = trimesh.creation.cone(radius=0.15, height=0.2, sections=4)
    top.apply_translation([0, 0.25, 0])
    color_mesh(top, [0.4, 0.7, 0.15])
    parts.append(top)
    bottom = trimesh.creation.cone(radius=0.15, height=0.15, sections=4)
    R = trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0])
    bottom.apply_transform(R)
    bottom.apply_translation([0, 0.15, 0])
    color_mesh(bottom, [0.35, 0.6, 0.1])
    parts.append(bottom)
    # Seam line (split indicator)
    seam = trimesh.creation.box(extents=[0.22, 0.015, 0.22])
    seam.apply_translation([0, 0.2, 0])
    color_mesh(seam, [0.6, 1.0, 0.3])
    parts.append(seam)
    return combine(parts)


def make_exploder():
    parts = []
    # Swollen sphere body
    body = trimesh.creation.icosphere(subdivisions=1, radius=0.18)
    body.apply_translation([0, 0.22, 0])
    color_mesh(body, [0.9, 0.45, 0.1])
    parts.append(body)
    # Spines
    for angle in range(0, 360, 45):
        rad = np.radians(angle)
        spine = trimesh.creation.cone(radius=0.02, height=0.1, sections=3)
        x = np.cos(rad) * 0.18
        z = np.sin(rad) * 0.18
        spine.apply_translation([x, 0.25, z])
        color_mesh(spine, [1.0, 0.5, 0.05])
        parts.append(spine)
    # Glow core
    core = trimesh.creation.icosphere(subdivisions=1, radius=0.08)
    core.apply_translation([0, 0.22, 0])
    color_mesh(core, [1.0, 0.7, 0.2])
    parts.append(core)
    return combine(parts)


def make_elite_rusher():
    parts = []
    # Armored angular body
    body = trimesh.creation.cone(radius=0.14, height=0.3, sections=5)
    body.apply_translation([0, 0.18, 0])
    color_mesh(body, [0.8, 0.1, 0.15], metallic=0.4)
    parts.append(body)
    # Head
    head = trimesh.creation.icosphere(subdivisions=0, radius=0.09)
    head.apply_translation([0, 0.38, 0.03])
    color_mesh(head, [0.65, 0.08, 0.1])
    parts.append(head)
    # Crown horns
    for x in [-0.08, 0, 0.08]:
        horn = trimesh.creation.cone(radius=0.02, height=0.1, sections=4)
        horn.apply_translation([x, 0.48, 0])
        color_mesh(horn, [0.9, 0.15, 0.2])
        parts.append(horn)
    # Armor plates
    chest = trimesh.creation.box(extents=[0.2, 0.12, 0.08])
    chest.apply_translation([0, 0.25, 0.08])
    color_mesh(chest, [0.4, 0.05, 0.08], metallic=0.7)
    parts.append(chest)
    # Legs
    for x in [-0.06, 0.06]:
        leg = trimesh.creation.cylinder(radius=0.035, height=0.12, sections=4)
        leg.apply_translation([x, 0.06, 0])
        color_mesh(leg, [0.5, 0.08, 0.1])
        parts.append(leg)
    return combine(parts)


def make_destroyer():
    parts = []
    # Massive body
    body = trimesh.creation.box(extents=[0.4, 0.45, 0.35])
    body.apply_translation([0, 0.3, 0])
    color_mesh(body, [0.2, 0.08, 0.3], metallic=0.3)
    parts.append(body)
    # Head
    head = trimesh.creation.box(extents=[0.22, 0.18, 0.2])
    head.apply_translation([0, 0.6, 0.04])
    color_mesh(head, [0.25, 0.1, 0.35], metallic=0.4)
    parts.append(head)
    # Eye
    eye = trimesh.creation.icosphere(subdivisions=0, radius=0.04)
    eye.apply_translation([0, 0.62, 0.14])
    color_mesh(eye, [1.0, 0.15, 0.0])
    parts.append(eye)
    # Shoulder pauldrons
    for x in [-0.25, 0.25]:
        pad = trimesh.creation.box(extents=[0.12, 0.08, 0.14])
        pad.apply_translation([x, 0.5, 0])
        color_mesh(pad, [0.3, 0.12, 0.4], metallic=0.6)
        parts.append(pad)
    # Helm crest
    crest = trimesh.creation.box(extents=[0.04, 0.15, 0.03])
    crest.apply_translation([0, 0.75, 0])
    color_mesh(crest, [0.4, 0.1, 0.5])
    parts.append(crest)
    # Legs
    for x in [-0.1, 0.1]:
        leg = trimesh.creation.cylinder(radius=0.07, height=0.2, sections=6)
        leg.apply_translation([x, 0.1, 0])
        color_mesh(leg, [0.15, 0.06, 0.2])
        parts.append(leg)
    return combine(parts)


# ===================================================================
# BUILDINGS (간소화 - 주요 5종)
# ===================================================================

def make_hq():
    parts = []
    # Main keep
    base = trimesh.creation.box(extents=[0.8, 0.6, 0.8])
    base.apply_translation([0, 0.3, 0])
    color_mesh(base, [0.2, 0.25, 0.5], metallic=0.3)
    parts.append(base)
    # Towers at corners
    for x, z in [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)]:
        tower = trimesh.creation.cylinder(radius=0.08, height=0.8, sections=6)
        tower.apply_translation([x, 0.4, z])
        color_mesh(tower, [0.25, 0.3, 0.55], metallic=0.4)
        parts.append(tower)
    # Roof
    roof = trimesh.creation.cone(radius=0.5, height=0.2, sections=4)
    roof.apply_translation([0, 0.7, 0])
    color_mesh(roof, [0.15, 0.2, 0.4])
    parts.append(roof)
    return combine(parts)


def make_tower():
    parts = []
    # Base
    base = trimesh.creation.cylinder(radius=0.2, height=0.5, sections=6)
    base.apply_translation([0, 0.25, 0])
    color_mesh(base, [0.3, 0.35, 0.4], metallic=0.3)
    parts.append(base)
    # Platform
    platform = trimesh.creation.cylinder(radius=0.25, height=0.05, sections=6)
    platform.apply_translation([0, 0.52, 0])
    color_mesh(platform, [0.35, 0.4, 0.45], metallic=0.4)
    parts.append(platform)
    return combine(parts)


def make_tower_turret():
    parts = []
    turret = trimesh.creation.cylinder(radius=0.1, height=0.15, sections=8)
    turret.apply_translation([0, 0.08, 0])
    color_mesh(turret, [0.6, 0.55, 0.2], metallic=0.7, roughness=0.3)
    parts.append(turret)
    # Barrel
    barrel = trimesh.creation.cylinder(radius=0.03, height=0.2, sections=6)
    barrel.apply_translation([0, 0.12, 0.12])
    R = trimesh.transformations.rotation_matrix(np.pi/2, [1, 0, 0])
    barrel.apply_transform(R)
    color_mesh(barrel, [0.4, 0.35, 0.15], metallic=0.8)
    parts.append(barrel)
    return combine(parts)


def make_barracks():
    parts = []
    # Main building
    building = trimesh.creation.box(extents=[0.6, 0.4, 0.5])
    building.apply_translation([0, 0.2, 0])
    color_mesh(building, [0.35, 0.25, 0.15])
    parts.append(building)
    # Roof
    roof = trimesh.creation.box(extents=[0.65, 0.05, 0.55])
    roof.apply_translation([0, 0.42, 0])
    color_mesh(roof, [0.25, 0.18, 0.1])
    parts.append(roof)
    # Door
    door = trimesh.creation.box(extents=[0.12, 0.2, 0.02])
    door.apply_translation([0, 0.12, 0.26])
    color_mesh(door, [0.2, 0.15, 0.08])
    parts.append(door)
    return combine(parts)


def make_miner():
    parts = []
    # Base
    base = trimesh.creation.box(extents=[0.35, 0.25, 0.35])
    base.apply_translation([0, 0.12, 0])
    color_mesh(base, [0.2, 0.4, 0.42])
    parts.append(base)
    # Drill arm
    arm = trimesh.creation.cylinder(radius=0.04, height=0.3, sections=6)
    arm.apply_translation([0, 0.35, 0])
    color_mesh(arm, [0.3, 0.6, 0.65], metallic=0.5)
    parts.append(arm)
    # Drill bit
    bit = trimesh.creation.cone(radius=0.06, height=0.12, sections=6)
    R = trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0])
    bit.apply_transform(R)
    bit.apply_translation([0, 0.5, 0])
    color_mesh(bit, [0.2, 0.7, 0.75], metallic=0.7)
    parts.append(bit)
    return combine(parts)


# ===================================================================
# EFFECTS (2종)
# ===================================================================

def make_projectile():
    parts = []
    core = trimesh.creation.icosphere(subdivisions=1, radius=0.08)
    color_mesh(core, [1.0, 0.8, 0.2])
    parts.append(core)
    trail = trimesh.creation.cone(radius=0.06, height=0.15, sections=6)
    trail.apply_translation([0, -0.1, 0])
    color_mesh(trail, [1.0, 0.5, 0.1])
    parts.append(trail)
    return combine(parts)


def make_mineral_orb():
    parts = []
    # Crystal shape (octahedron)
    orb = trimesh.creation.icosphere(subdivisions=0, radius=0.07)
    color_mesh(orb, [0.2, 0.8, 0.85])
    parts.append(orb)
    return combine(parts)


# ===================================================================
# MAIN
# ===================================================================

GENERATORS = {
    ("units", "soldier"): make_soldier,
    ("units", "archer"): make_archer,
    ("units", "tanker"): make_tanker,
    ("units", "bomber"): make_bomber,
    ("enemies", "rusher"): make_rusher,
    ("enemies", "tank"): make_tank_enemy,
    ("enemies", "splitter"): make_splitter,
    ("enemies", "exploder"): make_exploder,
    ("enemies", "elite_rusher"): make_elite_rusher,
    ("enemies", "destroyer"): make_destroyer,
    ("buildings", "hq"): make_hq,
    ("buildings", "tower"): make_tower,
    ("buildings", "tower_turret"): make_tower_turret,
    ("buildings", "barracks"): make_barracks,
    ("buildings", "miner"): make_miner,
    ("effects", "projectile"): make_projectile,
    ("effects", "mineral_orb"): make_mineral_orb,
}


def main():
    print(f"SIKMUBYNCH 3D 모델 생성 ({len(GENERATORS)}개)")
    print(f"출력: {MODELS_DIR}\n")

    success = 0
    for (category, name), gen_func in GENERATORS.items():
        try:
            mesh = gen_func()
            save_glb(mesh, category, name)
            success += 1
        except Exception as e:
            print(f"  FAIL {category}/{name}: {e}")

    print(f"\n완료: {success}/{len(GENERATORS)}")


if __name__ == "__main__":
    main()
