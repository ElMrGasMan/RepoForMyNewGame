class_name Nivel
extends Node2D


export(String, FILE, "*.tscn") var nivel_siguiente = ""
export var explosion: PackedScene = null
export var meteor: PackedScene = null
export var explosion_meteoro: PackedScene = null
export var lluvia_de_meteoritos: PackedScene = null
export var enemigo_ambusher: PackedScene = null
export var puerta_l: PackedScene = null
export var musica_ambiente: AudioStream = null
export var musica_combat: AudioStream = null
export var tiempo_transicion_camara: float = 3.0
export var tiempo_limite: int = 200

var cant_meteoritos_nivel: int = 0
var cant_estaciones_enemigas: int = 0
var jugador: Jugador = null
var lugar_exp: Vector2 

onready var proyectile_storage: Node
onready var meteor_storage: Node
onready var contenedor_lluvias_de_meteoritos: Node
onready var contenedor_enemigos: Node
onready var camara_nivel: Camera2D = $CamaraNivel
onready var camara_jugador: Camera2D = $Jugador/CamaraJugador
onready var timer_tiempo: Timer = $TimerActualizadorTiempo
onready var musica_juego: Node = $MusicaStellarRaiders


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	musica_juego.set_musica(musica_ambiente, musica_combat)
	musica_juego.ejecutar_musica(musica_juego.get_mus_amb())
	connect_signals()
	create_storages()
	jugador = DataJuego.get_jugador_actual()
	cant_estaciones_enemigas = cant_bases_enemigas()
	emit_signals()
	timer_tiempo.start()


# warning-ignore:unused_argument
# warning-ignore:unused_argument
func _on_TweenCamaraNivel_tween_completed(object: Object, key: NodePath) -> void:
	if object.name == "CamaraJugador":
		object.global_position = $Jugador.global_position


func _on_TimerReinicio_timeout() -> void:
	Events.emit_signal("terminar_nivel")
	yield(get_tree().create_timer(1.2), "timeout")
# warning-ignore:return_value_discarded
	get_tree().reload_current_scene()


func _on_TimerActualizadorTiempo_timeout() -> void:
	tiempo_limite -= 1
	Events.emit_signal("actualizar_tiempo", tiempo_limite)
		
	if tiempo_limite <= 0:
		timer_tiempo.stop()
		tiempo_agotado()


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
# warning-ignore:return_value_discarded
	Events.connect("base_destruida", self, "_on_base_destruida")
# warning-ignore:return_value_discarded
	Events.connect("spawn_enemigo_orbital", self,  "_on_spawn_orbital")
# warning-ignore:return_value_discarded
	Events.connect("nivel_completado", self, "_on_nivel_completado")
# warning-ignore:return_value_discarded
	Events.connect("misil_lanzado", self, "_on_shoot_misil")
# warning-ignore:return_value_discarded
	Events.connect("lanza_misiles_destruido", self, "_on_lanza_misiles_destruido")


func emit_signals() -> void:
	Events.emit_signal("comenzar_nivel")
	Events.emit_signal("actualizar_tiempo", tiempo_limite)


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
	
	contenedor_enemigos = Node.new()
	contenedor_enemigos.name = "ContenedorEnemigos"
	add_child(contenedor_enemigos)


func _on_shoot(proyectil: Proyectil) -> void:
	proyectile_storage.add_child(proyectil)


func _on_shoot_misil(misil: Misil) -> void:
	proyectile_storage.add_child(misil)


func _on_nivel_completado() -> void:
	Events.emit_signal("terminar_nivel")
	yield(get_tree().create_timer(1.0), "timeout")
# warning-ignore:return_value_discarded
	get_tree().change_scene(nivel_siguiente)


func _on_spawn_orbital(guardia: EnemigoOrbital) -> void:
	contenedor_enemigos.add_child(guardia)


func _on_player_destroyed(nave: Jugador, posicion: Vector2, num_explosions: int) -> void:
	if nave is Jugador:
		transcision_entre_camaras(
			posicion,
			posicion + crear_posicion_random(-150.0, 150),
			camara_nivel,
			tiempo_transicion_camara
			)
		$TimerReinicio.start()
	
	crear_explosiones(posicion, num_explosions, 0.4, Vector2(140.0, 80.0))


func _on_destroy_meteor(position_explosion: Vector2) -> void:
	var new_explosion:Node2D = explosion_meteoro.instance()
	new_explosion.global_position = position_explosion
	add_child(new_explosion)
	
	descontar_meteorito()


func _on_shoot_meteor(position_spawn: Vector2, direction : Vector2, size: float) -> void:
	var new_meteor: Meteoro = meteor.instance()
	new_meteor.create_meteor(position_spawn, direction, size)
	meteor_storage.add_child(new_meteor)


