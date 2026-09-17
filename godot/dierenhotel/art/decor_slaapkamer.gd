class_name ArtDecorSlaapkamer
extends RefCounted
## Decor models for the two bedrooms.  Same primitives, same palette and the same
## bake path as `ArtDecor`, which merges this table into its own (see
## `ArtDecor.tabel()` and `ArtDecor.alle_namen()`).  Every model is anchored at
## (0, 0, 0) on the floor, y upward, and is registered as a protected world model.

## Every model name this file provides, in a fixed order.
const NAMEN: Array[String] = []

## `naam -> Callable(params) -> Array` of voxels {x, y, z, k}.
static func tabel() -> Dictionary:
	return {}
