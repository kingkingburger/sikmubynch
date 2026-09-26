extends RefCounted

## 결과 화면 문구: 기록(이번 런 · 최고 · 갱신)과 실패 원인 단서(뚫린 방향, 건물 손실, 쓰지 않은 미네랄).
## summary는 GameSimulation.run_summary(), records는 GameManager.submit_run()의 반환값이다.

## 이만큼 남기고 죽었으면 "더 지을 수 있었다"를 보여준다 (타워 몇 개 값)
const UNSPENT_HINT_MINERALS := 100

static func build(summary: Dictionary, records: Dictionary) -> String:
	var secs := int(summary["time"])
	var lines: PackedStringArray = []
	lines.append(_record_line(Locale.t_fmt("result_time", [secs / 60, secs % 60]),
		_clock(float(records.get("best_time", 0.0))), records.get("new_time", false)))
	lines.append(_record_line(Locale.t_fmt("result_kills", [int(summary["kills"])]),
		str(int(records.get("best_kills", 0.0))), records.get("new_kills", false)))
	lines.append(_record_line(Locale.t_fmt("result_peak", [int(summary["peak"])]),
		str(int(records.get("best_peak", 0.0))), records.get("new_peak", false)))
	lines.append("")
	var side := int(summary["breach_side"])
	if side >= 0:
		var share := int(round(float(summary["breach_share"]) * 100.0))
		lines.append(Locale.t_fmt("result_breach", [Locale.t("side_%d" % side), share]))
	lines.append(Locale.t_fmt("result_lines", [int(summary["built"]), int(summary["lost"])]))
	var left := int(summary["minerals_left"])
	if left >= UNSPENT_HINT_MINERALS:
		lines.append(Locale.t_fmt("result_unspent", [left]))
	return "\n".join(lines)

static func _clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

static func _record_line(current: String, best: String, is_new: bool) -> String:
	if is_new:
		return "%s   %s" % [current, Locale.t("result_new_best")]
	return "%s   (%s)" % [current, Locale.t_fmt("result_best", [best])]
