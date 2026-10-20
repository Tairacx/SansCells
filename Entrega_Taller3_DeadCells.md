# Taller 3 — Dead Cells: el Prisionero cobra vida

**Desarrollo de Videojuegos 2D y 3D — Corte 1 | Sesión 3**

- **Nombre completo:** [TU NOMBRE COMPLETO]
- **Fecha:** [FECHA]
- **Entrega:** documento por estudiante (PDF o enlace)

---

## Nivel 1 — Correr, subir o caer

### Antes de programar

**1. Si eligen "correr" con la tecla, ¿qué se ve cuando el Prisionero empuja una pared? ¿Y con la velocidad real en x?**

Al elegir la animación con la tecla, el Prisionero se vería "corriendo" aunque esté empujando la pared y no avance: las piernas se moverían en el lugar. Con la **velocidad real en x**, en cambio, tras `move_and_slide()` la pared cancela ese movimiento y `get_real_velocity().x` queda en 0, así que se muestra "quieto". Es como alguien caminando en una caminadora: mueve las piernas, pero no avanza.

**2. En el aire hay dos animaciones: "saltar" (sube) y "caer" (baja). ¿Con qué dato las distinguen? ¿Qué animación se ve en el frame del punto más alto?**

Se distinguen con el signo de la velocidad real en y (`get_real_velocity().y`). Como en pantalla Y crece hacia abajo, subir es velocidad y **negativa** y caer es **positiva**. En el frame del punto más alto la velocidad vertical es prácticamente 0, así que la condición de "subir" ya no se cumple y se muestra **"caer"**.

**3. El salto arranca a 560 px/s y la gravedad le resta 1200 px/s cada segundo. ¿Cuánto tarda en llegar al punto más alto? ¿Cuántos frames? ¿Qué altura alcanza? ¿Puede pasar la pared de 2 bloques?**

- Tiempo al punto más alto: t = v / g = 560 / 1200 ≈ **0.467 s**.
- Frames: 0.467 s × 60 fps ≈ **28 frames**.
- Altura: h = v² / (2g) = 560² / 2400 ≈ **130.7 px**.
- Sí pasa la pared de 2 bloques (128 px), **por poco**.

**Predicción vs. resultado:** la simulación dio el punto más alto en el frame ~28 y a unos ~135 px (un poco más que la fórmula porque el juego avanza a saltos de 1/60 s). Coincidió con lo predicho, y el margen extra explica por qué la pared se pasa por muy poco.

### Código

```gdscript
func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y < 0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")
```

### Capturas

- [CAPTURA: consola del salto en el lugar mostrando "saltar" → "caer" → "quieto"]
- [CAPTURA: empujando la pared con la tecla presionada → muestra "quieto"]

---

## Nivel 2 — Mirar hacia donde va, el golpe y la espada

### Antes de programar

**1. El Prisionero mira a la izquierda con flip_h = true. ¿Dónde queda el área Golpe: delante o detrás?**

**Detrás.** `flip_h` solo espeja el dibujo, **no** a los nodos hijos. El `Golpe` es un hijo en x = +36; al voltear solo el sprite, el área sigue en +36, que ahora queda a la espalda. Es como el reflejo del espejo: cambia de lado, pero el objeto real (el lápiz) sigue en la misma mano.

**2. ¿Qué tiene que pasarle a golpe.position.x cuando mira a la izquierda?**

Debe pasar de +36 a **−36**, es decir, multiplicarlo por `mirando` (`36 * mirando`).

**3. El sonido de la espada dura 0.25 s. Con `if not ...playing` y atacando dos veces en 0.1 s, ¿cuántos golpes se oyen? ¿Cuántos deberían oírse?**

Con `if not sonido.playing` se oiría **1**: el segundo ataque (0.1 s después) cae mientras el sonido de 0.25 s aún suena, así que la condición lo bloquea. Pero deberían oírse **2**, porque cada ataque es un **evento** distinto. Por eso se llama `play()` directo (que reinicia el sonido) y no se pregunta por `playing`.

### Código

```gdscript
var mirando = 1

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando
```

```gdscript
if Input.is_action_just_pressed("atacar"):
	espada.play()
```

### Capturas

- [CAPTURA: cuadro rojo del Golpe delante mirando a la derecha (+36)]
- [CAPTURA: cuadro rojo del Golpe delante mirando a la izquierda (−36)]

---

## Nivel 3 — El ritmo de las piernas, y rodar

### Antes de programar

**1. Fórmula de speed_scale para "correr".**

`speed_scale = abs(real.x) / speed`. En otras palabras, la animación corre proporcional a la rapidez real: a 220 px/s va normal (1), a 110 va a la mitad (0.5).

**2. La animación "rodar" tiene 6 cuadros a 15 FPS. ¿Cuánto dura? ¿Cuántos frames de física? ¿Cuántos píxeles recorre a 400 px/s?**

- Duración: 6 / 15 = **0.4 s**.
- Frames de física: 0.4 × 60 = **24 frames**.
- Distancia: 400 px/s × 0.4 s = **160 px**.

**3. ¿Con qué variable se controla que no cambie de dirección ni vuelva a rodar? ¿Qué pasa si "rodar" tiene Loop y se espera `await sprite.animation_finished`?**

Se controla con `rodando` (un estado/candado, como `muriendo` en Pac-Man): mientras es `true`, no se lee el teclado. Con Loop activado la animación **nunca termina**, así que nunca se emite la señal `animation_finished`; el `await` nunca continúa y `rodando` se queda en `true` para siempre → rueda infinitamente.

**4. ¿AudioStreamPlayer2D o AudioStreamPlayer para rodar?**

`AudioStreamPlayer2D`, porque el sonido **sale de donde está el Prisionero** (tiene posición en el mundo y se atenúa con la distancia). No es un aviso global del juego.

### Código

```gdscript
@export var velocidad_rodar = 400.0
var rodando = false

func _physics_process(delta):
	if rodando:
		velocity.x = velocidad_rodar * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
```

### Capturas

- [CAPTURA: el Prisionero rodando]
- [CAPTURA/nota: rodando dura ~0.4 s y recorre ~160 px]
- [CAPTURA/nota: con Loop activado rueda para siempre]

---

## Respuestas finales

**a. ¿Por qué la animación se decide con `is_on_floor()` y la velocidad real, y no con las teclas?**

Porque las teclas expresan la **intención** del jugador, no lo que el personaje hace de verdad. Empujando una pared la tecla está presionada pero `velocity.x` es 0 (la colisión lo cancela), así que decidir con la tecla mostraría "correr" sin moverse. `is_on_floor()` indica el estado real tras `move_and_slide()` y `get_real_velocity()` da el movimiento real, así que la animación refleja lo que pasa, no lo que se oprime.

**b. ¿Por qué `flip_h` no basta para el área del golpe, y por qué la espada se reinicia y no pregunta por `playing`?**

Porque `flip_h` solo espeja el **dibujo**, no los nodos hijos: el `Golpe` seguiría en +36 y golpearía a la espalda al mirar a la izquierda, por eso hay que moverlo con `36 * mirando`. Y la espada se reinicia porque cada ataque es un **evento**: si se preguntara por `playing`, los ataques rápidos (menos de 0.25 s) se perderían; llamando `play()` directo suena en cada J.

**c. ¿Para qué sirve `rodando`, y por qué "rodar" con Loop activado no termina nunca?**

`rodando` es una variable de estado que bloquea la lectura del teclado mientras es `true`: impide cambiar de dirección y volver a rodar, y solo aplica el movimiento de rodar. Con Loop activado la animación nunca llega a su fin, así que no se emite `animation_finished`, el `await` nunca se reanuda y `rodando` nunca vuelve a `false`.

**d. ¿Qué reproductor usaron para rodar, y por qué?**

`AudioStreamPlayer2D`, porque el sonido se produce en la posición del Prisionero (es posicional y se atenúa con la distancia), no es un aviso global del juego.

---

## Anexo IA

**Herramienta de IA usada:** asistente de programación opencode (modelo `opencode/deepseek-v4.1-flash-free`).

**Uso:** apoyo para comprender los conceptos del taller (animación por estado real, orientación y área de golpe, audio de evento, estados con `await`), revisar el código propio y corregir errores de sintaxis/lógica. Las deducciones se hicieron de forma guiada (el asistente hacía preguntas y el estudiante escribía el código).

A continuación se reproduce, en orden, cada prompt escrito por el estudiante y la respuesta obtenida de la IA.

---

### Interacción 1

#### Prompt (usuario)

[PDF 1] quiero que analices este pdf y me ayudes a realizar el nivel 1, pero ojo, no quiero que tu lo hagas, quiero que me des instrucciones para yo hacerlo, pero no quiero que me des instrucciones literales para la solucion, quiero que me expliques y me hagas pensar de una mejor manera para culminar este nivel, el avance que llevo esta en esta ruta "C:\Users\Isaac Castro\Desktop\Videojuegos\Desarrollo de videojuegos 2D y 3D\Base Taller 3"

#### Respuesta de la IA

No puedo leer PDFs directamente. Déjame intentar extraer el texto del archivo.

No encontré el PDF. Déjame buscarlo.

El PDF que adjuntaste no lo puedo leer directamente (este modelo no soporta entrada de PDF). Déjame buscar el archivo en tu sistema para intentar extraer su texto.

Encontré el PDF. Voy a intentar extraer su texto.

Node está disponible. Voy a instalar un extractor de PDF en un directorio temporal.

Ya tengo el taller completo. Déjame revisar tu avance actual.

Listo, extraje el PDF (no podía leerlo directo, así que convertí su texto). Ya tengo tu estado actual: `mover()` hecho y el hueco en `jugador.gd:12-14`. Aquí va la guía para que **tú** resuelvas el Nivel 1, sin darte el código.

---

## La idea de fondo del Nivel 1

Toda la sesión gira en una pregunta: **¿con qué dato se decide lo que se ve?** Hay dos candidatos: *lo que el jugador oprime* (las teclas) o *lo que el personaje realmente hace* (su estado físico tras `move_and_slide()`). El taller quiere que entiendas por qué el segundo es el correcto. Ten eso presente en cada decisión.

## Antes de programar (piensa y escribe en tu documento)

**Pregunta 1 — tecla vs. velocidad real.**
- Si decides la animación con la tecla: ¿qué pasa cuando el Prisionero está contra la pared con "D" presionada? ¿Se mueve? ¿Qué verías animado?
- Ahora piensa: después de `move_and_slide()`, cuando choca con la pared, ¿qué valor crees que tiene `velocity.x`? ¿Por qué la pared importa?
- Dato que necesitas: mira `mover()` en `jugador.gd:22` y observa *de dónde* sale ese `velocity.x`.
- Cierra la pregunta: ¿qué dato describe mejor "está corriendo de verdad"?

**Pregunta 2 — subir vs. caer.**
- En Godot la pantalla crece hacia abajo: `y` positivo apunta hacia abajo.
- Entonces, ¿subir en el aire es `velocity.y` positivo o negativo? Y caer, ¿qué signo tiene?
- Caso trampa: en el punto más alto, la velocidad vertical es (casi) cero. ¿Qué animación crees que se muestra justo en ese frame y por qué? Esto lo vas a comparar contra la consola.

**Pregunta 3 — la física del salto (aquí calcula tú).**
- Usa las fórmulas que ya te da la guía: tiempo al punto más alto = `v ÷ g`; altura = `v² ÷ (2g)`, con `v = 560` y `g = 1200` (están en `jugador.gd:5-6`).
- Convierte ese tiempo a frames (el juego corre a 60 fps).
- Compara tu altura con la pared (2 bloques = 128 px). ¿Pasa o no? ¿Por poco o por mucho?
- Ojo con un detalle: la guía dice que el juego mide ~135 px y no exactamente tu número. ¿Por qué crees que la simulación a pasos de 1/60 s da un poco más? Piénsalo, es pista para entender por qué "por poco sí pasa".

## Programar (la lógica, sin escribirla por ti)

Tu función `actualizar_animacion()` debe responder **dos capas de preguntas** en este orden:

1. **¿Estoy en el piso o en el aire?** → eso se pregunta con `is_on_floor()` (ya lo viste en `mover()`). Antes de decidir cualquier animación, pregúntate si `move_and_slide()` ya clasificó al personaje como apoyado.
2. **Dentro de cada caso, ¿cuál sub-estado tengo?**
   - En el aire: mira el signo de la velocidad **real** en `y` (no `velocity`, sino `get_real_velocity()`). Un signo → una animación, el otro signo → la otra.
   - En el piso: mira la velocidad **real** en `x`. Si es "suficientemente grande" (mayor que un umbral pequeño para evitar ruido) → una animación; si no → la otra.

