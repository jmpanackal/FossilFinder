extends Node

## Teach-as-you-play tips. Each one shows once, the first time its situation
## comes up: as a ribbon under the pit during a dig, as a toast elsewhere (main.gd
## does the showing). GameState remembers which were shown; Settings can turn
## tips off or bring them all back.

const KEY_PREFIX := "tip_"

## In the order a new player is likely to meet them.
const TIPS: Array[Dictionary] = [
	{"id": "dig", "title": "Dig for bones", "text": "Click the dirt to dig. There may be bones buried below."},
	{"id": "sifted", "title": "Sifted finds", "text": "Digging can turn up small finds that sell for cash."},
	{"id": "pocket", "title": "Amber pocket!", "text": "Strike the glowing amber before it fades for cash."},
	{"id": "tools", "title": "New tool", "text": "Press 1-4 or scroll to switch tools."},
	{"id": "hold", "title": "Hold to dig", "text": "Hold the mouse button to keep digging."},
	{"id": "sense", "title": "Bone Sense", "text": "Hand digging now marks bone in nearby cells."},
	{"id": "collect", "title": "Bone uncovered!", "text": "Collected at shift end. A Brush cleans it for more $."},
	{"id": "summary", "title": "What next?", "text": "Spend money in Upgrades. Bones go to the Museum."},
	{"id": "shop", "title": "Upgrades", "text": "Locked tiers open once the tier before is maxed."},
	{"id": "museum", "title": "Your museum", "text": "Visitors pay you every second. Hover a stand for info."},
	{"id": "ribbon", "title": "New bone!", "text": "Click a gold ribbon to unveil it for a visitor rush."},
	{"id": "dirty", "title": "Dirty bone", "text": "Dirty bones earn less. A Brush cleans them in the dig."},
	{"id": "feature", "title": "Featured exhibit", "text": "Click a stand to feature it for extra visitors."},
	{"id": "complete", "title": "Next goal", "text": "Make every bone 5-star and clean for a Masterpiece."},
	{"id": "cart", "title": "Cleaning Cart", "text": "Drag it onto an exhibit. It closes while cleaning."},
]

## Tips waiting to be shown: {"id", "title", "text"}.
var pending: Array[Dictionary] = []


func enabled() -> bool:
	return Settings.tips_enabled


func tip_data(id: String) -> Dictionary:
	for tip in TIPS:
		if str(tip["id"]) == id:
			return tip
	return {}


func seen(id: String) -> bool:
	return GameState.hints_seen.has(KEY_PREFIX + id)


func is_pending(id: String) -> bool:
	for entry in pending:
		if str(entry["id"]) == id:
			return true
	return false


## Ask for a tip. Nothing happens if tips are off, it was already shown or is
## already waiting. `text` replaces the default wording (some tips depend on
## what you own). Returns true if it was queued.
func teach(id: String, text: String = "") -> bool:
	if not enabled() or seen(id) or is_pending(id):
		return false
	var data: Dictionary = tip_data(id)
	if data.is_empty():
		return false
	pending.append({"id": id, "title": str(data["title"]), "text": text if not text.is_empty() else str(data["text"])})
	return true


## The next tip to show (and mark it seen), or {} when none is waiting.
func next_tip() -> Dictionary:
	if pending.is_empty():
		return {}
	var entry: Dictionary = pending.pop_front()
	GameState.hints_seen[KEY_PREFIX + str(entry["id"])] = true
	return entry


## Bring every tip back (they show again as their moments come up).
func reset_seen() -> void:
	pending.clear()
	for tip in TIPS:
		GameState.hints_seen.erase(KEY_PREFIX + str(tip["id"]))
