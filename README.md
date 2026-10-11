# Poop My Park 💩🐶

Juego de Roblox: cuida perros en tu parque, junta su popó, abre sobres, consigue mutaciones con el clima y fusiona perros.

Hecho con [Rojo](https://github.com/rojo-rbx/rojo) 7.7.1 y Luau.

## Correr en local

```bash
rojo serve
```

En Roblox Studio abre un place vacío, ve a **Plugins → Rojo → Connect** y dale **Play**.

Para generar el archivo del place:

```bash
rojo build -o poop-my-park.rbxl
```

## Estructura

- `src/shared/` — datos del juego (`Data.luau`) y el modelo de perro (`DogModel.luau`)
- `src/server/` — economía, perros, popó, sobres, clima, equipo, progreso y mapa
- `src/client/` — interfaz, animaciones, cámara aérea, clima y pantalla de inicio

El balance (precios, probabilidades, multiplicadores) vive en `src/shared/Data.luau`.

> El guardado usa DataStore: publica el place y activa *Enable Studio Access to API Services* para probarlo en Studio.
