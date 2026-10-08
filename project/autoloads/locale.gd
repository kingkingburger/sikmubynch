extends Node

enum Lang { KO, EN }

var current_lang: int = Lang.KO

## 언어가 바뀌면 화면이 문구를 다시 채운다
signal language_changed()

# { key: [korean, english] }
# 플레이어가 읽는 문구다. 개발 용어(유입률, 쿼터뷰, 물량 등)를 쓰지 않는다.
var _strings: Dictionary = {
	# 타이틀
	"tagline": ["끝없이 몰려오는 괴물 떼로부터 기지를 지켜라.", "Hold your base against an endless alien swarm."],
	"tagline_sub": ["타워를 세우고, 벽을 쌓고, 화력을 모으세요.\n당신의 방어선은 몇 분이나 버틸 수 있을까요?",
		"Raise towers, stack walls, focus your fire.\nHow long can your line hold?"],
	"start_game": ["게임 시작", "Start Game"],
	"how_to_play": ["조작 방법", "How to Play"],
	"settings": ["설정", "Settings"],
	"quit": ["나가기", "Quit"],
	"close": ["닫기", "Close"],
	"best_time": ["최고 생존", "Best Time"],
	"best_kills": ["최다 처치", "Most Kills"],
	"runs": ["플레이", "Runs"],
	"runs_fmt": ["%d판", "%d"],
	"sound_on": ["소리 켜짐", "Sound On"],
	"sound_off": ["소리 꺼짐", "Sound Off"],
	"language_name": ["한국어", "English"],
	"language": ["언어", "Language"],

	# 조작 방법
	"ctl_select": ["건물 고르기", "Pick a building"],
	"ctl_build": ["짓기 (벽은 끌어서 줄지어)", "Build (drag to line up walls)"],
	"ctl_demolish": ["철거 (비용 절반 돌려받음)", "Demolish (half refund)"],
	"ctl_move": ["화면 이동", "Move camera"],
	"ctl_zoom": ["확대 · 축소", "Zoom"],
	"ctl_pause": ["일시정지", "Pause"],
	"ctl_speed": ["배속", "Game speed"],
	"ctl_auto_play": ["자동 플레이 켜기 · 끄기", "Toggle auto play"],
	"auto_play_off": ["자동 OFF", "AUTO OFF"],
	"auto_play_on": ["자동 ON", "AUTO ON"],
	"ctl_menu": ["메뉴", "Menu"],
	"key_lmb": ["좌클릭", "Left Click"],
	"key_rmb": ["우클릭", "Right Click"],
	"key_move": ["WASD · 우클릭 드래그", "WASD · Right Drag"],
	"key_wheel": ["마우스 휠", "Mouse Wheel"],
	"hint_build": ["건물 선택", "Pick"],
	"hint_place": ["짓기", "Build"],
	"hint_demolish": ["철거", "Demolish"],

	# HUD
	"hq": ["본진", "Base"],
	"hq_under_attack": ["본진이 공격받고 있습니다", "Your base is under attack"],
	"survival": ["생존 시간", "Survived"],
	"kills": ["처치", "Kills"],
	"enemies": ["적", "Enemies"],
	"income_label": ["+%d / 초", "+%d / s"],
	"gain_popup": ["+%d", "+%d"],
	"threat": ["위협", "Threat"],
	"paused": ["일시정지", "Paused"],
	"stat_damage": ["피해", "Damage"],
	"stat_range": ["사거리", "Range"],
	"stat_rate": ["공격 속도", "Fire Rate"],
	"stat_hp": ["체력", "Health"],
	"stat_range_fmt": ["%d칸", "%d"],
	"rate_very_fast": ["매우 빠름", "Very Fast"],
	"rate_fast": ["빠름", "Fast"],
	"rate_normal": ["보통", "Normal"],
	"rate_slow": ["느림", "Slow"],

	# 건물
	"HQ": ["본진", "Base"],
	"Barricade": ["바리케이드", "Barricade"],
	"Wall": ["강화벽", "Wall"],
	"Gun Tower": ["속사 타워", "Gun Tower"],
	"Cannon": ["포격 타워", "Cannon"],
	"Frost Tower": ["감속 타워", "Frost Tower"],
	"Flame Tower": ["화염 타워", "Flame Tower"],
	"Tesla Tower": ["전격 타워", "Tesla Tower"],
	"Sniper Tower": ["저격 타워", "Sniper Tower"],
	"desc_Barricade": ["싸고 빠르게 까는 벽. 적의 발을 묶어 시간을 법니다. 끌어서 줄지어 지을 수 있어요.",
		"Cheap, quick wall that holds the swarm back. Drag to build a line."],
	"desc_Wall": ["튼튼한 벽. 절대 뚫리면 안 되는 길목에 두세요.", "Sturdy wall for chokepoints that must not fall."],
	"desc_Gun Tower": ["빠르게 한 마리씩 쏩니다. 싸고, 많이 지을수록 강합니다.", "Rapid single shots. Cheap — build lots of them."],
	"desc_Cannon": ["포탄이 터지며 주변 적을 한꺼번에 날립니다.", "Shells explode and blow away whole groups."],
	"desc_Frost Tower": ["주변 적을 느리게 만들어 다른 타워가 더 오래 쏘게 합니다.", "Slows nearby enemies so other towers get more shots."],
	"desc_Flame Tower": ["가까운 적을 한꺼번에 태웁니다. 벽 바로 뒤에 두세요.", "Burns everything close by. Place it right behind walls."],
	"desc_Tesla Tower": ["번개가 적 사이를 튀며 여러 마리를 동시에 맞힙니다.", "Lightning jumps between enemies, hitting many at once."],
	"desc_Sniper Tower": ["멀리서 한 줄을 꿰뚫습니다. 덩치 큰 적을 먼저 노립니다.", "Long shot that pierces a line. Targets the biggest enemy."],

	# 결과
	"hq_fallen": ["본진 함락", "Base Destroyed"],
	"new_best": ["새 기록!", "New Best!"],
	"best_fmt": ["최고 %s", "Best %s"],
	"peak": ["최대 동시 적", "Largest Swarm"],
	"built": ["지은 건물", "Built"],
	"lost_fmt": ["잃은 건물 %d", "Lost %d"],
	"advice_title": ["다음 판을 위한 조언", "Tips for the next run"],
	"advice_breach": ["%s가 가장 많이 뚫렸어요.", "The %s side broke most often."],
	"advice_breach_rest": ["본진 피해의 %d%%가 그쪽에서 왔습니다.", "%d%% of base damage came from there."],
	"advice_unspent": ["크리스탈 %s개를 쓰지 않았어요.", "You left %s crystals unspent."],
	"advice_unspent_rest": ["타워를 더 지을 수 있었습니다.", "You could have built more towers."],
	"advice_lost": ["건물을 %d개 잃었어요.", "You lost %d buildings."],
	"advice_lost_rest": ["타워 앞에 벽을 두면 오래 버팁니다.", "Walls in front keep towers alive longer."],
	"advice_good": ["잘 버텼어요!", "Well held!"],
	"advice_good_rest": ["다른 배치로도 도전해 보세요.", "Try a different layout next time."],
	"retry": ["다시 도전", "Try Again"],
	"to_title": ["타이틀로", "Title"],
	"side_0": ["오른쪽 위", "upper right"],
	"side_1": ["오른쪽 아래", "lower right"],
	"side_2": ["왼쪽 아래", "lower left"],
	"side_3": ["왼쪽 위", "upper left"],

	# 일시정지 메뉴
	"resume": ["계속하기", "Resume"],
	"restart": ["처음부터", "Restart"],
	"title_screen": ["타이틀 화면", "Title Screen"],
	"vol_master": ["전체", "Master"],
	"vol_music": ["음악", "Music"],
	"vol_sfx": ["효과음", "Effects"],
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
	language_changed.emit()