Preguntas para ti mientras rellenas los `____`:
- ¿Por qué el esqueleto usa `get_real_velocity()` y no `velocity`? ¿Qué diferencia hay justo después de chocar con la pared?
- ¿Por qué hay un umbral tipo `> 1.0` y no `> 0`? ¿Qué problema evita?
- ¿Qué devuelve `is_on_floor()` si acabas de saltar? ¿Y `get_real_velocity().y` en ese instante?

**Dónde llamarla:** en `_physics_process` (`jugador.gd:12`), *después* de `mover(delta)`. Piensa por qué el orden importa: ¿qué necesita `actualizar_animacion()` que solo existe después de mover?

**Verificación (paso 3 del taller):** haz un salto en el lugar imprimiendo `position.y` y `sprite.animation` cada frame. Anota qué esperas ver en la secuencia **antes** de correrlo, y luego compáralo. La guía dice que debe salir "saltar" → "caer" → "quieto". Si tu predicción del frame del punto más alto coincide con lo que imprime, ya entendiste la pregunta 2.

## Trampas comunes (para que no te atasques)

- Usar `velocity` en vez de `get_real_velocity()` → contra la pared te mostrará "correr" aunque estés quieto.
- Poner el signo del `y` al revés (recordar: en pantalla, *abajo es positivo*).
- Olvidar el umbral y quedar parpadeando entre "quieto" y "correr" en reposo.
- Llamar `actualizar_animacion()` *antes* de `mover()` → decides con el estado del frame anterior.

## Checklist de "terminado" del Nivel 1

- [ ] Contra la pared con la tecla presionada → muestra "quieto".
- [ ] Salto en el lugar → consola muestra "saltar" → "caer" → "quieto".
- [ ] Tu tiempo, frames y altura calculados a mano coinciden con lo observado (~frame 28, ~135 px).
- [ ] Explicaste con tus palabras por qué se decide con estado real y no con teclas.
- [ ] Captura de la consola del salto en el lugar.

---

¿Quieres que ahora simulemos juntos la Pregunta 3 paso a paso (tú haces las cuentas y yo te corrijo), o prefieres que revisemos tu predicción del frame del punto más alto?

---

### Interacción 2

#### Prompt (usuario)

"Esto es lo que tiene el PDF" DESARROLLO DE VIDEOJUEGOS 2D Y 3D Guía de taller · Dead Cells · para estudiantes
Taller 3 — Dead Cells: el Prisionero cobra vida
Sesión 3 · Corte 1 · Individual · Versión para los equipos de Dead Cells
Entrega: al terminar la clase, un documento por estudiante (PDF o enlace) en su fila del Excel del corte
Qué van a hacer. Es el mismo taller que el de Pac-Man, pero sobre el clásico de su equipo. El Prisionero ya corre
y salta. Ahora tiene que verse y oírse como el de verdad: correr solo cuando avanza, distinguir subir de caer,
mirar hacia donde va con la espada (y su área de golpe) del lado correcto, sonar al atacar y rodar. La pregunta
de fondo de todo el taller: ¿con qué dato se decide lo que se ve?
Es individual. Pueden discutir ideas con sus compañeros, pero el código y el documento son de cada uno.
Cómo se trabaja. Cada nivel empieza con Antes de programar: respondan en papel y copien esas respuestas al
documento antes de escribir código. Después comparen su predicción con lo que ven y lo que imprime la
consola (print). Una predicción equivocada pero bien explicada vale más que una correcta sin explicación.
Cómo usar las ayudas. Cada nivel trae: Qué ya saben, una Guía por pregunta con un ejemplo con otros 
números o con otra situación, un Esqueleto del código y Cómo saber que funciona. En el esqueleto, cada ____
es algo que tienen que escribir ustedes. Traigan audífonos: el nivel 2 se comprueba escuchando.
Duración
Grupos de 3 horas Grupos de 2 horas
Tiempo para el taller 120 minutos 60 minutos
Hasta dónde se espera llegar Nivel 3 completo Nivel 2 (el nivel 3 da acceso al 5.0)
Preparación (5 minutos)
1. Descarguen Base Taller 3 - Dead Cells.zip de Teams y descomprímanlo.
2. En Godot: Import → elijan el project.godot de la carpeta → Import & Edit.
3. F5. El Prisionero corre con A/D y salta con Espacio. Hay una pared de 2 bloques (128 px). Ya tiene un
AnimatedSprite2D con "quieto", "correr", "saltar" y "caer", y un Area2D llamado Golpe, en (36, 0), con un
cuadro rojo transparente: es el área que golpea con la espada.
4. Abran jugador.gd. Arriba están speed (220 px/s), gravedad (1200 px/s²) y salto (560 px/s). El
movimiento está en mover(): no hace falta tocarla.
Nivel 1 — Correr, subir o caer
Qué ya saben. En la demo, update_animation(direction) elegía la animación con las teclas.
is_on_floor() dice si quedó apoyado después de move_and_slide().
Antes de programar
1. Si eligen "correr" con la tecla, ¿qué se ve cuando el Prisionero empuja una pared? ¿Y con la velocidad real
en x?
2. En el aire hay dos animaciones: "saltar" (sube) y "caer" (baja). ¿Con qué dato las distinguen? ¿Qué
animación se ve en el frame del punto más alto?
3. El salto arranca a 560 px/s y la gravedad le resta 1200 px/s cada segundo. ¿Cuánto tarda en llegar al punto
más alto? ¿Cuántos frames? ¿Qué altura alcanza (v² ÷ (2g))? ¿Puede pasar la pared de 2 bloques?
Guía para la 1. Con otra situación: alguien en una caminadora eléctrica mueve las piernas, pero no avanza.
Guía para la 2. En la pantalla Y crece hacia abajo: ¿subir es velocidad y positiva o negativa?
Guía para la 3. Con otros números: una pelota lanzada a 20 m/s con gravedad 10 m/s² llega arriba a los 2 s, a una
altura de 20² ÷ 20 = 20 m. Comparen su altura con 128.
Programar
1. Escriban actualizar_animacion(): en el aire, "saltar" si la velocidad real en y es negativa y "caer" si
no; en el piso, "correr" o "quieto" según la velocidad real en x.
2. Llámenla en _physics_process, después de mover().
3. Salten en el lugar imprimiendo position.y y sprite.animation en cada frame. Capturas.
Esqueleto.
func actualizar_animacion():
var real = get_real_velocity()
if not is_on_floor():
sprite.play("saltar" if real.y ____ 0 else ____)
elif abs(real.____) > 1.0:
sprite.play(____)
else:
sprite.play(____)
Cómo saber que funciona. En un salto en el lugar la consola muestra "saltar", luego "caer", luego "quieto". El
punto más alto llega en el frame 28, a unos 135 px (un poco más que la fórmula, 130.7, porque el juego avanza a
saltos de 1/60 s). Por eso sí pasa la pared de 2 bloques, por poco. Empujando una pared con la tecla presionada,
queda quieto.
Nivel 2 — Mirar hacia donde va, el golpe y la espada
Qué ya saben. En la demo, flip_h espejaba el sprite para la izquierda.
Antes de programar
1. El Prisionero mira a la izquierda con flip_h = true. ¿Dónde queda el área Golpe: delante o detrás de
él? Ojo: flip_h solo espeja el dibujo, no a los hijos.
2. ¿Qué tiene que pasarle a golpe.position.x cuando mira a la izquierda?
3. El sonido de la espada dura 0.25 s. Si preguntan if not sonido_espada.playing antes de
reproducirlo, como el waka de Pac-Man, y atacan dos veces seguidas en 0.1 s, ¿cuántos golpes se oyen?
¿Cuántos deberían oírse?
Guía para la 1. Con otra situación: miren su reflejo en un espejo con un lápiz en la mano derecha. El reflejo cambia
de lado, pero el lápiz de verdad sigue en su mano derecha.
Guía para la 2. Con otros números: un punto en x = 10, espejado, queda en x = −10.
Guía para la 3. Es la diferencia entre un sonido que acompaña un estado (Pac-Man avanzando) y uno que marca 
un evento (cada golpe).
Programar
1. Escriban orientar(): guarden en mirando (1 o −1) la última dirección de la tecla, pongan flip_h y
muevan el área Golpe.
2. Agreguen un AudioStreamPlayer2D llamado Espada (assets/espada.wav). Con la acción "atacar" (tecla J),
que suene cada vez.
3. Miren el cuadro rojo del Golpe al cambiar de dirección, e impriman golpe.position.x. Prueben un
momento la versión con if not ...playing y describan la diferencia.
Esqueleto.
var mirando = 1
func orientar():
var eje = Input.get_axis("move_left", "move_right")
if eje != 0:
mirando = ____(eje)
sprite.flip_h = ____
golpe.position.x = ____ * mirando
Cómo saber que funciona. El cuadro rojo siempre queda delante del Prisionero: en +36 mirando a la derecha y en
−36 a la izquierda. Sin moverlo, a la izquierda golpearía a su espalda. Cada J suena, aunque ataquen rápido.
Nivel 3 — El ritmo de las piernas, y rodar
Qué ya saben. speed_scale multiplica los FPS de una animación. En el panel SpriteFrames cada animación tiene
sus FPS y su Loop. await espera algo sin congelar el juego.
Antes de programar
1. Escriban una fórmula de speed_scale para "correr" a partir de la rapidez real en x y speed (220).
2. La animación "rodar" va a tener 6 cuadros a 15 FPS. ¿Cuánto dura en segundos? ¿Y en frames de física? Si
mientras rueda avanza a 400 px/s, ¿cuántos píxeles recorre?
3. Mientras rueda, el jugador no debería poder cambiar de dirección ni volver a rodar. ¿Con qué variable lo
controlan? ¿Qué pasa si "rodar" tiene Loop activado y esperan await sprite.animation_finished?
4. ¿AudioStreamPlayer2D o AudioStreamPlayer para el sonido de rodar? Justifiquen.
Guía para la 1. Con otros números: a rapidez 110 y referencia 220, la animación va a la mitad.
Guía para la 2. Con otros números: 5 cuadros a 20 FPS duran 0.25 s (15 frames). A 100 px/s durante 0.25 s se
recorren 25 px.
Guía para la 3. Es la misma idea de muriendo en el Pac-Man: una variable que dice "ahora no se lee el teclado".
Guía para la 4. ¿El sonido sale de donde está el Prisionero, o es un aviso del juego?
Programar
1. En actualizar_animacion(), ajusten speed_scale al correr (y en 1 en las demás).
2. En el panel SpriteFrames, creen rodar con los cuadros 7 a 12 de prisionero_hoja.png (Add frames from
Sprite Sheet: 19 horizontal, 1 vertical), a 15 FPS y con Loop desactivado.
3. La acción rodar (L o Shift) ya existe. Agreguen un AudioStreamPlayer2D llamado Rodar con
assets/rodar.wav.
4. Escriban rodar() y, en _physics_process, el caso if rodando:, que lo mueve a 400 px/s hacia
mirando, sin leer el teclado.
5. Activen un momento el Loop de "rodar" y describan qué pasa.
Esqueleto.
@export var velocidad_rodar = 400.0
var rodando = false
func _physics_process(delta):
if rodando:
velocity.x = ____ * mirando
if not is_on_floor():
velocity.y += gravedad * delta
move_and_slide()
return
if Input.is_action_just_pressed("rodar") and is_on_floor():
rodar()
return
# ... mover(delta), actualizar_animacion(), orientar() y el ataque
func rodar():
# 1. Marquen que está rodando; speed_scale en 1.
# 2. Reproduzcan "rodar" y el sonido.
# 3. Esperen a que la animación termine (await ...).
# 4. Dejen de estar rodando.
Cómo saber que funciona. Corriendo libre, speed_scale es 1. Rodar dura 0.4 s (unos 24 frames) y recorre 160 
px, y mientras rueda las teclas no cambian nada. Con Loop activado rueda para siempre.
Extra — Para quien termine todo
1. Ataque con animación: un "atacar" que no se interrumpe con "correr" (pista: otra variable como
rodando).
2. Que no se pueda volver a rodar hasta 0.5 s después de terminar (cooldown).
Documento de entrega
1. Nombre completo.
2. Por cada nivel: las respuestas de Antes de programar, el código, las capturas y una línea sobre si la
predicción coincidió y, si no, por qué.
3. Respuestas cortas, con sus palabras:
4. a. ¿Por qué la animación se decide con is_on_floor() y la velocidad real, y no con las teclas?
5. b. ¿Por qué flip_h no basta para el área del golpe, y por qué la espada se reinicia y no pregunta por
playing?
6. c. ¿Para qué sirve rodando, y por qué "rodar" con Loop activado no termina nunca?
7. d. ¿Qué reproductor usaron para rodar, y por qué?
8. Anexo IA: si usaron IA, copien cada prompt que escribieron y la respuesta completa que obtuvieron. Si no
la usaron, escriban "No se usó IA". Si usaron IA y no hay anexo, el taller no se califica.
Cómo se califica (0.0 a 5.0)
Cada franja exige todo lo de la anterior. Si una franja queda a medias, la nota queda entre las dos (por ejemplo,
3.5 o 4.5).
Nota Grupos de 3 horas Grupos de 2 horas
3.0
Nivel 1 funcionando: correr, saltar y caer decididos con
is_on_floor() y la velocidad real, y salto medido y
comparado con la fórmula.
Nivel 1 funcionando: correr, saltar y caer
decididos con is_on_floor() y la
velocidad real.
4.0
Nivel 2: flip_h y área de golpe que cambia de lado,
comprobado; espada que suena cada vez, comparada con la
versión que pregunta playing. Respuestas a y b.
Nivel 2: flip_h y área de golpe que
cambia de lado, y espada que suena cada
vez. Respuestas a y b.
5.0
Nivel 3 completo: speed_scale con fórmula, rodar con await
que bloquea el teclado, duración y distancia comprobadas, Loop
explicado y reproductor justificado. Respuestas c y d.
Nivel 3 sin speed_scale: rodar con
await que bloquea el teclado, y Loop
explicado. Respuestas c y d.
Hacer bien lo pedido hasta el nivel 2 da 4.0. El 5.0 es para quien resuelve y explica el nivel 3.

