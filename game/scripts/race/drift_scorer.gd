extends RefCounted
class_name NitroDriftScorer
## P3 drift scoring (master brief section 3). Rewards driving quality, not
## just sliding:
##   base rate   = speed x angle (sweet spot 25-60 deg) per second
##   proximity   = up to x1.5 while the car body rides the kerb / outer gap
##   transitions = left<->right flick inside one chain adds +0.25 multiplier
##   duration    = +0.1 multiplier per 1.5 s of continuous chain (cap x5)
##   mistakes    = wall contact or a spin loses the un-banked chain
## A chain ends (and is BANKED into the total) after CHAIN_GRACE seconds
## without drifting. The HUD shows TOTAL (banked) and SCORE xN (chain).

const CHAIN_GRACE: float = 0.9
const MULTIPLIER_STEP_SECONDS: float = 1.5
const MULTIPLIER_STEP: float = 0.1
const TRANSITION_BONUS: float = 0.25
const MAX_MULTIPLIER: float = 5.0
const BASE_RATE: float = 12.0
const MIN_ANGLE: float = 10.0
const SPIN_ANGLE: float = 115.0
const CLIP_EDGE_M: float = 2.6      # car side on the kerb (edge distance)
const PROXIMITY_START_M: float = 4.2
const WALL_LOSS_SPEED: float = 2.0
const EVENT_SECONDS: float = 1.6

var total: int = 0
var chain_points: float = 0.0
var multiplier: float = 1.0
var chain_time: float = 0.0
var idle_time: float = 0.0
var step_clock: float = 0.0
var last_side: int = 0
var in_chain: bool = false
var clipped_this_chain: bool = false
var transitions: int = 0
var kerb_clips: int = 0
var chains_banked: int = 0
var chains_lost: int = 0
var best_chain: int = 0
var events: Array[Dictionary] = []

func reset() -> void:
    total = 0
    chain_points = 0.0
    multiplier = 1.0
    chain_time = 0.0
    idle_time = 0.0
    step_clock = 0.0
    last_side = 0
    in_chain = false
    clipped_this_chain = false
    transitions = 0
    kerb_clips = 0
    chains_banked = 0
    chains_lost = 0
    best_chain = 0
    events.clear()

func chain_score() -> int:
    return int(round(chain_points))

func pending_total() -> int:
    return total+int(round(chain_points*multiplier))

static func angle_factor(angle_deg: float) -> float:
    var a: float = absf(angle_deg)
    if a < MIN_ANGLE:
        return 0.0
    if a <= 25.0:
        return lerpf(0.25,1.0,(a-MIN_ANGLE)/(25.0-MIN_ANGLE))
    if a <= 60.0:
        return 1.0+0.15*(a-25.0)/35.0
    return maxf(0.3,1.15-(a-60.0)/60.0)

static func proximity_factor(edge_distance: float) -> float:
    if edge_distance >= PROXIMITY_START_M:
        return 1.0
    return 1.0+0.5*clampf((PROXIMITY_START_M-edge_distance)/(PROXIMITY_START_M-1.3),0.0,1.0)

## drifting: model.is_drifting(); angle in degrees (signed);
## edge_distance: metres from the car centre to the nearest road edge.
func update(dt: float, drifting: bool, angle_deg: float, speed_mps: float, edge_distance: float) -> void:
    _age_events(dt)
    if drifting and absf(angle_deg) >= SPIN_ANGLE:
        lose_chain("SPIN")
        return
    if drifting and absf(angle_deg) >= MIN_ANGLE:
        idle_time = 0.0
        var side: int = 1 if angle_deg > 0.0 else -1
        if not in_chain:
            in_chain = true
            chain_time = 0.0
            step_clock = 0.0
            clipped_this_chain = false
            last_side = side
        elif side != last_side:
            transitions += 1
            multiplier = minf(MAX_MULTIPLIER,multiplier+TRANSITION_BONUS)
            _event("TRANSITION  +%.2fx" % TRANSITION_BONUS)
            last_side = side
        var zone: float = proximity_factor(edge_distance)
        if edge_distance < CLIP_EDGE_M and not clipped_this_chain:
            clipped_this_chain = true
            kerb_clips += 1
            _event("KERB CLIP  x1.5")
        chain_points += speed_mps*angle_factor(angle_deg)*zone*BASE_RATE*dt
        chain_time += dt
        step_clock += dt
        while step_clock >= MULTIPLIER_STEP_SECONDS-0.0001:
            step_clock -= MULTIPLIER_STEP_SECONDS
            multiplier = minf(MAX_MULTIPLIER,multiplier+MULTIPLIER_STEP)
    elif in_chain:
        idle_time += dt
        if idle_time >= CHAIN_GRACE:
            bank()

func bank() -> void:
    if not in_chain and chain_points <= 0.0:
        return
    var gained: int = int(round(chain_points*multiplier))
    if gained > 0:
        total += gained
        chains_banked += 1
        best_chain = maxi(best_chain,gained)
        _event("BANKED  +%s" % _thousands(gained))
    _clear_chain()

func lose_chain(reason: String) -> void:
    if in_chain and chain_points > 0.0:
        chains_lost += 1
        _event(reason+"!  CHAIN LOST")
    _clear_chain()

func wall_hit(impact_speed: float) -> void:
    if impact_speed >= WALL_LOSS_SPEED:
        lose_chain("WALL")

func _clear_chain() -> void:
    in_chain = false
    chain_points = 0.0
    multiplier = 1.0
    chain_time = 0.0
    idle_time = 0.0
    step_clock = 0.0
    last_side = 0
    clipped_this_chain = false

func _event(text: String) -> void:
    events.append({"text":text,"age":0.0})
    while events.size() > 3:
        events.pop_front()

func _age_events(dt: float) -> void:
    for e in events:
        e["age"] = float(e["age"])+dt
    while not events.is_empty() and float(events[0]["age"]) > EVENT_SECONDS:
        events.pop_front()

static func _thousands(value: int) -> String:
    var digits: String = str(value)
    var end: String = ""
    while digits.length() > 3:
        end = ","+digits.substr(digits.length()-3,3)+end
        digits = digits.substr(0,digits.length()-3)
    return digits+end
