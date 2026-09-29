extends RefCounted

## 결과 화면 데이터: 기록(이번 런 · 최고 · 갱신)과 다음 판 조언(뚫린 방향, 쓰지 않은 크리스탈, 잃은 건물).
## summary는 GameSimulation.run_summary(), records는 GameManager.submit_run()의 반환값이다.

const UiKit := preload("res://scenes/ui/ui_kit.gd")

## 이만큼 남기고 죽었으면 "더 지을 수 있었다"를 보여준다 (타워 몇 개 값)
const UNSPENT_HINT := 100
## 잃은 건물이 이만큼 넘으면 벽 조언
const LOST_HINT := 8
const MAX_ADVICE := 2

## 반환: {time, kills, peak, built, lost, best_time, best_kills, best_peak, new_time, new_kills, new_peak,
##        advice: [{kind: "danger"|"crystal"|"info", bold: String, rest: String}]}
static func build(summary: Dictionary, records: Dictionary) -> Dictionary:
	var out := {
		"time": float(summary["time"]),
		"kills": int(summary["kills"]),
		"peak": int(summary["peak"]),
		"built": int(summary.get("built", 0)),
		"lost": int(summary.get("lost", 0)),
	}
	for k in ["time", "kills", "peak"]:
		out["best_" + k] = records.get("best_" + k, 0.0)
		out["new_" + k] = records.get("new_" + k, false)
	var advice: Array = []
	var side := int(summary.get("breach_side", -1))
	if side >= 0:
		var share := int(round(float(summary["breach_share"]) * 100.0))
		advice.append({"kind": "danger",
			"bold": Locale.t_fmt("advice_breach", [Locale.t("side_%d" % side)]),
			"rest": Locale.t_fmt("advice_breach_rest", [share])})
	var left := int(summary.get("minerals_left", 0))
	if left >= UNSPENT_HINT:
		advice.append({"kind": "crystal",
			"bold": Locale.t_fmt("advice_unspent", [UiKit.thousands(left)]),
			"rest": Locale.t("advice_unspent_rest")})
	if int(out["lost"]) >= LOST_HINT and advice.size() < MAX_ADVICE:
		advice.append({"kind": "danger",
			"bold": Locale.t_fmt("advice_lost", [int(out["lost"])]),
			"rest": Locale.t("advice_lost_rest")})
	if advice.is_empty():
		advice.append({"kind": "info", "bold": Locale.t("advice_good"), "rest": Locale.t("advice_good_rest")})
	out["advice"] = advice.slice(0, MAX_ADVICE)
	return out