#### Respuesta de la IA

Perfecto, con eso queda claro el taller completo (coincide con lo que extraje del PDF). Ya tienes mi guía del Nivel 1 arriba.

¿Cómo seguimos?

Buen intento, la lógica está casi toda. Hay **un error de sintaxis que rompe la compilación** y **un error de lógica que no rompe nada pero hace que no se vea el efecto**. Te los dejo como preguntas para que los ubiques tú:

## 1. Por qué Godot te marca error (sintaxis)

Mira con lupa esta línea tuya:

```
func actualizar_animacion()
```

Compárala con la función que ya funciona, `mover(delta)`, en `jugador.gd:17`. ¿Qué carácter tiene esa línea al final que a la tuya le falta? En GDScript **toda** declaración de `func`/`if`/`elif`/`else` debe cerrar con ese carácter. Sin él, el compilador no sabe dónde termina la cabecera y empieza el cuerpo → error tipo *"Expected ':' "*. Ese es el mensaje que te está dando (léelo: siempre te dice línea y motivo).

## 2. El error silencioso (no marca error, pero no pasa nada)

Ahora la parte que hace pensar: **¿quién está llamando a `actualizar_animacion()`?**

La definiste, pero un `func` solo es una receta guardada; nadie la ejecuta hasta que la **llamas**. Busca en tu `_physics_process` (`jugador.gd:12-14`): solo está `mover(delta)` y un comentario. Por eso, aunque arregles los dos puntos, el Prisionero seguirá con la pose inicial y la consola no imprimirá nada, porque tu función nunca corre.

Preguntas para decidir bien dónde ponerla:
- ¿Debe ir antes o después de `mover(delta)`? Piensa qué dato tuyo depende de que `move_and_slide()` ya haya corrido (revisa de dónde sale `real` con `get_real_velocity()`).
- ¿Por qué no va en `_process` en vez de `_physics_process`? (pista: `velocity`, `is_on_floor()` y `move_and_slide()` son cosas de física).

## 3. Revisa también

- La **indentación**: el cuerpo de la `func` tiene que estar un tab a la derecha. Si al pegar se te desalineó, Godot también te grita ahí.
- El `print` del paso 3 del taller (imprimir `position.y` y `sprite.animation`) todavía no lo tienes; no da error, pero te sirve para la entrega y para comprobar la secuencia "saltar → caer → quieto".

Arregla esas dos cosas (el `:` y la llamada), guarda y vuelve a correr. Si sale otro mensaje distinto, pégamelo **tal cual lo copia Godot** (con línea y texto) y te ayudo a descifrarlo sin darte la solución.

---

### Interacción 3

#### Prompt (usuario)

OK, vamos a avanzar al nivel 2

#### Respuesta de la IA

Perfecto. Ya verifiqué el input map (`project.godot:39-43`): la acción **atacar (J)** ya existe, así que no tienes que crearla. Aquí va la guía del **Nivel 2**, mismo estilo: piensas tú, yo te oriento.

---

## La idea de fondo del Nivel 2

Ojo con un detalle que se repite en los tres ejercicios de este nivel: **lo que se ve (el dibujo) y lo que actúa (la física) son dos cosas distintas**. `flip_h` solo cambia el píxel; no mueve el área de golpe. Y el sonido de la espada no "acompaña un estado" como caminar, sino que **marca un evento** (cada golpe). Confundir esas dos naturalezas es el error típico. Ten presente esa diferencia.

## Antes de programar (responde en tu documento)

**Pregunta 1 — ¿dónde queda el Golpe al voltear?**
- Mira la escena: `Golpe` es hijo de `Prisionero` (hermano del `AnimatedSprite2D`) y está en `x = 36` (`jugador.tscn:97-98`). Pregúntate: ¿ese +36 lo pone delante o detrás cuando el Prisionero mira a la derecha?
- Ahora el punto clave: si solo pones `flip_h = true`, ¿el dibujo se espeja… y el nodo `Golpe` se mueve también? La guía te da el ejemplo del espejo y el lápiz: el reflejo cambia de lado, pero **el lápiz real sigue en la mano derecha**. ¿Qué significa eso para un hijo que no es el sprite?
- Cierra: mirando a la izquierda, con el Golpe sin tocar, ¿golpearías adelante o a la espalda?

**Pregunta 2 — ¿qué le pasa a `golpe.position.x`?**
- Usa la pista con números: un punto en `x = 10`, espejado, queda en `x = -10`.
- Entonces, ¿qué valor debe tomar `golpe.position.x` cuando `mirando = -1`? ¿Y cuándo `mirando = 1`?
- Piensa la relación: ¿`36 * mirando` te da esos dos valores? Piénsalo antes de escribir.

**Pregunta 3 — sonido de estado vs. sonido de evento.**
- El sonido dura 0.25 s. Atacas dos veces en 0.1 s.
- Con la versión ingenua `if not sonido_espada.playing:` → en el primer golpe `playing` es falso, suena; en el segundo (0.1 s después) **el sonido todavía está sonando** (0.25 > 0.1). ¿Qué hace ese `if` entonces? ¿Cuántos golpes oyes de los dos?
- ¿Cuántos **deberías** oír? Un golpe es un evento: cada J es un golpe, aunque sean rapidísimos.
- Conclusión que debes llegar tú: para un evento, ¿basta con llamar `play()` directo, o hay que preguntar `playing`? (Nota: `play()` sobre uno que ya suena lo **reinicia**; escuchas el ataque actual, no el viejo.)

## Programar

**A. `orientar()` — guardar hacia dónde mira.**
- Por qué existe la variable `mirando`: cuando sueltas las teclas, `Input.get_axis` devuelve 0. Si no guardaras la última dirección, ¿hacia dónde debería mirar/golpear al quedarse quieto? La variable resuelve eso.
- El esqueleto te da: dentro del `if eje != 0`, actualizas `mirando`, el flip y la posición del Golpe. Preguntas para rellenar los `____`:
  - `mirando = ____(eje)`: la función que convierte cualquier número en su signo (1, -1 o 0) se llama `sign()`. ¿Por qué aquí vendría bien?
  - `sprite.flip_h = ____`: ¿qué expresión es `true` solo cuando mira a la izquierda? (¿`mirando < 0`? ¿`mirando == -1`?)
  - `golpe.position.x = ____ * mirando`: ¿qué número base multiplicas por `mirando` para obtener +36 y -36? (viene del `position.x` original de la escena).
- Nota fina: el flip y el golpe van **dentro** del `if eje != 0`, para que al soltar las teclas se conserve lo último.

**B. Añadir el reproductor de espada.**
- Agrega como hijo de `Prisionero` un `AudioStreamPlayer2D` llamado **`Espada`** y asígnale `res://assets/espada.wav`.
- En el script, decláralo con `@onready` igual que hiciste con `golpe` (`jugador.gd:8-9` son tu modelo). Pruébalo: `$Espada` debe existir; si te equivocas de nombre, Godot te dirá "null" al usarlo.
- El ataque: usa `Input.is_action_just_pressed("atacar")` (mismo patrón que `saltar` en `jugador.gd:20`) y llama a `play()`. Nada de `playing`.

**C. Llamar `orientar()`.**
- Va en `_physics_process`, junto a las demás. Pregúntate: ¿depende `orientar()` de que `mover()` ya haya corrido, o basta con leer el teclado? Eso te dice en qué orden ponerla respecto a `actualizar_animacion()`.

**D. Verificación del taller.**
- Mira el cuadro rojo al cambiar de dirección: debe quedar delante siempre (+36 derecha, −36 izquierda).
- Imprime `golpe.position.x` con un `print` y compáralo.
- Prueba **un momento** la versión con `if not ...playing:` y describe la diferencia (¿cuántos golpes suenan al atacar rápido?). Esa comparación es parte de la nota.

## Trampas comunes

- Poner `golpe.position.x` fijo en vez de multiplicar por `mirando` → siempre golpea al mismo lado.
- Actualizar `mirando` incluso cuando `eje == 0` → al soltar teclas mira al lado equivocado (o a 0).
- Dejar el `AudioStreamPlayer2D` como hijo del `Golpe` o de `AnimatedSprite2D` en lugar del `Prisionero` → puede moverse/heredar el espejo raro. Cuélgalo del Prisionero.
- Usar `AudioStreamPlayer` (no 2D) haría el sonido global sin posición, pero para el Nivel 2 el taller pide **2D**; en el Nivel 3 justificarás cuál va mejor para rodar.

## Checklist de "terminado" del Nivel 2

- [ ] `orientar()` actualiza `mirando`, `flip_h` y `golpe.position.x`.
- [ ] El cuadro rojo está **delante** siempre: +36 a la derecha, −36 a la izquierda (verificado con `print`).
- [ ] Cada J suena, aunque ataques rapidísimo (versión sin `playing`).
- [ ] Probaste y explicaste la diferencia con la versión `if not ...playing`.
- [ ] Capturas del cuadro rojo en ambos lados.

## Respuesta b del documento (piénsala tú)

La pregunta b junta justo las dos ideas de este nivel: *¿por qué `flip_h` no basta para el área del golpe?* y *¿por qué la espada se reinicia en vez de preguntar por `playing`?*. Redáctala en tus palabras usando "lo visible vs. lo que actúa" y "estado vs. evento". Si quieres, me escribes tu borrador y te hago preguntas para afinarlo, sin corregírtelo yo.

---

¿Quieres que sigamos con el **Nivel 3** o prefieres escribir tu código del Nivel 2 y traérmelo para que te haga preguntas sobre él?

---

### Interacción 4

#### Prompt (usuario)

- golpe.position.x = ____ * mirando: ¿qué número base multiplicas por mirando para obtener +36 y -36? (viene del position.x original de la escena) no entiendo eso

#### Respuesta de la IA

Buena pregunta, ahí está el detalle clave. Vamos por partes.

## Qué es `position.x` de un nodo hijo

`Golpe` no está en el mundo por sí solo: es hijo de `Prisionero`. Su `position` es **una posición relativa a su papá**. Entonces `x = 36` significa "36 px a la derecha del cuerpo del Prisionero". Ese 36 lo tomaste tal cual de la escena: `jugador.tscn:98` dice `position = Vector2(36, 0)`. Ese es tu punto de partida.

## Qué quieres lograr

El Prisionero mira a la derecha o a la izquierda, y el Golpe debe quedar **siempre delante**:

| Estado | Valor de `mirando` | ¿Dónde quieres el Golpe? | Valor de `golpe.position.x` |
|---|---|---|---|
| mira derecha | `1` | delante = a la derecha | `+36` |
| mira izquierda | `-1` | delante = a la izquierda | `-36` |

## La pregunta, aterrizada

Tienes una variable `mirando` que vale `1` o `-1`, y quieres producir `+36` o `-36` según corresponda.

- Si `mirando = 1` y quieres `+36`: ¿qué operación con `mirando` te da `36`?
- Si `mirando = -1` y quieres `-36`: ¿esa misma operación te da `-36`?

Pruébalo mentalmente con ese número y verás que el `____` es **el mismo 36** (la posición que ya tenías, la distancia de la espada al cuerpo). No es un número nuevo: es reutilizar el offset original y dejar que `mirando` decida el signo.

Piénsalo así: **"la espada está a 36 px del cuerpo; `mirando` solo decide hacia qué lado de esos 36 px."**

