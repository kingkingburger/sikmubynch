extends Node

enum Lang { KO, EN }

var current_lang: int = Lang.KO

# { key: [korean, english] }
var _strings: Dictionary = {
	# Title screen
	"subtitle": ["웨이브 디펜스 + 오토배틀 + 로그라이크", "Wave Defense + Auto Battle + Roguelike"],
	"start_game": ["게임 시작", "START GAME"],
	"controls_info": ["1-5: 건설  |  WASD: 카메라  |  스크롤: 줌  |  Space: 일시정지  |  F: 속도", "1-5: Build  |  WASD: Camera  |  Scroll: Zoom  |  Space: Pause  |  F: Speed"],

	# HUD
	"hp": ["체력", "HP"],
	"mineral": ["미네랄", "MINERAL"],
	"hud_format": ["웨이브 %d  |  처치 %d  |  적 %d", "WAVE %d  |  KILLS %d  |  ENEMIES %d"],
	"next_wave": ["다음: %d초", "NEXT: %ds"],
	"paused": ["일시정지", "PAUSED"],

	# Buildings
	"Barricade": ["바리케이드", "Barricade"],
	"Tower": ["타워", "Tower"],
	"Barracks": ["배럭", "Barracks"],
	"Miner": ["채굴기", "Miner"],
	"Buff Tower": ["버프타워", "Buff Tower"],

	# Game over
	"game_over": ["게임 오버", "GAME OVER"],
	"restart": ["재시작", "RESTART"],
	"result_format": ["웨이브: %d  |  처치: %d  |  시간: %d:%02d", "Wave: %d  |  Kills: %d  |  Time: %d:%02d"],

	# Card UI
	"choose_reward": ["보상 선택", "CHOOSE A REWARD"],
	"skip": ["건너뛰기", "SKIP"],

	# Rarity
	"rarity_common": ["일반", "Common"],
	"rarity_rare": ["희귀", "Rare"],
	"rarity_legendary": ["전설", "Legendary"],

	# Reward cards
	"card_mineral_cache": ["미네랄 저장고", "Mineral Cache"],
	"card_mineral_vein": ["미네랄 광맥", "Mineral Vein"],
	"card_mineral_surge": ["미네랄 급등", "Mineral Surge"],
	"card_motherlode": ["대광맥", "Motherlode"],
	"card_fortified_walls": ["강화 성벽", "Fortified Walls"],
	"card_iron_fortress": ["철의 요새", "Iron Fortress"],
	"card_titans_blessing": ["거인의 축복", "Titan's Blessing"],
	"card_sharp_blades": ["날카로운 칼날", "Sharp Blades"],
	"card_war_drums": ["전쟁 북소리", "War Drums"],
	"card_berserker_rage": ["광전사의 분노", "Berserker Rage"],
	"card_essence_suffix": ["의 정수", " Essence"],
	"card_trait_desc": ["%s 특성을 랜덤 타워에 부여", "Grant %s trait to a random tower"],
	"card_mineral_desc": ["+%d 미네랄", "+%d minerals"],
	"card_building_hp": ["전체 건물 +%d%% 체력", "All buildings +%d%% HP"],
	"card_building_hp_heal": ["전체 건물 +%d%% 체력 + 회복", "All buildings +%d%% HP + heal"],
	"card_unit_dps": ["전체 유닛 +%d%% 공격력", "All units +%d%% DPS"],

	# Trait names
	"trait_fire": ["화염", "Fire"],
	"trait_ice": ["냉기", "Ice"],
	"trait_poison": ["독", "Poison"],
	"trait_electric": ["전기", "Electric"],
	"trait_fortify": ["강화", "Fortify"],

	# ESC menu
	"resume": ["계속하기", "RESUME"],
	"title_screen": ["타이틀 화면", "TITLE SCREEN"],

	# Rarity
	"Common": ["일반", "Common"],
	"Rare": ["희귀", "Rare"],
	"Legendary": ["전설", "Legendary"],

	# Traits
	"Fire": ["화염", "Fire"],
	"Ice": ["빙결", "Ice"],
	"Poison": ["맹독", "Poison"],
	"Electric": ["전기", "Electric"],
	"Fortify": ["강화", "Fortify"],

	# Card names
	"Mineral Cache": ["미네랄 보급", "Mineral Cache"],
	"Mineral Vein": ["미네랄 광맥", "Mineral Vein"],
	"Mineral Surge": ["미네랄 폭발", "Mineral Surge"],
	"Motherlode": ["대광맥", "Motherlode"],
	"Fortified Walls": ["강화 성벽", "Fortified Walls"],
	"Iron Fortress": ["철벽 요새", "Iron Fortress"],
	"Titan's Blessing": ["타이탄의 축복", "Titan's Blessing"],
	"Sharp Blades": ["날카로운 검", "Sharp Blades"],
	"War Drums": ["전쟁 북", "War Drums"],
	"Berserker Rage": ["광전사의 분노", "Berserker Rage"],
	" Essence": [" 정수", " Essence"],
	"Grant ": ["부여: ", "Grant "],
	" trait to a random tower": [" 특성을 랜덤 타워에 부여", " trait to a random tower"],

	# Card descriptions
	"All buildings +15% HP": ["모든 건물 체력 +15%", "All buildings +15% HP"],
	"All buildings +30% HP": ["모든 건물 체력 +30%", "All buildings +30% HP"],
	"All buildings +50% HP + heal": ["모든 건물 체력 +50% + 회복", "All buildings +50% HP + heal"],
	"All units +10% DPS": ["모든 유닛 공격력 +10%", "All units +10% DPS"],
	"All units +25% DPS": ["모든 유닛 공격력 +25%", "All units +25% DPS"],
	"All units +50% DPS": ["모든 유닛 공격력 +50%", "All units +50% DPS"],

	# Combat events
	"Mineral Rush": ["미네랄 러시", "Mineral Rush"],
	"Bonus +40 minerals!": ["보너스 +40 미네랄!", "Bonus +40 minerals!"],
	"Speed Surge": ["속도 폭증", "Speed Surge"],
	"Enemies move 30% faster this wave!": ["적이 이번 웨이브에 30% 빨라집니다!", "Enemies move 30% faster this wave!"],
	"Enemy Enrage": ["적 격노", "Enemy Enrage"],
	"Enemies deal 50% more damage!": ["적이 50% 더 강해집니다!", "Enemies deal 50% more damage!"],
	"Field Repair": ["전투 수리", "Field Repair"],
	"All buildings healed 30%!": ["모든 건물 30% 회복!", "All buildings healed 30%!"],
	"Bonus Wave": ["보너스 웨이브", "Bonus Wave"],
	"Double mineral rewards this wave!": ["이번 웨이브 미네랄 보상 2배!", "Double mineral rewards this wave!"],

	# Choice events
	"Gamble": ["도박", "Gamble"],
	"Risk minerals for a bigger reward?": ["미네랄을 걸고 큰 보상을 노리시겠습니까?", "Risk minerals for a bigger reward?"],
	"Bet 50 → Win 150": ["50 배팅 → 150 획득", "Bet 50 → Win 150"],
	"Pass": ["패스", "Pass"],
	"Sacrifice": ["희생", "Sacrifice"],
	"Sacrifice a building for power?": ["건물을 희생하여 힘을 얻으시겠습니까?", "Sacrifice a building for power?"],
	"Sacrifice → +200 minerals": ["희생 → +200 미네랄", "Sacrifice → +200 minerals"],
	"Keep all": ["유지", "Keep all"],
	"Empower": ["강화", "Empower"],
	"Spend minerals to buff all units?": ["미네랄을 사용하여 유닛을 강화하시겠습니까?", "Spend minerals to buff all units?"],
	"Pay 80 → Units +30% DPS (permanent)": ["80 지불 → 유닛 공격력 +30% (영구)", "Pay 80 → Units +30% DPS (permanent)"],
	"Save minerals": ["미네랄 저축", "Save minerals"],
	"Trade": ["교역", "Trade"],
	"A merchant offers a deal.": ["상인이 거래를 제안합니다.", "A merchant offers a deal."],
	"Pay 60 → Random trait essence": ["60 지불 → 랜덤 특성 정수", "Pay 60 → Random trait essence"],
	"No thanks": ["거절", "No thanks"],
	"Challenge": ["도전", "Challenge"],
	"Face a harder wave for better rewards?": ["더 강한 웨이브에 도전하시겠습니까?", "Face a harder wave for better rewards?"],
	"Accept Challenge (+50% enemies, +100% rewards)": ["도전 수락 (적 +50%, 보상 +100%)", "Accept Challenge (+50% enemies, +100% rewards)"],
	"Normal wave": ["일반 웨이브", "Normal wave"],

	# Choice results
	"Won 150 minerals!": ["150 미네랄 획득!", "Won 150 minerals!"],
	"Lost the bet...": ["배팅에 졌습니다...", "Lost the bet..."],
	"Not enough minerals!": ["미네랄이 부족합니다!", "Not enough minerals!"],
	"Played it safe.": ["안전하게 넘어갔습니다.", "Played it safe."],
	"Building sacrificed! +200 minerals": ["건물 희생! +200 미네랄", "Building sacrificed! +200 minerals"],
	"No buildings to sacrifice!": ["희생할 건물이 없습니다!", "No buildings to sacrifice!"],
	"Buildings preserved.": ["건물을 유지합니다.", "Buildings preserved."],
	"Units empowered! +30% DPS": ["유닛 강화! 공격력 +30%", "Units empowered! +30% DPS"],
	"Minerals saved.": ["미네랄을 저축했습니다.", "Minerals saved."],
	"Maybe next time.": ["다음 기회에.", "Maybe next time."],
	"Challenge accepted! Brace yourself!": ["도전 수락! 각오하세요!", "Challenge accepted! Brace yourself!"],
	"Normal wave incoming.": ["일반 웨이브가 시작됩니다.", "Normal wave incoming."],

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

