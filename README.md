# Delivery Game

Proyecto personal de exploración en **Godot 4.7** (GDScript). Juego de acción 2D side-scrolling: un mensajero cyberpunk entrega paquetes corriendo por una ciudad, esquivando tráfico y peleando contra enemigos mientras un dron lo persigue.

Estética de ilustración anime cyberpunk (no pixel art) — las animaciones del personaje y los enemigos salen de un pipeline propio con herramientas de IA generativa (Kling) más scripts Node.js para procesarlas (chroma key, recorte, limpieza de artefactos) hasta dejarlas listas como spritesheets para el motor.

## Qué tiene

- Combate con combos (golpes, patadas, barrida, patada voladora), hitstop y screen shake.
- Generador procedural de tráfico/obstáculos (autos, colectivos, camiones-rampa, policías) sin fin.
- Persecución de un dron que marca el ritmo del nivel.
- Pelea de jefe con fases y mozos aliados.
- HUD propio, estética fósforo verde cyberpunk.

## Stack

Godot 4.7, GDScript, `CharacterBody2D`. Pipeline de animación con Node.js (`tools/`) para procesar video generado por IA en spritesheets.

## Estado

En desarrollo activo, no es un juego terminado — es el proyecto donde exploro mecánicas de combate, cámara y generación procedural fuera del trabajo.