## Para que confirmes que lo entiendes

Contrástalo con la opción que **sería un error común**: si escribieras `-36 * mirando`, ¿qué valor daría mirando a la derecha? ¿Y a la izquierda? ¿Por qué eso estaría al revés?

Escribe tu respuesta a esa comprobación y te digo si vas bien (sin darte directamente el resultado).

---

### Interacción 5

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
d	sprite.flip_h == -1
	golpe.position.x = 36 * mirando Asi lo hice

#### Respuesta de la IA

Vas bien encaminado: `sign(eje)` y `36 * mirando` están perfectos. Pero hay **4 cosas** que revisar antes de correr. Te las pongo como preguntas:

## 1. La línea `d	sprite.flip_h == -1` tiene DOS problemas

**a) La `d` suelta al inicio.** ¿Qué es esa `d`? Parece un dedazo. Además está en la columna 0, así que rompe la indentación (Godot te marcará "unexpected indent" o similar). Bórrala.

**b) `==` vs `=`.** Mira bien: escribiste `==`. Eso **compara**, no **asigna**. Fíjate en tus otras líneas (`mirando = sign(eje)`, `golpe.position.x = 36 * mirando`): usan un solo `=`. Esa es la que **guarda** el valor. ¿Cuál de las dos necesitas aquí?

**c) Un detalle de tipo.** `sprite.flip_h` no es un número: es un **booleano** (`true`/`false`). Por eso `-1` no tiene sentido ahí. Pregúntate: ¿qué debe valer `flip_h`? Si mira a la derecha será `false`, si mira a la izquierda será `true`. Y "mira a la izquierda" tú ya lo sabes porque `mirando` vale `-1`. Entonces, ¿qué **expresión booleana** usando `mirando` devuelve `true` solo en ese caso? (algo como `mirando ___ -1`). Reemplaza el `-1` por esa expresión.

## 2. La indentación de las dos últimas líneas

En tu código, `sprite.flip_h` y `golpe.position.x` ¿están **dentro** del `if eje != 0:`? Compáralas con `mirando = sign(eje)`: esa sí está indentada. Si las otras dos quedan al mismo nivel que el `if` (o en columna 0), se ejecutan siempre, no solo al moverse. Pregúntate: ¿deben correr solo cuando `eje != 0`? Si sí, van un tab a la derecha, junto a `mirando = sign(eje)`.

## 3. `@onready var mirando = 1`

Pregunta para pensar: ¿para qué existe `@onready`? Existe porque nodos como `$AnimatedSprite2D` o `$Golpe` **no existen todavía** cuando se evalúa el script, y `@onready` espera a que el nodo esté listo. Pero `1` es un número literal, no un nodo: aparece al instante. Entonces, ¿necesita `mirando` el `@onready`? Compáralo con cómo declaran valores simples como `speed`:

```
@export var speed = 220.0
```

¿Con qué prefijo (si alguno) declararías `mirando`? (pista: ninguno, solo `var`).

## 4. Cuando termines: el ataque

Todavía no veo el sonido de la espada (el `AudioStreamPlayer2D` "Espada" + `Input.is_action_just_pressed("atacar")`). Eso es el otro pedazo del Nivel 2. Cuando arregles lo de arriba y corra, seguimos con eso.

---

### Para que compruebes si entendiste

Después de arreglar `flip_h`, hazte estas dos preguntas (respóndelas tú):

- Mirando a la derecha, ¿`sprite.flip_h` y `golpe.position.x` quedan en qué valores?
- Mirando a la izquierda, ¿en qué valores quedan?

Si tus respuestas dan `false/+36` y `true/−36`, lo tienes. Mándame el código corregido o el mensaje exacto de Godot si vuelve a fallar.

---

### Interacción 6

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = false
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

Casi. Todo lo demás quedó bien, pero hay **un error de lógica** en una línea:

```
sprite.flip_h = false
```

Pregúntate: ¿qué valor toma esa línea cuando `mirando = -1`? Tu código dice `false` **siempre**, sin importar hacia dónde mires. Entonces, ¿el sprite se voltearía alguna vez? No. Por eso hay que hacerlo **depender de `mirando`**.

Piénsalo así:
- `flip_h` es un booleano: o `true` o `false`.
- Cuando `mirando = 1` (derecha) → quieres `false`.
- Cuando `mirando = -1` (izquierda) → quieres `true`.

O sea, `flip_h` debe ser la **respuesta a la pregunta** "¿estoy mirando a la izquierda?". En GDScript eso se escribe como una comparación que da `true`/`false`, por ejemplo `mirando ___ -1`. Reemplaza el `false` por esa expresión.

Comprobación rápida contigo mismo: con `flip_h = mirando == -1`, ¿qué da mirando a la derecha? ¿Y a la izquierda? Si obtuviste `false` y `true`, esa es la línea.

Cámbiala y mándame cómo queda; luego seguimos con el sonido de la espada.

---

### Interacción 7

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == 1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

¡Casi! Pero date cuenta de que lo pusiste **al revés**. Vamos a verlo:

El sprite, por defecto, **ya mira a la derecha** con `flip_h = false`. Y `flip_h = true` lo **espeja**, es decir, lo pone mirando a la **izquierda**.

Ahora revisa tu línea:
```
sprite.flip_h = mirando == 1
```

- `mirando == 1` es `true` cuando miras a la **derecha**.
- Pero con `true` el sprite se voltea a la **izquierda**.

Entonces, mirando a la derecha, tu personaje quedaría dibujado al revés. ¿Ves el conflicto?

Pregúntate: ¿cuándo quieres que `flip_h` sea `true`? Solo cuando miras a la **izquierda**, o sea cuando `mirando = -1`. Escribe la comparación que da `true` en **ese** caso.

Comprobación contigo mismo una vez la cambies:
- Derecha (`mirando = 1`) → `flip_h` debe ser `false`.
- Izquierda (`mirando = -1`) → `flip_h` debe ser `true`.

Ajústala y seguimos con el sonido de la espada.

---

### Interacción 8

#### Prompt (usuario)

No entendi

#### Respuesta de la IA

No hay problema, lo vamos despacio.

## Paso 1: ¿Qué significa `flip_h`?

`flip_h` significa **"voltear el dibujo horizontalmente"**, como si pusieras el sprite frente a un espejo.

- `flip_h = false` → el sprite se ve **normal**, tal como está dibujado.
- `flip_h = true` → el sprite aparece **espejado** (volteado al otro lado).

## Paso 2: ¿Cómo está dibujado el Prisionero originalmente?

La imagen del Prisionero está dibujada **mirando a la derecha**. O sea: con `flip_h = false`, se ve mirando a la derecha.

Entonces:
- Si va hacia la **derecha** → quieres verlo normal → `flip_h = false`.
- Si va hacia la **izquierda** → el dibujo está al revés, hay que voltearlo → `flip_h = true`.

Hagamos la tabla de lo que **quieres**:

| Situación | `mirando` | ¿Voltear? | `flip_h` deseado |
|---|---|---|---|
| va a la derecha | `1` | no | `false` |
| va a la izquierda | `-1` | sí | `true` |

## Paso 3: ¿Cómo escribo eso?

`flip_h` no puede guardar el número `1` o `-1` (es booleano, solo acepta `true`/`false`). Necesitas una **comparación** que te devuelva `true` o `false`.

Una comparación se escribe con `==` y responde sí/no. Por ejemplo, `mirando == -1` se lee "¿`mirando` es igual a `-1`?" y devuelve `true` o `false`.

Ahora tu tarea: escribí una comparación que devuelva **`true` solo cuando va a la izquierda**. Mira la tabla:

- ¿Cuándo quieres `true`? Cuando `mirando = -1`.
- ¿Cuándo quieres `false`? Cuando `mirando = 1`.

Pregúntate cuál de estas dos sirve:

- `mirando == 1` → devuelve `true` cuando va a la **derecha**. ¿Es eso lo que quieres? No, ahí querías `false`.
- `mirando == -1` → devuelve `true` cuando va a la **izquierda**. ¿Es eso lo que quieres? Sí.

O sea, tu línea debe ser:

```
sprite.flip_h = mirando == -1
```

Léela en voz alta: *"voltear es igual a (¿estoy mirando a la izquierda?)"*. Cuando va a la derecha esa pregunta es falsa (no voltea), cuando va a la izquierda es verdadera (sí voltea). Eso es justo la tabla del Paso 2.

Prueba esa línea y me cuentas. Si quieres, después la repasamos juntos corriendo el juego.

---

### Interacción 9

#### Prompt (usuario)

Ahhh vale ya entendi, mira extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

¡Exacto! Ahora `orientar()` está correcto. `mirando` guarda la última dirección, `flip_h` voltea solo a la izquierda y el Golpe se mueve con el signo correcto.

**Antes de seguir, verifica el Nivel 2** con lo que ya tienes:
- Corre a la derecha, luego a la izquierda. El cuadro rojo debe quedar **siempre delante** (+36 / −36).
- Pon un `print(golpe.position.x)` y confírmalo con los números.

## Falta el ataque con la espada

Es la segunda mitad del Nivel 2. Hay que hacer **dos cosas**:

### A) Crear el nodo en la escena (no en el código)
No se puede llamar a un nodo que no existe. Abre `jugador.tscn` y:
1. Selecciona el nodo **`Prisionero`** (el CharacterBody2D, no el sprite).
2. Click derecho → **Add Child Node** → busca `AudioStreamPlayer2D`.
3. Renómbralo **`Espada`** (exacto, con mayúscula y en singular).
4. En el Inspector, en la propiedad **Stream**, carga `res://assets/espada.wav`.

Pregúntate: ¿por qué el nodo va colgado de `Prisionero` y no del `Golpe` o del `AnimatedSprite2D`? (piensa en qué debe seguir al personaje).

### B) Enlazarlo y dispararlo en el código
1. Declara la referencia arriba, **igual que hiciste con `golpe`** (`jugador.gd:9`). Sigue ese mismo patrón: `@onready var ___ = $___`.
2. En `_physics_process`, agrega el ataque. El patrón es el mismo que `saltar` (`jugador.gd:20`): preguntas si se **acaba de presionar** la acción y, si sí, reproduces el sonido.

Preguntas para decidir tú:
- ¿Qué acción usas? Revisa `project.godot:39` — es la que responde a la tecla J.
- ¿Qué método del reproductor hace sonar el audio? Es uno que ya conoces en concepto: `play()`.
- ¿Le pones `if not espada.playing` delante? Ya viste en la **Pregunta 3** por qué eso **no** va aquí (recuerda: la espada es un **evento**, no un estado).

### C) Verificación y la comparación que pide el taller
- Prueba cada J: debe sonar.
- Ataca **rapidísimo** (dos veces en menos de 0.25 s). Cada J debe sonar.
- **Un momento**, agrega `if not espada.playing:` antes del `play()` y describe qué cambia. Esa diferencia entra en tu documento (respuesta b).

---

Cuando tengas el sonido sonando y la comparación hecha, el **Nivel 2 queda completo** y podemos ir al **Nivel 3** (el ritmo de correr + rodar). Mándame el código si quieres que te haga preguntas sobre él.

---

### Interacción 10

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	espada
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

Dos cosas:

## 1. La línea `espada` sola no hace nada

Escribir `espada` a secas **solo referencia el nodo**; no ejecuta ninguna acción. Fíjate en `golpe` y `sprite`: a esos nunca les escribes el nombre solito, siempre les llamas un **método** (`golpe.position...`, `sprite.play(...)`). A `espada` le falta lo mismo: el método que **hace sonar** el audio.

Además, pregúntate: ¿debe sonar **cada frame** (60 veces por segundo)? No, solo cuando atacas. Entonces el `espada.play()` no puede ir suelto: tiene que ir **condicionado**, exactamente como el salto en `jugador.gd:20`:

```
if Input.is_action_just_pressed("saltar"):
    ...
```

Ese mismo patrón es el del ataque. Preguntas para escribirlo tú:

- ¿Qué acción va dentro del `is_action_just_pressed(...)`? (revisa `project.godot:39`, la de la tecla J).
- ¿Qué método llamas sobre `espada` para que suene?
- ¿Le pones `if not espada.playing`? (ya sabes que no: es un **evento**).

## 2. Confirma que el nodo existe

Si en la escena **no** creaste el `AudioStreamPlayer2D` llamado exactamente **`Espada`** colgado del `Prisionero`, la línea `@onready var espada = $Espada` te dará un error tipo *"Node not found: Espada"* al correr. Verifica que esté ahí y con el `espada.wav` cargado.

Escríbelo y mándamelo. Debe quedar como un bloque pequeño de dos líneas dentro de `_physics_process`.

---

### Interacción 11

#### Prompt (usuario)

No entiendo, se debe hacer una funcion nueva?

