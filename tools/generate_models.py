"""
SIKMUBYNCH 3D 모델 자동 생성 스크립트
Hunyuan3D-2 Gradio 서버에 연결하여 20개 모델을 일괄 생성합니다.

사용법:
  1. C:\AI\HY3D2\Hunyuan3D2_WinPortable\RUN.bat 실행 (서버 시작, 첫 실행 시 10분+)
  2. 브라우저에서 http://127.0.0.1:7860 접속 확인
  3. 이 스크립트 실행: python tools/generate_models.py
"""

import json
import os
import sys
import time
import shutil
from pathlib import Path

try:
    from gradio_client import Client
except ImportError:
    print("gradio_client 설치 중...")
    os.system(f"{sys.executable} -m pip install gradio_client")
    from gradio_client import Client

# 프로젝트 경로
PROJECT_ROOT = Path(__file__).parent.parent
MODELS_DIR = PROJECT_ROOT / "project" / "assets" / "models"

# 20개 모델 프롬프트
MODELS = [
    # 건물 (9종)
    ("buildings", "hq", "dark fantasy fortress headquarters, large stone castle keep, glowing blue magical runes, military fortification, low poly stylized, flat shading, game asset, isometric"),
    ("buildings", "tower", "dark fantasy attack tower with cannon turret, stone military watchtower, compact design, low poly stylized, flat shading, game asset, isometric"),
    ("buildings", "tower_turret", "small cannon turret mechanism, dark metal, military weapon, low poly stylized, flat shading, game asset"),
    ("buildings", "barracks", "dark fantasy military barracks with banner flag, troop recruitment building, wooden and stone, low poly stylized, flat shading, game asset, isometric"),
    ("buildings", "barracks_banner", "medieval banner on pole, blue flag, military standard, low poly stylized, flat shading, game asset"),
    ("buildings", "miner", "dark fantasy mining drill machine, teal crystal glow, mechanical drill, low poly stylized, flat shading, game asset, isometric"),
    ("buildings", "miner_drill", "small mechanical drill bit, teal metal, spinning tool, low poly stylized, flat shading, game asset"),
    ("buildings", "buff_tower", "dark fantasy power beacon tower, golden crystal on top, magical aura, low poly stylized, flat shading, game asset, isometric"),
    ("buildings", "buff_crystal", "floating golden crystal, magical gem, glowing energy, diamond shape, low poly stylized, flat shading, game asset"),
    # 적 (6종)
    ("enemies", "rusher", "small fast goblin creature, aggressive charging pose, sharp claws, dark fantasy, red tint, low poly stylized, flat shading, game asset"),
    ("enemies", "tank", "heavy armored beast, thick shell armor plates, dark fantasy, bulky defensive creature, dark gray, low poly stylized, flat shading, game asset"),
    ("enemies", "splitter", "diamond shaped alien creature, crystalline body, dark fantasy, green glow, splitting organism, low poly stylized, flat shading, game asset"),
    ("enemies", "exploder", "spiky explosive creature, swollen body with spines, dark fantasy, orange glow, dangerous volatile, low poly stylized, flat shading, game asset"),
    ("enemies", "elite_rusher", "elite goblin warrior with dark red armor, battle scarred, dark fantasy, glowing red eyes, low poly stylized, flat shading, game asset"),
    ("enemies", "destroyer", "massive boss demon creature, towering imposing figure, dark fantasy, purple dark aura, heavy build, low poly stylized, flat shading, game asset"),
    # 유닛 (4종)
    ("units", "soldier", "human infantry soldier with sword and shield, dark fantasy military, blue armor, standing ready pose, low poly stylized, flat shading, game asset"),
    ("units", "archer", "human archer with longbow, dark fantasy military, green hooded cloak, slim build, low poly stylized, flat shading, game asset"),
    ("units", "tanker", "heavy shield warrior, dark fantasy military, golden plate armor, wide stance defensive, low poly stylized, flat shading, game asset"),
    ("units", "bomber", "suicide bomber unit carrying explosive barrel, dark fantasy, red and blue outfit, desperate look, low poly stylized, flat shading, game asset"),
    # 이펙트 (2종)
    ("effects", "projectile", "magical energy orb projectile, glowing yellow fireball, small sphere with trail, low poly stylized, flat shading, game asset"),
    ("effects", "mineral_orb", "small glowing crystal orb, teal cyan energy, floating magical mineral, low poly stylized, flat shading, game asset"),
]


