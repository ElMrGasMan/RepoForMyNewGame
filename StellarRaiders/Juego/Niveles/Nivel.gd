class_name Nivel
extends Node2D


export var explosion: PackedScene = null
export var meteor: PackedScene = null
export var explosion_meteor: PackedScene = null
export var lluvia_de_meteoritos: PackedScene = null
export var tiempo_transicion_camara: float = 3.0

onready var proyectile_storage: Node
onready var meteor_storage: Node
onready var contenedor_lluvias_de_meteoritos: Node
onready var camara_nivel: Camera2D = $CamaraNivel
onready var camara_jugador: Camera2D = $McCarran/CamaraJugador

var cant_meteoritos_nivel: int = 0


func _ready() -> void:
	connect_signals()
	create_storages()


# warning-ignore:unused_argument
func _on_TweenCamaraNivel_tween_completed(object: Object, key: NodePath) -> void:
	if object.name == "CamaraJugador":
		object.global_position = $McCarran.global_position
func _on_shoot(proyectil:Proyectil) -> void:
	proyectile_storage.add_child(proyectil)


func connect_signals() -> void:
# warning-ignore:return_value_discarded
	Events.connect("jugador_en_sector_peligroso", self, "_on_player_sector_peligroso")
# warning-ignore:return_value_discarded
	Events.connect("shoot", self, "_on_shoot")
# warning-ignore:return_value_discarded
	Events.connect("player_destroyed", self, "_on_player_destroyed")
# warning-ignore:return_value_discarded
	Events.connect("shoot_meteor", self, "_on_shoot_meteor")
# warning-ignore:return_value_discarded
	Events.connect("destroy_meteor", self, "_on_destroy_meteor")


func create_storages() -> void:
	proyectile_storage = Node.new()
	proyectile_storage.name = "ProyectileStorage"
	add_child(proyectile_storage)
	
	meteor_storage = Node.new()
	meteor_storage.name = "MeteorStorage"
	add_child(meteor_storage)
	
	contenedor_lluvias_de_meteoritos = Node.new()
	contenedor_lluvias_de_meteoritos.name = "ContenedorLluviasMeteoritos"
	add_child(contenedor_lluvias_de_meteoritos)


func _on_player_destroyed(position: Vector2, num_explosions: int) -> void:
# warning-ignore:unused_variable
	for i in range(num_explosions):
		var new_explosion:Node2D = explosion.instance()
		new_explosion.global_position = position
		add_child(new_explosion)
		yield(get_tree().create_timer(0.4), "timeout")


func _on_destroy_meteor(position_explosion: Vector2) -> void:
	var new_explosion:Node2D = explosion_meteor.instance()
	new_explosion.global_position = position_explosion
	add_child(new_explosion)
	
	descontar_meteorito()


func _on_shoot_meteor(position_spawn: Vector2, direction : Vector2, size: float) -> void:
	var new_meteor: Meteor = meteor.instance()
	new_meteor.create_meteor(position_spawn, direction, size)
	meteor_storage.add_child(new_meteor)


# warning-ignore:unused_argument
func crear_sector_meteoritos(centro_camara: Vector2, cant_peligros: int) -> void:
	cant_meteoritos_nivel = cant_peligros
	
	var new_sector_lluvia: MeteorRain = lluvia_de_meteoritos.instance()
	new_sector_lluvia.crear_lluvia(centro_camara, cant_peligros)
	camara_nivel.global_position = centro_camara
	contenedor_lluvias_de_meteoritos.add_child(new_sector_lluvia)
	
	camara_nivel.zoom = camara_jugador.zoom
	camara_nivel.devolver_zoom()
	transcision_entre_camaras(camara_jugador.global_position, camara_nivel.global_position, camara_nivel, tiempo_transicion_camara)


func _on_player_sector_peligroso(centro_camara: Vector2, clase_peligro: String, cant_peligros: int):
	if clase_peligro == "Meteorite":
		crear_sector_meteoritos(centro_camara, cant_peligros)
		
	elif clase_peligro == "Enemy":
		pass


func transcision_entre_camaras(desde: Vector2, hasta: Vector2, camara_actual: Camera2D, tiempo_transicion: float):
	$TweenCamaraNivel.interpolate_property(
		camara_actual, 
		"global_position", 
		desde, 
		hasta, 
		tiempo_transicion, 
		Tween.TRANS_CIRC, 
		Tween.EASE_OUT
		)
	camara_actual.current = true
	$TweenCamaraNivel.start()


func descontar_meteorito() -> void:
	cant_meteoritos_nivel -= 1
	print(cant_meteoritos_nivel)
	
	if cant_meteoritos_nivel == 0:
		contenedor_lluvias_de_meteoritos.get_child(0).queue_free()
		camara_jugador.set_puede_hacer_zoom(true)
		var zoom_actual = camara_jugador.zoom
		camara_jugador.zoom = camara_nivel.zoom
		camara_jugador.suavizar_zoom(zoom_actual.x, zoom_actual.y, 3.0)
		transcision_entre_camaras(camara_nivel.global_position, camara_jugador.global_position, camara_jugador, tiempo_transicion_camara * 0.05)