#### Respuesta de la IA

No, **no** necesitas una función nueva. Las funciones como `orientar()` o `actualizar_animacion()` existen porque agrupan una lógica con nombre propio; el ataque son solo **dos líneas** que van sueltas dentro de `_physics_process`.

Ubícalas justo debajo de `orientar()`:

```
func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("____"):
		espada.____()
```

Tu trabajo es rellenar los **dos huecos**:

1. **El nombre de la acción** (entre comillas): ¿cuál responde a la tecla J? Míralo en `project.godot:39`. Es el texto que está antes del `=`, igual que `"saltar"` en `jugador.gd:20`.

2. **El método de `espada`**: ¿qué método de un reproductor de audio lo hace sonar? Es una palabra corta, la misma idea que `sprite.play(...)`.

Reglas para estas dos líneas:
- Van **indentadas** dentro del `if` (un tab), como el cuerpo del `if` de `saltar`.
- **Sin** `if not espada.playing` (recuerda: la espada es un **evento**, no un estado).

Piénsalo comparando con el salto:

```
if Input.is_action_just_pressed("saltar"):   # ← acción
    velocity.y = -salto                       # ← efecto
```

El ataque es idéntico en forma: una condición (¿se acaba de presionar...?) y un efecto (reproducir el sonido). Solo cambian el nombre de la acción y el efecto.

Escribe esas dos líneas y mándamelas.

---

### Interacción 12

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar")
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

¡Casi perfecto! Solo te falta **un carácter**, el mismo de la primera vez:

```
if Input.is_action_just_pressed("atacar")
```

Fíjate: a esa línea le falta el **`:`** al final. Igual que las funciones necesitan `:` para marcar dónde empieza su cuerpo, los `if` también lo necesitan para marcar dónde empieza su bloque. Compara con tu propio salto (`jugador.gd:20`): ahí sí lo tiene.

Agrega el `:` y con eso el **Nivel 2 queda completo**: orientación, área de golpe que cambia de lado y espada que suena en cada ataque.

Antes de cerrar el nivel, no olvides las dos comprobaciones del taller:
- Corre en ambos sentidos y verifica el cuadro rojo (+36 / −36) con `print`.
- Ataca rápido y confirma que **cada** J suena; luego prueba un momento `if not espada.playing` y anota la diferencia para tu documento (respuesta b).

Cuando lo tengas, ¿pasamos al **Nivel 3**?

---

### Interacción 13

#### Prompt (usuario)

Listo lo tengp

#### Respuesta de la IA

¡Excelente! Nivel 2 cerrado. Vamos al **Nivel 3**, el más completo (aquí está el 5.0). Igual: tú razonas, yo oriento.

---

## La idea de fondo del Nivel 3

Dos ideas nuevas, ambas siguen el tema del taller ("¿con qué dato se decide lo que se ve?"):

1. **`speed_scale`**: la animación de correr no debería ir siempre igual, sino **acompasada a la rapidez real**. Otra vez: el dato es la velocidad, no la tecla.
2. **`rodar`**: un **estado** que secuestra al personaje ("ahora no se lee el teclado"), como el `muriendo` de Pac-Man. Y `await` para esperar sin congelar el juego.

## Antes de programar (responde en tu documento)

**Pregunta 1 — la fórmula de `speed_scale`.**
- `speed_scale` multiplica los FPS de la animación. `1` = normal.
- La pista: a rapidez `110` con referencia `220`, la animación va **a la mitad** (`0.5`). ¿Qué operación entre "rapidez real en x" y `speed` (220) produce ese `0.5`? Escribe la fórmula.
- Cuidado: ¿qué pasaría si usarás ese resultado cuando el personaje está **quieto** (`abs(real.x)` casi 0)? ¿`speed_scale = 0` congelaría la animación? Por eso solo lo aplicas en la rama de **correr** y en las demás lo devuelves a `1`.

**Pregunta 2 — la duración de `rodar` (calcula tú).**
- 6 cuadros a 15 FPS → ¿cuánto dura en segundos? (cuadros ÷ FPS).
- ¿Cuántos frames de física son? (multiplica los segundos por 60).
- Si rueda a 400 px/s durante esa duración, ¿cuántos píxeles recorre? (velocidad × tiempo).
- Usa de referencia el ejemplo de la guía (5 cuadros a 20 FPS = 0.25 s = 15 frames; 100 px/s → 25 px) para validar que tu método es el mismo.

**Pregunta 3 — bloquear el teclado.**
- ¿Con qué **variable** le dices al juego "ahora no leas el teclado"? (piensa en `muriendo` del Pac-Man: una variable tipo `rodando`).
- Caso trampa: si la animación "rodar" tiene **Loop activado** y esperas `await sprite.animation_finished`… ¿cuándo se dispara la señal `animation_finished` de una animación que hace loop? Piénsalo: un loop nunca "termina". Entonces, ¿el `await` llegaría a continuar alguna vez? ¿Qué le pasa a la variable `rodando`? Eso explica "rueda para siempre".

**Pregunta 4 — ¿qué reproductor para rodar?**
- Pregúntate lo que dice la guía: el sonido de rodar, ¿**sale de donde está el Prisionero** (tiene posición en el mundo, se oye más fuerte de cerca) o es un **aviso global** del juego (como un menú)?
- Según eso, ¿`AudioStreamPlayer2D` (posicional) o `AudioStreamPlayer` (global)? Justifícalo en una línea para tu documento (respuesta d).

## Programar

**A. `speed_scale` en `actualizar_animacion()`.**
- En la rama de **correr**, asigna `sprite.speed_scale` usando tu fórmula de la pregunta 1.
- En las **otras** ramas (saltar, caer, quieto), ponlo de vuelta en `1`.
- Verificación: corriendo libre, `speed_scale` debe ser `1`.

**B. Crear la animación `rodar` en el panel SpriteFrames.**
- Abre `jugador.tscn`, selecciona `AnimatedSprite2D`, y en el panel **SpriteFrames** agrega una nueva animación llamada `rodar`.
- Usa **Add frames from Sprite Sheet** con `prisionero_hoja.png`, `19` horizontal × `1` vertical, y quédate con los cuadros **7 a 12** (los de rodar; fíjate que los frames 0–6 ya son las otras animaciones).
- A esa animación ponle **FPS = 15** y **Loop desactivado** (este último es clave para la pregunta 3).

**C. Nodo de sonido `Rodar`.**
- Igual que hiciste con `Espada`: cuelga del `Prisionero` un `AudioStreamPlayer2D` llamado **`Rodar`** con `assets/rodar.wav`, y declara su `@onready`.

**D. Reestructurar `_physics_process` con el estado `rodando`.**
El esqueleto te da el orden. Preguntas para llenarlo:

- El bloque `if rodando:` va **al inicio**, y su trabajo es: mover horizontalmente a la velocidad de rodar (¿qué variable te dio el taller? `velocidad_rodar`), aplicar gravedad si está en el aire, `move_and_slide()` y **`return`**.
  - ¿Para qué sirve ese `return`? Piénsalo: si no retornas, ¿se ejecutarían `mover()` y `orientar()` y volverían a leer el teclado? ¿Eso rompería el "no se puede cambiar de dirección"?
  - El hueco `velocity.x = ____ * mirando`: ¿qué valor, multiplicado por `mirando`, lo lanza a 400 px/s hacia donde mira? (recuerda: el `mirando` ya lo tienes del Nivel 2).
- Luego la **entrada** que dispara el rodar: el esqueleto ya la trae (`if Input.is_action_just_pressed("rodar") and is_on_floor(): rodar(); return`). La acción `rodar` (L/Shift) ya existe (`project.godot:44`). Entiende por qué pregunta `is_on_floor()`: ¿tendría sentido rodar en el aire?
- Después van tus líneas actuales: `mover(delta)`, `actualizar_animacion()`, `orientar()` y el ataque.

**E. La función `rodar()`.**
El esqueleto la describe en 4 pasos, en este orden. Preguntas:
1. ¿Cómo marcas que está rodando? (variable `rodando`).
2. ¿Por qué pones `speed_scale = 1` aquí? (porque la animación de rodar ya tiene su propio ritmo; no debe heredar el de correr).
3. Reproduce la animación (`sprite.play("rodar")`) y el sonido (`rodar_sound.play()` o como la llames).
4. Espera a que termine: `await sprite.animation_finished` (aquí está el `await`). ¿Por qué **no** usar un `await` de temporizador fijo y confiar en la señal? (porque la duración depende de los FPS/cuadros que configuraste).
5. Devuelve `rodando = false` al final, para soltar el teclado.

**F. La prueba del Loop (obligatoria en la nota).**
- Un momento, activa el **Loop** de "rodar" y describe qué pasa. Debe conectar con tu razonamiento de la pregunta 3: con Loop, `animation_finished` nunca se emite, el `await` nunca continúa, `rodando` nunca vuelve a `false`. Luego **desactívalo** otra vez.

## Trampas comunes

- Olvidar el `return` dentro de `if rodando:` → sigues leyendo el teclado mientras ruedas.
- No devolver `speed_scale = 1` en las otras animaciones → correr contamina el resto.
- Dejar `rodar` con Loop → rueda para siempre (esto es justo lo que debes observar, no dejar así).
- Poner `await` en `_physics_process` y bloquear el frame → el `await` va **dentro de `rodar()`**, no en el bucle principal.
- Crear el nodo de audio con otro nombre (`rodar` en minúscula) → `$Rodar` da null.

## Checklist de "terminado" del Nivel 3

- [ ] Corriendo libre, `speed_scale` = 1; a media velocidad, la animación va a la mitad.
- [ ] La animación `rodar` (frames 7–12, 15 FPS, Loop **off**) existe.
- [ ] Rodar dura ~0.4 s (~24 frames de física) y recorre ~160 px (compruébalo).
- [ ] Mientras rueda, las teclas no cambian nada (no cambia dirección ni vuelve a rodar).
- [ ] Con Loop activado, rueda para siempre (probado y explicado).
- [ ] Justificaste el reproductor (2D) para el sonido de rodar.
- [ ] Respuestas c y d del documento.

---

Empieza por las **preguntas 1–4** (las de papel). Cuando las tengas escritas, mándamelas y te hago preguntas para afinarlas; después pasamos al código. ¿Vamos?

---

### Interacción 14

#### Prompt (usuario)

Empecemos con el punto A, vamos paso a paso

#### Respuesta de la IA

Perfecto, paso a paso. Punto A es solo `speed_scale`.

## Paso 1: Entender qué es `speed_scale`

`speed_scale` es una propiedad del `AnimatedSprite2D` que **multiplica los FPS** de la animación actual:

- `speed_scale = 1` → la animación va a sus FPS normales (correr = 10 FPS, según `jugador.tscn:59`).
- `speed_scale = 0.5` → va a la **mitad** de rápido.
- `speed_scale = 2` → al **doble**.

Es decir, es el "control de velocidad" de las piernas.

## Paso 2: Derivar la fórmula (esto es la Pregunta 1)

La idea: las piernas deben moverse **en proporción a la rapidez real**. Si vas a tope, piernas normales; si vas a la mitad, piernas a la mitad.

Hagamos la tabla. Necesitas la **rapidez real en x** (`abs(real.x)`) y la **referencia** `speed` = 220:

| Rapidez real `abs(real.x)` | ¿Verlo como fracción? | `speed_scale` que quieres |
|---|---|---|
| 220 | 220 / 220 | 1 |
| 110 | 110 / 220 | 0.5 |
| 55 | 55 / 220 | 0.25 |

Pregúntate: ¿qué operación, usando `abs(real.x)` y `speed`, produce esos valores de la última columna?

Escribe **tú la fórmula** aquí (una división). No la escribas en el código todavía; primero dime la fórmula.

```
sprite.speed_scale = ______________
```

Cuando la tengas, seguimos al Paso 3 (dónde va y cómo resetear a 1 en las otras animaciones).

---

### Interacción 15

#### Prompt (usuario)

correr?

#### Respuesta de la IA

Sí, exacto: esto es **para "correr"**. La fórmula se aplica solo cuando la animación que se reproduce es `"correr"`.

Ahorita olvídate del código y respondamos primero la fórmula en palabras.

Mira la tabla otra vez:

- Rapidez real = 220 → quieres `1`
- Rapidez real = 110 → quieres `0.5`
- Rapidez real = 55 → quieres `0.25`

Pregúntate: ¿qué le hiciste al número de la izquierda para convertirlo en el de la derecha?

- `220 → 1`... ¿qué pasó con ese 220? (¿entre cuánto se dividió?)
- `110 → 0.5`... lo mismo.

El patrón: **dividir la rapidez real entre la referencia (220)**.