func _on_base_destruida(posiciones_partes: Array, _ex) -> void:
	cant_estaciones_enemigas -= 1
	
	for pos in posiciones_partes:
		crear_explosiones(pos, 1, 0.0, Vector2(60.0, 40.0))
		yield(get_tree().create_timer(0.3), "timeout")
	
	if cant_estaciones_enemigas == 0:
		crear_puerta_l()


func _on_lanza_misiles_destruido(_lanzador, explosiones: int, posicion: Vector2) -> void:
# warning-ignore:unused_variable
	for i in range(explosiones):
		crear_explosiones(posicion, 1, 0.0, Vector2(60.0, 40.0))
		yield(get_tree().create_timer(0.3), "timeout")


# warning-ignore:unused_argument
func crear_sector_meteoritos(centro_camara: Vector2, cant_peligros: int) -> void:
	musica_juego.transicion_entre_musicas()
	cant_meteoritos_nivel = cant_peligros
	
	var new_sector_lluvia: MeteorRain = lluvia_de_meteoritos.instance()
	new_sector_lluvia.crear_lluvia(centro_camara, cant_peligros)
	camara_nivel.global_position = centro_camara
	contenedor_lluvias_de_meteoritos.add_child(new_sector_lluvia)
	
	camara_nivel.zoom = camara_jugador.zoom
	camara_nivel.devolver_zoom()
	transcision_entre_camaras(camara_jugador.global_position, camara_nivel.global_position, camara_nivel, tiempo_transicion_camara)


func crear_sector_enemigos(cant_enemigos: int) -> void:
# warning-ignore:unused_variable
	for i in range(cant_enemigos):
		var new_ambusher: EnemigoAmbusher = enemigo_ambusher.instance()
		var posicion_spawn: Vector2 = crear_posicion_random(1000.0, 800.0)
		new_ambusher.global_position = jugador.global_position + posicion_spawn
		contenedor_enemigos.add_child(new_ambusher)


func _on_player_sector_peligroso(centro_camara: Vector2, clase_peligro: String, cant_peligros: int):
	if clase_peligro == "Meteorite":
		crear_sector_meteoritos(centro_camara, cant_peligros)
		Events.emit_signal("cambio_numero_met", cant_meteoritos_nivel)
		
	elif clase_peligro == "Enemy":
		crear_sector_enemigos(cant_peligros)


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
	Events.emit_signal("cambio_numero_met", cant_meteoritos_nivel)
	
	if cant_meteoritos_nivel == 0:
		musica_juego.transicion_entre_musicas()
		contenedor_lluvias_de_meteoritos.get_child(0).queue_free()
		camara_jugador.set_puede_hacer_zoom(true)
		var zoom_actual = camara_jugador.zoom
		camara_jugador.zoom = camara_nivel.zoom
		camara_jugador.suavizar_zoom(zoom_actual.x, zoom_actual.y, 3.0)
		transcision_entre_camaras(camara_nivel.global_position, camara_jugador.global_position, camara_jugador, tiempo_transicion_camara * 0.05)


func crear_posicion_random(rango_x: float, rango_y: float) -> Vector2:
	randomize()
	var random_x = rand_range(-rango_x, rango_x)
	var random_y = rand_range(-rango_y, rango_y)
	
	return Vector2(random_x, random_y)


func crear_explosiones(posicion: Vector2, cant_explosiones: int, intervalo_exp: float, rangos_explosiones: Vector2) -> void:
# warning-ignore:unused_variable
	for i in range(cant_explosiones):
		var new_explosion:Node2D = explosion.instance()
		new_explosion.global_position = posicion + crear_posicion_random(rangos_explosiones.x, rangos_explosiones.y)
		add_child(new_explosion)
		yield(get_tree().create_timer(intervalo_exp), "timeout")


func cant_bases_enemigas() -> int:
	return $AlmacenEstacionesEnemigas.get_child_count()


func crear_puerta_l() -> void:
	var new_puerta_l: PuertaL = puerta_l.instance() 
	var pos_aleatoria: Vector2 = crear_posicion_random(400.0, 200.0)
	var margen_max: Vector2 = Vector2(800.0, 800.0)
	
	if pos_aleatoria.x < 0:
		margen_max *= -1
	
	if pos_aleatoria.y < 0:
		margen_max *= -1
	
	new_puerta_l.global_position = jugador.global_position + (margen_max + pos_aleatoria)
	add_child(new_puerta_l)


func tiempo_agotado() -> void:
	lugar_exp = jugador.global_position 
	crear_explosiones(lugar_exp, 10, 0.2, Vector2(400.0, 300.0))
	jugador.destroy_player()
