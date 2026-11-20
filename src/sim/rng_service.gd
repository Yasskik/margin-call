class_name RNGService
extends RefCounted
## Deterministic seeded RNG with Box-Muller Gaussian. The ONLY randomness source in src/sim/.

var seed_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spare: float = 0.0
var _has_spare: bool = false


func _init(p_seed: int = 0) -> void:
	seed_value = p_seed
	_rng.seed = p_seed


func next_float() -> float:
	return _rng.randf()


## Alias matching the blueprint wording (`rng.randf()`).
func randf() -> float:
	return _rng.randf()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Standard normal variate via the Box-Muller transform (caches the paired sample).
func rand_gaussian() -> float:
	if _has_spare:
		_has_spare = false
		return _spare
	var u1: float = maxf(_rng.randf(), 1e-12)
	var u2: float = _rng.randf()
	var r: float = sqrt(-2.0 * log(u1))
	var theta: float = TAU * u2
	_spare = r * sin(theta)
	_has_spare = true
	return r * cos(theta)


## Weighted pick over {key: weight}. Keys are sorted so the result never depends on dict order.
func weighted_pick(weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total: float = 0.0
	for k: Variant in keys:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return str(keys[0]) if not keys.is_empty() else ""
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for k: Variant in keys:
		acc += maxf(float(weights[k]), 0.0)
		if roll < acc:
			return str(k)
	return str(keys[keys.size() - 1])


## Weighted index over parallel float weights.
func weighted_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for i: int in weights.size():
		acc += maxf(weights[i], 0.0)
		if roll < acc:
			return i
	return weights.size() - 1


## Independent child stream (e.g. market vs. shop) derived deterministically from this seed.
func fork(salt: int) -> RNGService:
	return RNGService.new(hash([seed_value, salt]))