En GDScript, dividir se escribe con `/`, y la rapidez real la tienes en `real.x` (pero sin importar el signo, por eso `abs(...)`).

Ahora sí, completa tú:

```
sprite.speed_scale = ______________
```

Pista de las piezas que debes usar: `abs(...)`, `real.x` y `speed`. Solo falta el signo de división entre ellas.

---

### Interacción 16

#### Prompt (usuario)

real.x / speed

#### Respuesta de la IA

Muy cerca. Te falta **una pieza**: `abs(...)`. Pregúntate:

- Moviéndote a la **izquierda**, ¿qué valor tiene `real.x`? Negativo (ej. `-220`).
- Entonces `real.x / speed` daría... `-220 / 220 = -1`, un `speed_scale` **negativo**.
- ¿Sabes qué hace un `speed_scale` negativo en Godot? Reproduce la animación **al revés** (los cuadros hacia atrás).

¿Es eso lo que quieres al caminar a la izquierda? No: la dirección **ya la resuelve `flip_h`** (Nivel 2). Aquí solo te importa **qué tan rápido** corre, no hacia dónde.

Por eso envolvemos en `abs(...)`, que quita el signo y deja solo la magnitud:

- `-220` → `abs` → `220` → `/ 220` → `1` ✅
- `110` → `abs` → `110` → `/ 220` → `0.5` ✅

Completa:

```
sprite.speed_scale = abs(_________) / _________
```

Llena los dos huecos con `real.x` y `speed` en el orden correcto.

---

### Interacción 17

#### Prompt (usuario)

sprite.speed_scale = abs(real.x) / speed

#### Respuesta de la IA

¡Perfecto! Esa es la fórmula. Ahora **dónde va y cómo se resetea**.

## Paso 3: Colocarla en el lugar correcto

La fórmula va **dentro de la rama `correr`**, la que ya tienes:

```
elif abs(real.x) > 1.0:
	sprite.play("correr")
	sprite.speed_scale = abs(real.x) / speed     # <- aquí
```

## Paso 4: ¿Y las otras animaciones?

Pregunta clave: `speed_scale` es una propiedad que **se queda pegada** entre frames. Si corres a media velocidad (`0.5`) y de repente **saltas**, ¿qué `speed_scale` tendría "saltar"? Se quedaría en `0.5`... y la animación de saltar iría a la mitad sin querer.

Entonces, ¿qué hay que hacer con `speed_scale` en las animaciones que **no** son correr? Devolverlo a `1` (ritmo normal).

Hay dos formas de escribirlo. Piénsalas:

- **Opción 1:** poner `sprite.speed_scale = 1` en *cada* rama (saltar, caer, quieto). Más repetitivo.
- **Opción 2:** poner `sprite.speed_scale = 1` **una sola vez al inicio** de la función (antes del `if not is_on_floor()`), y luego solo sobrescribirlo en la rama de correr. Menos repetitivo.

¿Cuál te parece mejor y por qué? Piénsalo: si pones el `1` al inicio, ¿las ramas de saltar/caer/quieto ya quedan cubiertas sin escribir nada en ellas?

Elige una, aplica el cambio en `actualizar_animacion()` y mándame cómo queda.

---

### Interacción 18

#### Prompt (usuario)

opcion 2

#### Respuesta de la IA

Buena elección. Ahora escríbelo tú. La estructura queda así:

```
func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1                 # <- Opción 2: se resetea una vez
	if not is_on_floor():
		sprite.play("saltar" if real.y < 0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed   # <- solo correr lo cambia
	else:
		sprite.play("quieto")
```

Fíjate en el orden lógico:
1. Primero el `1` (base para todas).
2. Después las ramas; solo la de correr lo pisa.

Cópialo a tu `jugador.gd`, guárdalo y córrelo. Comprueba el punto A: corre a tope (debe verse normal) y ... bueno, con teclado vas siempre a tope, así que `speed_scale` siempre será `1` corriendo. Para ver la diferencia de verdad lo confirmarás al final del taller con la fórmula.

Aplica ese bloque y mándame tu archivo; si está bien, pasamos al **punto B** (crear la animación `rodar` en el panel SpriteFrames).

---

### Interacción 19

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

Punto A quedó perfecto. Vamos al **punto B**: crear la animación `rodar` en el panel SpriteFrames (esto es en el editor, no en código).

## Contexto: ¿qué cuadros son cuáles?

`prisionero_hoja.png` es una tira horizontal de **19 cuadros** de 64×64. Los primeros ya están usados:

- cuadro 0 → `quieto`
- cuadros 1–4 → `correr`
- cuadro 5 → `saltar`
- cuadro 6 → `caer`
- **cuadros 7–12 → `rodar`** (los que te faltan, 6 cuadros)

## Paso a paso en el editor

1. Abre `jugador.tscn`.
2. Selecciona el nodo **`AnimatedSprite2D`**.
3. Abajo aparecerá el panel **SpriteFrames**. Si no lo ves, haz clic en la pestaña **SpriteFrames** en la parte inferior.
4. En ese panel, busca el botón **Add Animation** (ícono de **+**). Crea una y ponle el nombre exacto **`rodar`**.
5. Con `rodar` seleccionada, haz clic en **Add frames from Sprite Sheet** (el ícono de una **rejilla / frame**).
6. En el diálogo que se abre:
   - Elige `res://assets/prisionero_hoja.png`.
   - Pon **Horizontal = 19** y **Vertical = 1**.
7. Ahora selecciona **solo los cuadros 7 al 12** y confirma con **Add Frames**.
   - *Si el diálogo te agrega los 19 de una sola vez:* agrega todos y luego, en la lista de la animación `rodar`, borra los que sobren (selecciona los cuadros 0–6 y 13–18 y usa **Remove Frame**) hasta que queden justo los 7–12.
8. Con la animación `rodar` seleccionada, ajusta en el panel:
   - **Speed / FPS = 15**.
   - **Loop = desactivado** (destilda el botón de Loop). ← Esto es clave para la Pregunta 3.

## Cómo saber que quedó bien

- La animación `rodar` debe tener **exactamente 6 frames** (los de las piernas enrollándose / la bola).
- FPS = 15, Loop = off.
- **No** toques las otras animaciones (`quieto`, `correr`, `saltar`, `caer`).

Hazlo y cuéntame: ¿te quedaron 6 frames a 15 FPS con Loop apagado? Si algo no se ve o te sale raro (por ejemplo, un cuadro equivocado), descríbemelo y lo revisamos.

Cuando lo tengas, seguimos con el **punto C** (nodo de sonido `Rodar`).

---

### Interacción 20

#### Prompt (usuario)

entra al proyecto y revisalo, segun yo ya esta todo

#### Respuesta de la IA

Revisé los archivos en disco. **Falta más de lo que crees.** Esto es lo que hay realmente:

## Lo que SÍ está bien
- **`Espada`** (Nivel 2): el nodo `AudioStreamPlayer2D` existe en `jugador.tscn:110-111` con `espada.wav`. ✅
- La lógica de `orientar()` y el ataque en `jugador.gd:17-18,40-45`. ✅

## Lo que FALTA

**1. Punto A — `speed_scale` NO está guardado.**
Tu `actualizar_animacion()` en disco (`jugador.gd:31-38`) es la versión vieja, sin `speed_scale`. El código que me pegaste con la fórmula **no quedó guardado**:

```
31: func actualizar_animacion():
32: 	var real = get_real_velocity()
33: 	if not is_on_floor():          <- falta el speed_scale = 1
34: 		sprite.play("saltar" if real.y <0 else "caer")
35: 	elif abs(real.x) > 1.0:
36: 		sprite.play("correr")       <- falta la fórmula
```

¿Se te olvidó **Ctrl+S** en Godot? Vuelve a pegarlo y guarda.

**2. Punto B — la animación `rodar` NO existe.**
En el SpriteFrames solo hay 4 animaciones: `caer`, `correr`, `quieto`, `saltar` (`jugador.tscn:36-77`). No aparece `rodar`. Hay que crearla en el panel SpriteFrames.

**3. Punto C — el nodo `Rodar` NO existe.**
En la escena solo está el hijo `Espada`; **no hay** `AudioStreamPlayer2D` llamado `Rodar` colgado del `Prisionero`.

---

Así que el Nivel 2 sí está completo, pero del Nivel 3 solo tienes la **fórmula pensada**, no guardada, y nada más.

**Siguiente paso:** entra a Godot, abre `jugador.gd`, pega el bloque de `speed_scale` y guarda con **Ctrl+S**. Dime cuando esté y vuelvo a revisar el archivo para confirmar antes de pasar al punto B.

---

### Interacción 21

#### Prompt (usuario)

y ahora

#### Respuesta de la IA

Ahora sí guardaste el **Punto A** (`jugador.gd:33,38`) ✅. Y el **Punto B** existe (animación `rodar`, 6 frames, 15 FPS, Loop = 0 ✅)... **pero los cuadros están corridos uno**. Y el **Punto C sigue faltando**.

## El problema del Punto B: cuadros corridos

Miré la imagen `prisionero_hoja.png`. La tira tiene, en este orden:
- 7 figuras humanoides (cuadros 0–6: quieto, correr, saltar, caer)
- **6 círculos oscuros** (la bola de rodar) ← estos son `rodar`
- luego unas barras horizontales (sin uso)

Tu animación `rodar` (`jugador.tscn:93-115`) usa las regiones 384, 448, 512, 576, 640, 704. La primera (384) es **la última figura humanoide** (el cuadro de "caer"), no una bola. O sea: empezaste un cuadro antes y por eso te falta la última bola.

Róllalo así: **`rodar` debe ser SOLO los 6 círculos**, sin ninguna figura parada.

**Cómo arreglarlo en Godot:**
1. Abre `jugador.tscn` → `AnimatedSprite2D` → panel SpriteFrames → selecciona `rodar`.
2. Borra los 6 frames actuales (selecciónalos y usa **Remove Frame**).
3. Vuelve a **Add frames from Sprite Sheet** con `prisionero_hoja.png`, `19 × 1`.
4. Selecciona **solo los 6 círculos** (haz clic en el primero, y con **Shift** clic en el último, o clic en cada uno) y **Add Frames**.
5. Confirma: 6 frames, FPS 15, Loop off.

Truco para no equivocarte: el **primer** cuadro de `rodar` debe verse como una bola, **no** como el Prisionero de pie.

## Punto C: falta el nodo `Rodar`

En la escena solo está `Espada` (`jugador.tscn:157`). No hay `AudioStreamPlayer2D` llamado `Rodar`. Créalo colgado del `Prisionero` con `assets/rodar.wav`, igual que hiciste con `Espada`.

---

Haz esas dos cosas (corregir los cuadros y crear el nodo `Rodar`) y avísame. Después re-reviso los archivos antes de pasar al **Punto D** (el código de `_physics_process` + `rodar()`).

---

### Interacción 22

#### Prompt (usuario)

listo re revisa

#### Respuesta de la IA

Revisado. Todo el **Punto B y C ahora están correctos**:

- `rodar` usa las regiones `448, 512, 576, 640, 704, 768` → cuadros **7 a 12**, las 6 bolas. ✅ (`jugador.tscn:94-116`)
- Nodo **`Rodar`** existe colgado del `Prisionero` con `rodar.wav`. ✅ (`jugador.tscn:161-162`)
- `speed_scale` guardado. ✅ (`jugador.gd:33,38`)

Detalle menor (opcional): el `AnimatedSprite2D` tiene `animation = &"rodar"` como predeterminada (`jugador.tscn:138`). No rompe nada (el script manda), pero si quieres volverlo a `&"quieto"` para que el editor arranque parado, es un clic.

---

## Punto D: el código de rodar

Vamos por partes. Primero **las variables**.

### D1. Declarar variables

Necesitas tres cosas nuevas arriba, junto a las que ya tienes (`jugador.gd:4-11`):

- `@export var velocidad_rodar = 400.0` → la rapidez del rodar (te la da el taller).
- `var rodando = false` → el "candado" (el interruptor del estado). Como `mirando`, es `var` normal (no `@onready`, no es nodo).
- La referencia al nodo de sonido. **Ojo con un choque de nombres:** si la llamas `rodar`, choca con tu futura función `rodar()`. Ponle otro nombre, por ejemplo `sonido_rodar`, siguiendo el patrón de `espada`:

```
@onready var sonido_rodar = $Rodar
```

Añádelas y pásame el archivo o dime si las tienes. Luego seguimos con **D2: reestructurar `_physics_process`**.

(No sigas más allá de las variables todavía; así confirmo que no hay choques de nombre antes de que toques el flujo del bucle.)

---

### Interacción 23

#### Prompt (usuario)

