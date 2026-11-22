# GoldFinder Forever

Addon para WoW Forever que te dice qué hacer con lo que llevas (vender al vendedor, subastar o guardar) y te ayuda a
subir profesiones gastando lo menos posible. Nada se vende, se publica ni se envía sin tu clic.

*An addon for WoW Forever that tells you what to do with what you carry (vendor, auction or keep) and helps you level
professions cheaply. Nothing is sold, posted or mailed without your click. The interface is available in English and Spanish (it follows your game language; change it in Options > AddOns > GoldFinder).*

## Funciones

- **Consejo en cada objeto**: vender, subastar o guardar, con el motivo (lo usa tu profesión, un alt o una misión).
- **Panel del vendedor**: lo que conviene venderle, con botones Vender y Guardar.
- **Casa de subastas**: pestaña GoldFinder con Subastar en un clic (precio y cantidad calculados al estilo TSM).
  Si tu último escaneo es viejo, el primer clic revisa el precio en vivo y el segundo publica. Un panel lateral
  plegable reúne la navegación y las opciones de publicación, y el botón Scan muestra su progreso.
- **Correo**: Enviar al banquero manda lo que hay que subastar a tu personaje banquero; cada línea tiene una
  casilla (y "Seleccionar todo") para dejar objetos fuera de ese correo.
- **Bolsas**: botón X para ocultar un objeto de la lista (por personaje) y botón Ver para recuperarlo.
- **Profesiones**: pestañas Ruta y Fabricar en la ventana de profesiones, chance de subir y coste por punto en cada
  receta, y una guía 1-300 (`/gf guia`) con tus precios, que ahora incluye Pesca y, con QuestieDB, dónde conseguir las
  recetas que se aprenden con un objeto.
- **Compras**: lo que te falta de cada profesión, con botón Lista que lo manda (nombres exactos y cantidades) a una lista de
  Auctionator, y una lista aparte por profesión.
- **Seguimiento**: tu siguiente paso de profesión en el seguimiento de objetivos, con el icono de cada material,
  lo que cuesta lo que te falta, la probabilidad de subir por fabricación y un aviso cuando la guía propone otra receta.
- **Opciones** en Opciones > AddOns > GoldFinder Forever.

## Requisitos

- Obligatorio: **Auctionator** (precios de subasta).
- Opcionales: **QuestieDB** (recomendado: objetos de misiones y cadenas, y dónde conseguir las recetas que se
  aprenden con un objeto; sin él esas partes se omiten) y **TradeSkillMaster** (precios de mercado).

## Comandos

La interfaz está en español e inglés: sigue el idioma del juego y se cambia en las opciones.

`/gf` abre la ventana, `/gf guia [profesion]` la guía, `/gf ajustes` las opciones, `/gf ruta N` y `/gf tope N`.

## Fuentes de datos

- Recetas y guía de profesiones: tablas públicas del juego (wago.tools), generadas con `tools/`.
- Rutas de Peletería, Minería y Herboristería y ubicación de instructores: datos sueltos de las guías de Icy Veins.
- No contiene datos de Zygor ni código de otros addons.

## Licencia

MIT. Ver `LICENSE`.