def ensure_dirs():
    for category in ["buildings", "enemies", "units", "effects"]:
        (MODELS_DIR / category).mkdir(parents=True, exist_ok=True)


def generate_all(server_url="http://127.0.0.1:7860", skip_existing=True):
    print(f"Hunyuan3D-2 서버 연결: {server_url}")
    try:
        client = Client(server_url)
    except Exception as e:
        print(f"\n연결 실패: {e}")
        print("Hunyuan3D-2 서버가 실행 중인지 확인하세요.")
        print("  1. C:\\AI\\HY3D2\\Hunyuan3D2_WinPortable\\RUN.bat 실행")
        print("  2. http://127.0.0.1:7860 접속 가능할 때까지 대기")
        sys.exit(1)

    ensure_dirs()
    total = len(MODELS)
    success = 0
    failed = []

    for i, (category, name, prompt) in enumerate(MODELS):
        output_path = MODELS_DIR / category / f"{name}.glb"

        if skip_existing and output_path.exists():
            print(f"[{i+1}/{total}] SKIP (이미 존재): {category}/{name}.glb")
            success += 1
            continue

        print(f"\n[{i+1}/{total}] 생성 중: {category}/{name}")
        print(f"  프롬프트: {prompt[:60]}...")

        try:
            # Gradio API 호출 — text-to-3D
            # 함수 시그니처는 Gradio 앱 버전에 따라 다를 수 있음
            # 일반적: (prompt, seed, steps, guidance, octree_res)
            result = client.predict(
                caption=prompt,
                api_name="/generation_all"
            )

            # result는 보통 (html_path, glb_path, ...) 튜플
            if result:
                # GLB 파일 찾기
                glb_source = None
                if isinstance(result, (list, tuple)):
                    for item in result:
                        if isinstance(item, str) and item.endswith('.glb'):
                            glb_source = item
                            break
                        elif isinstance(item, dict) and 'value' in item:
                            if str(item['value']).endswith('.glb'):
                                glb_source = item['value']
                                break
                elif isinstance(result, str) and result.endswith('.glb'):
                    glb_source = result

                if glb_source and os.path.exists(glb_source):
                    shutil.copy2(glb_source, output_path)
                    size_kb = output_path.stat().st_size / 1024
                    print(f"  성공! {size_kb:.0f}KB → {output_path}")
                    success += 1
                else:
                    print(f"  경고: GLB 파일을 찾을 수 없음. result={result}")
                    failed.append(f"{category}/{name}")
            else:
                print(f"  경고: 빈 결과")
                failed.append(f"{category}/{name}")

        except Exception as e:
            print(f"  실패: {e}")
            failed.append(f"{category}/{name}")

        # 모델 간 쿨다운
        if i < total - 1:
            print("  다음 모델 대기 (5초)...")
            time.sleep(5)

    print(f"\n{'='*50}")
    print(f"완료: {success}/{total} 성공")
    if failed:
        print(f"실패: {', '.join(failed)}")
        print("\n실패한 모델은 Hunyuan3D-2 웹 UI에서 수동 생성하세요:")
        print(f"  http://127.0.0.1:7860")
    print(f"\n모델 저장 위치: {MODELS_DIR}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="SIKMUBYNCH 3D 모델 자동 생성")
    parser.add_argument("--url", default="http://127.0.0.1:7860", help="Hunyuan3D-2 서버 URL")
    parser.add_argument("--force", action="store_true", help="기존 모델 덮어쓰기")
    parser.add_argument("--only", type=str, help="특정 카테고리만 생성 (buildings/enemies/units/effects)")
    args = parser.parse_args()

    if args.only:
        MODELS[:] = [m for m in MODELS if m[0] == args.only]
        print(f"필터: {args.only} ({len(MODELS)}개)")

    generate_all(server_url=args.url, skip_existing=not args.force)