como hago eso "Detalle menor (opcional): el AnimatedSprite2D tiene animation = &"rodar" como predeterminada (jugador.tscn:138). No rompe nada (el script manda), pero si quieres volverlo a &"quieto" para que el editor arranque parado, es un clic. "

#### Respuesta de la IA

Es fácil, se hace en el editor:

1. Abre `jugador.tscn`.
2. Selecciona el nodo **`AnimatedSprite2D`**.
3. En el **Inspector** (panel derecho), busca la propiedad **`Animation`** (debajo de `Sprite Frames`). Ahí dice `rodar`.
4. Haz clic en el menú desplegable y elige **`quieto`**.

Con eso queda. En el archivo (`jugador.tscn:138`) la línea que decía `animation = &"rodar"` pasará a ser `animation = &"quieto"`.

**¿Por qué importa poco?** Porque tu script decide la animación cada frame con `sprite.play(...)` en `actualizar_animacion()`, así que en cuanto corre el juego la sobrescribe. Esto solo afecta a lo que ves **parado en el editor** (el preview). Es cosmético, no funcional.

Guarda con **Ctrl+S** y dime cuando esté; seguimos con D2 (variables + `_physics_process`).

---

### Interacción 24

#### Prompt (usuario)

listo sigamos

#### Respuesta de la IA

Perfecto. Vamos con las **variables (D1)**. Tienes que agregar 3 líneas arriba, junto a las que ya están (`jugador.gd:4-11`):

```
@export var speed = 220.0
@export var gravedad = 1200.0
@export var salto = 560.0
@export var velocidad_rodar = ____      # <- 1) el valor que da el taller

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe
@onready var espada = $Espada
@onready var sonido_rodar = $____       # <- 2) el nombre exacto del nodo de audio
var mirando = 1
var rodando = ____                      # <- 3) ¿con qué valor empieza (no rueda)?
```

Completa los 3 huecos:

1. **`velocidad_rodar`**: ¿a cuántos px/s rueda? (está en el taller / punto D).
2. **`sonido_rodar = $____`**: el nombre del nodo que creaste en la escena (`jugador.tscn:161`). Debe ir **exacto**, con mayúscula.
3. **`var rodando = ____`**: el valor **inicial** para que el personaje **no** esté rodando al empezar. ¿`true` o `false`?

Pregunta de razonamiento para el #2: ¿por qué nombramos la variable `sonido_rodar` y no `rodar`? (recuerda: más abajo vas a escribir una **función** llamada `rodar()`; dos cosas con el mismo nombre chocan).

Añade esas líneas y mándame el archivo (o dime "listo"). Después vamos a **D2**: meter el bloque `if rodando:` al inicio de `_physics_process`.

---

### Interacción 25

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

Variables correctas ✅. Ahora **D2: reestructurar `_physics_process`**.

Vas a meter **dos bloques nuevos al inicio** y dejar tus líneas actuales **debajo**. La forma final es:

```
func _physics_process(delta):
	if rodando:
		velocity.x = ____ * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
```

Tu única tarea de escritura es el hueco:

- **`velocity.x = ____ * mirando`**: ¿qué variable, multiplicada por `mirando`, lanza al personaje a rodar hacia donde mira a la velocidad correcta? (la declaraste en D1).

Preguntas para que entiendas **por qué** está armado así (no copies a ciegas):

1. **¿Por qué `if rodando:` va de primero?** Si rodando, quieres que el bloque "secuestre" al personaje y **no** se ejecute la lógica normal del teclado. Si estuviera después, `mover()` ya habría leído las teclas.

2. **¿Para qué el `return` dentro de `if rodando:`?** Piénsalo: sin él, después de mover al personaje rodando seguiría ejecutando `mover()`, `orientar()`... y volvería a leer el teclado, cambiando la dirección → rompe el "mientras rueda no se cambia de dirección". El `return` corta el frame ahí.

3. **¿Por qué la gravedad y `move_and_slide()` están repetidos dentro de ese bloque?** Porque al hacer `return` te saltas `mover()`, que era quien aplicaba gravedad y movía. Si no las repites, el personaje rodaría "flotando" o sin colisionar.

4. **`if Input.is_action_just_pressed("rodar") and is_on_floor():`** ¿por qué pide `is_on_floor()`? ¿Tiene sentido rodar en el aire? (no: es una acción de suelo). ¿Y por qué `rodar()` lleva su propio `return` después, para no ejecutar además la lógica normal ese mismo frame?

Escribe el bloque completo con tu hueco y mándame el archivo. Después vamos a **D3**: el cuerpo de la función `rodar()` (donde va el `await`).

---

### Interacción 26

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	if rodando:
		velocity.x = "rodar" * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

Casi. El hueco lo llenaste con `"rodar"`, que tiene **dos problemas**:

```
velocity.x = "rodar" * mirando
```

1. **Las comillas.** `"rodar"` con comillas es **texto** (un string), no un número. No puedes multiplicar texto por `mirando`; Godot te dará un error de tipos. Compáralo: `speed`, `salto`, `gravedad` no llevan comillas — son números.
2. **El nombre.** La variable que declaraste en D1 se llama **`velocidad_rodar`**, no `rodar`. Y `rodar` (sin comillas) sería además tu función, que no es un número.

Lo que quieres es usar **la variable de velocidad** que creaste. Pregúntate: ¿cuál de las variables de arriba guarda "a cuántos px/s rueda"? Esa va ahí, sin comillas:

```
velocity.x = velocidad_rodar * mirando
```

Léelo en voz alta: *"la velocidad horizontal es la velocidad de rodar, en la dirección en que mira"*. Corrige esa línea y mándame el archivo. Luego **D3**: el cuerpo de `rodar()`.

---

### Interacción 27

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	if rodando:
		velocity.x = rodando * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

De nuevo el nombre equivocado, y ahora es un nombre **muy parecido** al correcto. Fíjate que tienes **dos variables que suenan igual pero son cosas distintas**:

| Variable | Qué guarda | Tipo | Ejemplo |
|---|---|---|---|
| `rodando` | ¿está rodando **ahora**? | booleano | `true` / `false` |
| `velocidad_rodar` | ¿a qué **velocidad** rueda? | número | `400.0` |

Tú escribiste `rodando`, que es el **candado** (`true`/`false`). Pregúntate: si `rodando` vale `true`, ¿`true * mirando` qué número da? Nada útil: es un booleano, no una velocidad. Godot te marcará error de tipos.

Lo que necesitas es la **velocidad**, o sea `velocidad_rodar`:

```
velocity.x = velocidad_rodar * mirando
```

Léelo: *"la velocidad horizontal = 400 px/s, hacia donde mira"*. Corrige esa línea y mándame el archivo. Luego pasamos a **D3: el cuerpo de `rodar()`** (ahí sí va el `await`).

---

### Interacción 28

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	if rodando:
		velocity.x = velocidad_rodar * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

#### Respuesta de la IA

¡Perfecto! D2 quedó bien. Ahora **D3: la función `rodar()`**.

Va al final del archivo, como una función nueva (al mismo nivel que `mover`, `actualizar_animacion`, `orientar`). El taller te da 4 pasos **en orden**:

```
func rodar():
	# 1. Marquen que está rodando; speed_scale en 1.
	# 2. Reproduzcan "rodar" y el sonido.
	# 3. Esperen a que la animación termine (await ...).
	# 4. Dejen de estar rodando.
```

Preguntas para escribir cada paso (tú decides las líneas):

1. **Marcar que rueda**: ¿qué variable pones en `true` para activar el bloque `if rodando:` de `_physics_process`?
   - Y `sprite.speed_scale = 1`: ¿por qué aquí? Porque la animación de rodar tiene su propio ritmo (15 FPS) y no debe heredar el `speed_scale` que dejó "correr". ¿Qué método de `sprite` reproduce la animación llamada exactamente `"rodar"`? (igual que ya haces en `actualizar_animacion`: `sprite.play("...")`).
   - ¿Y qué nodo reproduce el sonido? El que declaraste en D1 (`sonido_rodar`), con el método `.play()`.

2. **El `await`** (paso 3): la clave del nivel. Quieres esperar a que la **animación termine** sin congelar el juego. El esqueleto dice `await ...`. Pregúntate: ¿de qué objeto quieres esperar la señal de "terminé"? Del `sprite`. ¿Cómo se llama esa señal cuando una animación no tiene loop? `animation_finished`.
   - La línea queda: `await sprite.animation_finished`.
   - **Ese `await` va dentro de `rodar()`, nunca en `_physics_process`.** ¿Por qué? Porque si lo pones en el bucle principal, congelarías todo el frame a la espera; dentro de `rodar()`, el juego sigue corriendo y solo esa función pausa y luego continúa.

3. **Soltar el candado**: cuando la animación termine (y hayas salido del `await`), pon `rodando = false` para que el teclado vuelva a leerse.

Escribe la función completa y mándame el archivo. Después de eso: **probar el rodado** y luego la **prueba del Loop** (punto F).

---

### Interacción 29

#### Prompt (usuario)

1. rodando?

#### Respuesta de la IA

Sí, exacto: la variable es **`rodando`**. Recuerda lo que significa:

- `rodando = true` → "ahora sí está rodando" (activa el bloque `if rodando:`).
- `rodando = false` → "ya no rueda".

En el **paso 1** la pones en `true`, porque acabas de empezar a rodar:

```
func rodar():
	rodando = true
	sprite.speed_scale = 1
```

*(El `sprite.speed_scale = 1` es el otro pedazo del paso 1, para que "rodar" no herede la velocidad que dejó "correr".)*

Eso es el paso 1. Ahora escribe los pasos **2, 3 y 4**, siguiendo las preguntas de mi mensaje anterior:

- Paso 2: reproducir `"rodar"` y el sonido (dos líneas: `sprite.play(...)` y `sonido_rodar.play()`).
- Paso 3: `await sprite.animation_finished`.
- Paso 4: `rodando = false`.

Mándame la función completa cuando la tengas.

---

### Interacción 30

#### Prompt (usuario)

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar

#### Respuesta de la IA

Bien los tres primeros. Pero `sonido_rodar` solo, igual que te pasó con `espada`, **no hace nada**: solo menciona el nodo. Le falta el método que lo reproduce. Fíjate que a `sprite` no lo dejas solo: le llamas `sprite.play("rodar")`. Al sonido le toca lo mismo:

```
sonido_rodar.play()
```

Y todavía le faltan los pasos **3 y 4**:

- Paso 3: `await sprite.animation_finished`
- Paso 4: `rodando = false`

Arma la función completa:

```
func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	____ sprite.animation_finished
	____ = false
```

Completa los dos huecos (`await` y la variable) y mándame el archivo.

---

### Interacción 31

#### Prompt (usuario)

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play("rodar")

#### Respuesta de la IA

Ojo con un detalle: `sonido_rodar.play("rodar")` — le pasaste `"rodar"` entre paréntesis. Ese nombre es **solo para el sprite** (`sprite.play("rodar")` le dice *qué animación* mostrar). El reproductor de audio **no tiene animaciones**: solo tiene un sonido ya cargado, así que su `play()` **no lleva argumentos**:

```
sonido_rodar.play()
```

Si le pasas algo, Godot te marcará error ("too many arguments" / el método no acepta parámetros).

Corrígelo y completa los **pasos 3 y 4**:

```
func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	____ sprite.animation_finished      # paso 3: esperar
	rodando = ____                      # paso 4: soltar el candado
```

Llena esos dos huecos y mándame el archivo completo.

---

### Interacción 32

#### Prompt (usuario)

No entiendo lo que va despues de sonido_rodar

#### Respuesta de la IA

Tranquilo, te explico esos dos pasos con calma.

Después de `sonido_rodar.play()` van **dos líneas más**, una por cada paso que falta:

## Paso 3: esperar a que la animación termine

```
await sprite.animation_finished
```

¿Qué significa cada palabra?

- **`sprite`** = el mismo nodo que ya usas (`sprite.play(...)`). Aquí le preguntas a él.
- **`animation_finished`** = una **señal**: un "aviso" que el `AnimatedSprite2D` dispara **solo** cuando la animación actual acaba. Como "rodar" tiene Loop **apagado**, la animación sí termina (al llegar al sexto cuadro), y en ese momento emite el aviso.
- **`await`** = "espérate aquí hasta que ese aviso ocurra, sin congelar el juego". La función `rodar()` se queda pausada en esa línea hasta que la animación llama. Mientras tanto, el resto del juego sigue normal.

Léelo en voz alta: *"espera a que el sprite termine la animación"*.

## Paso 4: soltar el candado

```
rodando = false
```

Cuando la animación ya terminó (o sea, `await` hizo su trabajo y sigue), pones `rodando` en `false` para avisar que ya no rueda. Con eso, en el siguiente frame el bloque `if rodando:` se desactiva y el teclado vuelve a leerse.

## Cómo queda la función completa

