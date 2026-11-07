# SuperLoad

Entrada al juego y pantallas de carga más rápidas para World of Warcraft 3.3.5a (WotLK), más algunos arreglos de la interfaz de Blizzard.

## Qué hace

- **Entrada más rápida**: el recolector de memoria se pausa mientras cargan los addons, y los demás addons no pueden forzar limpiezas completas durante la carga ni en combate. Se hace una sola limpieza al entrar al mundo, fuera de combate. Si la memoria crece demasiado durante la carga, igual se limpia por seguridad.
- **Pantallas de carga más rápidas**: los eventos ruidosos (hechizos, barras de acción, talentos, mapa, reputación y logros) se silencian mientras está la pantalla de carga y se devuelven apenas termina.
- **Arreglos de la interfaz** (solo con `hooksecurefunc`, sin taint):
  - Los botones de los menús desplegables ya no quedan detrás del fondo.
  - `InterfaceOptionsFrame_OpenToCategory` abre y muestra la categoría correcta a la primera.
  - El ping del minimapa sigue su posición al moverte y se desvanece suave.

No tiene opciones: se instala y funciona.

## Instalación

1. Descargá este repositorio (**Code → Download ZIP**).
2. Copiá la carpeta `!!!SuperLoad` en `World of Warcraft/Interface/AddOns/`.
3. Dejá los `!!!` en el nombre de la carpeta: hacen que SuperLoad cargue antes que todos los demás addons, que es lo que le permite acelerar la entrada.

## Requisitos

- WotLK 3.3.5a (Interface `30300`)
- Sin dependencias.

## Autor

**Nidhaus**
