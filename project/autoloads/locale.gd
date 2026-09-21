extends Node

enum Lang { KO, EN }

var current_lang: int = Lang.KO

# { key: [korean, english] }
var _strings: Dictionary = {
	# Title screen
	"subtitle": ["대규모 물량 vs 방어선 — 2D 쿼터뷰 디펜스", "Massive Hordes vs Your Defense Line"],
	"start_game": ["게임 시작", "START GAME"],
	"controls_info": ["1-5: 건설  |  우클릭: 철거  |  WASD/우드래그: 카메라  |  휠: 줌  |  Space: 일시정지  |  F: 속도", "1-5: Build  |  RMB: Demolish  |  WASD/RMB drag: Camera  |  Wheel: Zoom  |  Space: Pause  |  F: Speed"],

	# HUD
	"hp": ["체력", "HP"],
	"hq_hp": ["본진 체력", "HQ HP"],
	"hq_under_attack": ["본진 공격받는 중!", "HQ UNDER ATTACK!"],
	"mineral": ["미네랄", "MINERAL"],
	"selected": ["선택", "SELECTED"],
	"wave_label": ["웨이브 %d", "WAVE %d"],
	"kills_label": ["처치 %d", "KILLS %d"],
	"enemies_label": ["적 %d", "ENEMIES %d"],
	"next_wave": ["다음: %d초", "NEXT: %ds"],
	"paused": ["일시정지", "PAUSED"],
	"threat_radar": ["위협 레이더", "THREAT RADAR"],
	"cost": ["비용", "COST"],
	"not_enough_minerals": ["미네랄 부족", "NOT ENOUGH MINERALS"],
	"cannot_place": ["배치 불가", "CANNOT PLACE"],

	# Buildings
	"HQ": ["본진", "HQ"],
	"Barricade": ["바리케이드", "Barricade"],
	"Wall": ["강화벽", "Wall"],
	"Gun Tower": ["속사 타워", "Gun Tower"],
	"Cannon": ["포격 타워", "Cannon"],
	"Frost Tower": ["감속 타워", "Frost Tower"],
	"desc_Barricade": ["싸고 약한 벽. 시간을 번다", "Cheap weak wall. Buys time"],
	"desc_Wall": ["튼튼한 벽. 핵심 길목용", "Sturdy wall for key chokepoints"],
	"desc_Gun Tower": ["단일 연사. 기본 화력", "Rapid single-target fire"],
	"desc_Cannon": ["광역 폭발. 밀집 처리", "Area blast. Clears crowds"],
	"desc_Frost Tower": ["범위 감속. 밀도를 묶는다", "Area slow. Pins the crowd"],

	# Wave types
	"wave_scout": ["정찰 웨이브", "Scout Wave"],
	"wave_density": ["밀도 웨이브", "Density Wave"],
	"wave_breach": ["돌파 웨이브", "Breach Wave"],
	"wave_storm": ["폭풍 웨이브", "Storm Wave"],
	"side_north": ["북", "N"],
	"side_east": ["동", "E"],
	"side_south": ["남", "S"],
	"side_west": ["서", "W"],
	"side_all": ["사방", "ALL SIDES"],
	"from_side": ["%s에서 %d마리", "%s: %d incoming"],

	# Game over
	"game_over": ["본진 파괴", "HQ DESTROYED"],
	"restart": ["재시작", "RESTART"],
	"result_format": ["도달 웨이브 %d\n처치 %d\n최대 동시 적 %d\n생존 %d:%02d", "Reached Wave %d\nKills %d\nPeak Enemies %d\nSurvived %d:%02d"],

	# ESC menu
	"resume": ["계속하기", "RESUME"],
	"title_screen": ["타이틀 화면", "TITLE SCREEN"],
	"vol_master": ["전체", "Master"],
	"vol_music": ["음악", "Music"],
	"vol_sfx": ["효과음", "SFX"],

	# Language toggle
	"language": ["English", "한국어"],
}

func t(key: String) -> String:
	if _strings.has(key):
		return _strings[key][current_lang]
	return key

func t_fmt(key: String, args: Array) -> String:
	var template := t(key)
	return template % args

func toggle_lang() -> void:
	current_lang = Lang.EN if current_lang == Lang.KO else Lang.KO