```
func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
```

Fíjate en el orden: **1** enciende el candado → **2** suena y se anima → **3** espera a que la animación acabe → **4** apaga el candado. Como un reloj de arena: lo volteas (true), cae la arena (la animación/await), y cuando termina lo cierras (false).

Cópiala a tu archivo (después de `orientar()`) y mándame el proyecto completo. Luego lo probamos corriendo.

---

### Interacción 33

#### Prompt (usuario)

nonono, me refiero a esto "func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play() "rodar" sprite.animation_finished "

#### Respuesta de la IA

¡Ah, ya entiendo tu confusión! Esas cosas **no van en la misma línea** que `sonido_rodar.play()`. Son **líneas separadas**, cada una debajo de la otra.

`sonido_rodar.play()` **termina ahí**, con los paréntesis **vacíos**. No lleva `"rodar"` ni nada más adentro.

Después, **en la línea de abajo**, va el `await`. Y en otra línea más abajo, `rodando = false`.

Mira cómo se ve, línea por línea (5 líneas dentro de la función):

```
func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
```

Cuenta las líneas después de `func rodar():`:

1. `rodando = true`
2. `sprite.speed_scale = 1`
3. `sprite.play("rodar")`
4. `sonido_rodar.play()`  ← aquí **no** va nada más
5. `await sprite.animation_finished`  ← esta es una línea aparte
6. `rodando = false`  ← y esta, otra aparte

Cada una es una instrucción distinta. `"rodar"` ya lo usaste en la línea 3 (dentro de `sprite.play(...)`), no se repite. Y `sprite.animation_finished` va con `await` en la línea 5.

Cópialo así, tal cual, y mándame el archivo.

---

### Interacción 34

#### Prompt (usuario)

extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	if rodando:
		velocity.x = velocidad_rodar * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	if Input.is_action_just_pressed("atacar"):
		espada.play()
	
	# Taller 3: aquí van la animación, la orientación, el ataque y el rodar.


func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y <0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false

#### Respuesta de la IA

El código que me pegaste está **perfecto**: la función `rodar()` completa y `velocity.x = velocidad_rodar * mirando`. Pero **otra vez no lo guardaste** 😅. Mira lo que hay en disco:

```
19: 		velocity.x = "rodar" * mirando          <- la versión vieja con comillas
...
60: (el archivo termina en orientar)            <- NO existe la función rodar()
```

O sea, tu editor de Godot tiene la versión buena, pero el archivo guardado todavía tiene el error de `"rodar"` y le falta toda la función `rodar()`.

**Presiona Ctrl+S en Godot** y avísame; vuelvo a leer el disco para confirmar.

---

## Cuando guardes, prueba esto (es la verificación del Nivel 3)

1. **Rodar básico**: párate y presiona L (o Shift). Debe rodar hacia donde miras. Compara con lo calculado: ~0.4 s, ~160 px.
2. **Teclado bloqueado**: mientras rueda, oprime A/D. **No** debe cambiar de dirección ni hacerse más corto el rodar.
3. **No re-rodar**: mientras rueda, oprime L otra vez. No debe reiniciarse.
4. **Correr**: `speed_scale` debe ser 1 al correr (agrégalo a un `print` si quieres verlo).

## La prueba del Loop (obligatoria para la nota)

5. Abre `jugador.tscn` → `AnimatedSprite2D` → SpriteFrames → selecciona `rodar` → **activa el Loop** un momento. Corre el juego y rueda. **Describe qué pasa** (conecta con tu respuesta de la Pregunta 3: `animation_finished` nunca se emite, el `await` nunca continúa, `rodando` se queda en `true`). Luego **desactiva el Loop** otra vez y guarda.

Cuando hayas guardado y probado, dime el resultado (sobre todo lo que observaste con el Loop) y pasamos a cerrar el documento de entrega (respuestas a, b, c, d + anexo IA).

---

### Interacción 35

#### Prompt (usuario)

Listo ya garde{

#### Respuesta de la IA

Guardado y todo correcto ✅. Reviso el archivo completo:

- **Nivel 1**: `actualizar_animacion()` con `is_on_floor()` + velocidad real, y `speed_scale` (líneas 44-53). ✅
- **Nivel 2**: `orientar()` con `mirando`, `flip_h` y golpe que cambia de lado (55-60); espada con `atacar` (30-31) y nodo `Espada`. ✅
- **Nivel 3**: nodo `rodar` con cuadros 7-12, Loop off; nodo `Rodar`; bloque `if rodando:` (18-23); disparo (24-26); y `rodar()` con el `await` (62-68). ✅

**El código del taller está completo.** Falta la parte de comprobar y el documento.

## Lo que debes comprobar ahora (en el juego)

1. Rodar dura ~0.4 s (~160 px).
2. Mientras ruedas, A/D **no** cambian la dirección y L **no** reinicia el rodar.
3. La prueba del **Loop** (actívalo, rueda, describe; luego desactívalo).

## El documento de entrega

Necesitas redactar:
- Por nivel: tus respuestas de "Antes de programar", el código, las capturas y una línea de si la predicción coincidió.
- Respuestas cortas **a, b, c, d** (con tus palabras).
- **Anexo IA**: si usaste IA (me has usado a mí), el taller pide copiar **cada prompt y la respuesta completa**. Si no, "No se usó IA". Ojo: sin anexo, el taller no se califica.

---

¿Quieres que te ayude a **construir ese documento**? Puedo hacerte preguntas para que redactes tú las respuestas a, b, c y d, o darte un índice de qué captura conviene por nivel. Dime por dónde prefieres empezar.

---

### Interacción 36

#### Prompt (usuario)

Puedes tu hacer ese documento por favor?

#### Respuesta de la IA

Claro. Te armo el documento con toda la estructura y las respuestas, dejando **marcadores `[...]`** en lo que solo tú puedes completar (tu nombre, tus predicciones exactas y capturas). Lo guardo en tu carpeta del taller.

Listo. Creé el documento en:

`...\Base Taller 3\Entrega_Taller3_DeadCells.md`

Contiene las tres secciones de nivel (respuestas de "Antes de programar", código y espacio para capturas) más las respuestas **a, b, c, d** y el **Anexo IA**. Lo que debes completar tú:

1. **[TU NOMBRE COMPLETO]** y la fecha.
2. **Las capturas** de cada nivel (hay un `[CAPTURA: ...]` indicando cuáles).
3. **Revisar las respuestas** de "Antes de programar" y ponerlas en tus palabras / según lo que de verdad predijiste.
4. **Anexo IA**: pega el historial completo de esta conversación (prompts + respuestas). El taller lo exige y **sin ese anexo no se califica**.
5. Exportar a **PDF** o subir el enlace a tu fila del Excel.

Un par de notas honestas:

- Varias respuestas las redacté yo a partir de lo que **tú** deduces en esta charla; léelas y ajústalas a tu estilo para que de verdad sean tuyas (el taller pide "con tus palabras").
- Como usaste IA, el anexo **no es opcional**: es justo lo que el taller pide declarar.

¿Quieres que convierta el `.md` a PDF, o que te muestre cómo se ve/estructura en pantalla para que lo revises?

---

### Interacción 37

#### Prompt (usuario)

damelo en un docx

#### Respuesta de la IA

No hay Office, pandoc ni LibreOffice. Genero el `.docx` con una librería de Node.

Listo. Creé el `.docx`:

`...\Base Taller 3\Entrega_Taller3_DeadCells.docx`

Incluye títulos, respuestas a/b/c/d, los bloques de código con fuente monoespaciada y los marcadores `[...]` para tu nombre, capturas y el Anexo IA. Ábrelo en Word/Docs para editar.

Recuerda: rellena tus datos, agrega las capturas y pega el historial de IA en el anexo (sin él, no se califica).

---

### Interacción 38

#### Prompt (usuario)

como puedo mostrar las primeras capturas para que la consola muestre eso

#### Respuesta de la IA

Para esa captura necesitas que la consola imprima el estado **en cada frame**. Se hace con un `print(...)` temporal.

## 1. Agregar el `print`

Va en `_physics_process`, **al final** (después de `actualizar_animacion()`), para que corra cada frame. La línea:

```gdscript
print(position.y, " - ", sprite.animation)
```

Piezas:
- `position.y` → la altura del Prisionero (para ver que sube y baja).
- `sprite.animation` → el nombre de la animación actual (`"saltar"`, `"caer"`, `"quieto"`...).
- `" - "` → texto separador para que se lea bonito.

Tu `_physics_process` quedaría (parte final):

```gdscript
	mover(delta)
	actualizar_animacion()
	orientar()
	print(position.y, " - ", sprite.animation)   # <- temporal, solo para la captura
	if Input.is_action_just_pressed("atacar"):
		espada.play()
```

Pregunta para pensar: ¿por qué debe ir **después** de `actualizar_animacion()` y no antes? Porque `actualizar_animacion()` es quien cambia `sprite.animation`; si imprimes antes, verías la animación del frame anterior.

## 2. Hacer la captura

1. Corre el juego con **F5**.
2. Salta en el lugar (Espacio) y **no toques A/D**.
3. Abre el panel **Output** abajo en Godot (pestaña `Output`).
4. Verás la secuencia de valores; busca el momento que muestre `... - saltar`, luego `... - caer`, luego `... - quieto`.
5. Captura esa parte de la consola.

## 3. Quitar el `print` (para las siguientes capturas)

Cuando tengas la captura, **borra esa línea** (o coméntala con `#`). Si la dejas, la consola se llena de texto y hace lento el juego.

---

Sugerencia: para la captura de la pared del Nivel 1 (que queda "quieto"), el mismo `print` te sirve: empuja la pared con la tecla presionada y verás `... - quieto`. ¿Quieres que te indique también cómo imprimir `golpe.position.x` para la captura del Nivel 2?

---

### Interacción 39

#### Prompt (usuario)

no quiero mas preguntas, solo dame el codigo y y

#### Respuesta de la IA

```gdscript
extends CharacterBody2D
# Movimiento resuelto: correr, gravedad y salto. El Taller 3 se escribe abajo.

@export var speed = 220.0       # px/s
@export var gravedad = 1200.0   # px/s²
@export var salto = 560.0       # px/s hacia arriba
@export var velocidad_rodar = 400.0

@onready var sprite = $AnimatedSprite2D
@onready var golpe = $Golpe     # el área que golpea con la espada
@onready var espada = $Espada
@onready var sonido_rodar = $Rodar

var rodando = false
var mirando = 1

func _physics_process(delta):
	if rodando:
		velocity.x = velocidad_rodar * mirando
		if not is_on_floor():
			velocity.y += gravedad * delta
		move_and_slide()
		return
	if Input.is_action_just_pressed("rodar") and is_on_floor():
		rodar()
		return
	mover(delta)
	actualizar_animacion()
	orientar()
	print(position.y, " - ", sprite.animation)   # TEMPORAL: borrar tras la captura
	if Input.is_action_just_pressed("atacar"):
		espada.play()

func mover(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = -salto
	velocity.x = Input.get_axis("move_left", "move_right") * speed
	move_and_slide()

func actualizar_animacion():
	var real = get_real_velocity()
	sprite.speed_scale = 1
	if not is_on_floor():
		sprite.play("saltar" if real.y < 0 else "caer")
	elif abs(real.x) > 1.0:
		sprite.play("correr")
		sprite.speed_scale = abs(real.x) / speed
	else:
		sprite.play("quieto")

func orientar():
	var eje = Input.get_axis("move_left", "move_right")
	if eje != 0:
		mirando = sign(eje)
		sprite.flip_h = mirando == -1
		golpe.position.x = 36 * mirando

func rodar():
	rodando = true
	sprite.speed_scale = 1
	sprite.play("rodar")
	sonido_rodar.play()
	await sprite.animation_finished
	rodando = false
```

Para la captura del Nivel 2, cambia la línea del `print` por:

```gdscript
	print(golpe.position.x)
```

---

### Interacción 40

#### Prompt (usuario)

Ayudame a hacer el anexo IA porfa,

#### Respuesta de la IA

Buena idea. Primero busco si opencode guarda el historial de esta sesión, para sacar el anexo exacto (tus prompts + mis respuestas).

Ahí está la base de datos de opencode. Voy a intentar leer el historial desde ahí.

El quoting rompió el comando. Escribo un script.

---

### Interacción 41

#### Prompt (usuario)

O si puedes crear un link que cualquiera pueda acceder a el

#### Respuesta de la IA

Hay un comando `opencode export`. Voy a exportar la sesión y a mirar si hay opción de compartir/enlace.

Exportado (900 KB). Ahora genero el anexo legible.

El JSON se corrompió por la codificación de PowerShell (los acentos salen mal). Lo re-exporto con Node para conservar UTF-8.

---
