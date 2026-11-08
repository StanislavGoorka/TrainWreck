## Floor pickups (coins, keys, hearts, bombs) and item pedestals.
extends "res://tests/helpers/tw_test_suite.gd"

const PICKUP_SCENE := preload("res://Test/PickUps/pick_up.tscn")
const PEDESTAL_SCENE := preload("res://Test/Scenes/InGameElements/pedestal.tscn")
const PedestalScript := preload("res://Test/Scripts/RoomRelated/pedestal.gd")

var player: Player


func before_test() -> void:
	super.before_test()
	player = auto_free(Factory.player())
	add_child(player)


# --- Pickups -----------------------------------------------------------------------

func _pickup(data: PickupData) -> Area2D:
	var pickup: Area2D = auto_free(PICKUP_SCENE.instantiate())
	pickup.pickup_data = data
	add_child(pickup)
	return pickup


func test_pickup_shows_its_icon() -> void:
	var data := Factory.pickup(PickupData.PickupType.COIN)
	data.icon = Factory.texture(Vector2(16, 16))
	var pickup := _pickup(data)
	assert_object(pickup.sprite.texture).is_same(data.icon)


func test_player_collects_the_pickup() -> void:
	var pickup := _pickup(Factory.pickup(PickupData.PickupType.COIN, 3))
	pickup._on_body_entered(player)
	assert_int(player.currency).is_equal(3)
	assert_bool(pickup.is_queued_for_deletion()).is_true()


func test_non_players_do_not_collect_pickups() -> void:
	var pickup := _pickup(Factory.pickup(PickupData.PickupType.KEY))
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	pickup._on_body_entered(enemy)
	assert_bool(pickup.is_queued_for_deletion()).is_false()


func test_empty_pickup_is_left_alone() -> void:
	var pickup := _pickup(null)
	pickup._on_body_entered(player)
	assert_bool(pickup.is_queued_for_deletion()).is_false()


func test_walking_over_a_pickup_collects_it() -> void:
	var pickup := _pickup(Factory.pickup(PickupData.PickupType.KEY, 1))
	pickup.collision_mask = 2
	player.global_position = pickup.global_position
	await wait_physics_frames(3)
	assert_int(player.keys).is_equal(1)


# --- Pedestals ---------------------------------------------------------------------

func _all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir := DirAccess.open(PedestalScript.ITEM_RESOURCE_FOLDER)
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			items.append(load(PedestalScript.ITEM_RESOURCE_FOLDER + file_name))
	return items


func _pedestal(item: ItemData = null, pools := ItemData.POOL_ITEM_ROOM) -> Area2D:
	var pedestal: Area2D = auto_free(PEDESTAL_SCENE.instantiate())
	pedestal.item_data = item
	pedestal.draw_from_pools = pools
	add_child(pedestal)
	return pedestal


func test_rarity_weights_cover_every_rarity_and_sum_to_one() -> void:
	var total := 0.0
	for rarity in ItemData.Rarity.values():
		assert_bool(PedestalScript.RARITY_WEIGHTS.has(rarity)).is_true()
		total += PedestalScript.RARITY_WEIGHTS[rarity]
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_pedestal_with_a_fixed_item_shows_it() -> void:
	var item := Factory.item({"item_name": "Fixed", "icon": Factory.texture()})
	var pedestal := _pedestal(item)
	assert_object(pedestal.item_data).is_same(item)
	assert_object(pedestal.item_sprite.texture).is_same(item.icon)


func test_pedestal_draws_a_random_item_from_the_pool() -> void:
	var pedestal := _pedestal()
	assert_object(pedestal.item_data).is_not_null()
	assert_int(pedestal.item_data.pools & ItemData.POOL_ITEM_ROOM).is_not_zero()
	assert_object(pedestal.item_sprite.texture).is_not_null()


func test_pedestal_never_offers_an_item_the_player_owns() -> void:
	var items := _all_items()
	var remaining: ItemData = null
	for item in items:
		if item.pools & ItemData.POOL_ITEM_ROOM:
			if remaining == null:
				remaining = item
			else:
				player.add_item(item, true)
	for i in 10:
		var pedestal := _pedestal()
		assert_str(pedestal.item_data.item_name).is_equal(remaining.item_name)


func test_boss_pedestals_only_draw_boss_items() -> void:
	for i in 20:
		var pedestal := _pedestal(null, ItemData.POOL_BOSS)
		assert_object(pedestal.item_data).is_not_null()
		assert_int(pedestal.item_data.pools & ItemData.POOL_BOSS).is_not_zero()


func test_pedestal_is_empty_when_everything_is_owned() -> void:
	for item in _all_items():
		player.add_item(item, true)
	var pedestal := _pedestal()
	assert_object(pedestal.item_data).is_null()
	pedestal._on_body_entered(player)
	assert_bool(pedestal.is_queued_for_deletion()).is_false()


func test_random_draws_cover_several_items() -> void:
	seed(42)
	var names := {}
	for i in 40:
		names[_pedestal().item_data.item_name] = true
	assert_int(names.size()).is_greater(1)


func test_player_takes_the_item_from_the_pedestal() -> void:
	var item := Factory.item({"item_name": "Prize"})
	var pedestal := _pedestal(item)
	var picked := []
	player.item_picked_up.connect(func(it: ItemData) -> void: picked.append(it))
	pedestal._on_body_entered(player)
	assert_array(player.inventory).contains_exactly(item)
	assert_array(picked).contains_exactly(item)
	assert_bool(pedestal.is_queued_for_deletion()).is_true()


func test_enemies_cannot_take_pedestal_items() -> void:
	var pedestal := _pedestal(Factory.item())
	var enemy: Enemy = auto_free(Factory.enemy())
	add_child(enemy)
	pedestal._on_body_entered(enemy)
	assert_bool(pedestal.is_queued_for_deletion()).is_false()
