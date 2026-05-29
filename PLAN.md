# ScreenOS — Plan de Arquitectura

## Resumen

Aplicación nativa **Swift + AppKit** que corre en la barra de menús de macOS. Gestiona ventanas mediante la **Accessibility API** (AXUIElement) y atajos globales de teclado.

---

## Features (confirmadas)

| # | Feature | Descripción | Atajo por defecto |
|---|---------|-------------|-------------------|
| 1 | **Show Desktop** | Minimiza/oculta todas las ventanas → escritorio limpio | `⌘⇧D` |
| 2 | **Window Tiling** | Colocar ventana activa en posiciones predefinidas | `⌘⌥ ←/→/↑/↓` |
| 2b | **Maximize / Center** | Maximizar ventana o centrarla | `⌘⌥ M` / `⌘⌥ C` |
| 3 | **Menu Bar** | Icono en barra de menús con acceso rápido a todas las acciones | — |
| 4 | **Window Switcher** | Overlay con miniaturas, iconos y búsqueda de ventanas | `` ⌘` `` |

---

## Arquitectura de componentes

```
ScreenOS.app
├── AppDelegate.swift           ← Entry point, setup menu bar
├── WindowManager.swift         ← Core: listar, mover, redimensionar ventanas
├── ShowDesktopManager.swift    ← Lógica de show/hide desktop
├── TilingEngine.swift          ← Cálculos de posiciones (grid, splits, corners)
├── HotkeyManager.swift         ← Registro global de atajos de teclado
├── WindowSwitcher/
│   ├── SwitcherPanel.swift     ← NSWindow panel flotante con vista de colección
│   ├── SwitcherCell.swift      ← Celda con miniatura + icono + título
│   └── SwitcherController.swift ← Lógica de navegación y filtro
├── PermissionsManager.swift    ← Solicitar/verificar Accessibility + Screen Recording
├── Preferences/
│   ├── PreferencesController.swift ← Ventana de preferencias
│   └── ShortcutRecorder.swift    ← Componente para capturar atajos personalizados
├── Models/
│   └── ScreenWindow.swift      ← Modelo de datos para una ventana (pid, title, rect, etc.)
├── Extensions/
│   ├── NSImage+WindowSnapshot.swift ← Capturar miniaturas de ventanas
│   └── AXUIElement+Extensions.swift ← Helpers para AXUIElement
└── Resources/
    └── Assets.xcassets          ← Iconos de menú bar
```

---

## Flujo de datos

### Show Desktop
```
⌘⇧D → HotkeyManager → ShowDesktopManager
                         ├── WindowManager.listAllWindows() → [ScreenWindow]
                         ├── Store current state (posición/orden de cada ventana)
                         ├── AXUIElement.performAction("AXMinimize") en cada una
                         └── Estado: "desktop visible"
⌘⇧D (toggle) → ShowDesktopManager.restoreAll() → AXUIElement.performAction("AXRaise") en cada una
```

### Window Tiling
```
⌘⌥ ← → HotkeyManager → TilingEngine
                         ├── WindowManager.focusedWindow() → ScreenWindow
                         ├── Obtener frame del monitor actual (NSScreen)
                         ├── Calcular nuevo frame según posición:
                         │   ├── Left: 50% ancho, 100% alto
                         │   ├── Right: 50% ancho, 100% alto (offset X)
                         │   ├── Top: 100% ancho, 50% alto
                         │   ├── Bottom: 100% ancho, 50% alto (offset Y)
                         │   ├── TopLeft: 50%×50% esquina
                         │   ├── TopRight, BottomLeft, BottomRight
                         │   ├── Center: centrado 60%×80%
                         │   └── Maximize: fill monitor
                         └── WindowManager.setFrame(frame) → AXUIElementSetAttributeValue
```

### Window Switcher
```
⌘` → HotkeyManager → SwitcherController
                      ├── WindowManager.listAllWindows() → [ScreenWindow]
                      ├── Generar miniaturas (CGWindowListCreateImage)
                      ├── Mostrar SwitcherPanel (overlay, NSPanel level: .floating)
                      ├── Navegación: ← → o Cmd+` para next, Shift+Cmd+` para prev
                      ├── Búsqueda: empezar a teclear → filtrar por título/app
                      └── Enter/click → AXUIElement.setAttribute("AXFocused") + cerrar panel
```

---

## Permisos de macOS

| Permiso | API usada | Cuándo se solicita |
|---------|-----------|-------------------|
| **Accessibility** | `AXIsProcessTrusted()` | En `applicationDidFinishLaunching`, si no está concedido abrimos Prefs de Seguridad |
| **Screen Recording** | `CGWindowListCreateImage` (thumbnails) | Antes de abrir el Switcher por primera vez |

Ambos se verifican en `PermissionsManager` con polling educado: si falta, mostramos alerta con botón "Abrir Preferencias" que ejecuta `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.

---

## Dependencias externas

**CERO dependencias.** Todo es AppKit nativo + APIs de sistema. Sin CocoaPods, SPM ni Carthage.

---

## Estructura del proyecto Xcode

- **Target:** `ScreenOS` (Application, macOS)
- **Minimum deployment:** macOS 14.0 (Sonoma)
- **Bundle identifier:** `com.clot.screenos`
- **LSUIElement:** `true` (app sin ícono en dock, solo menubar)
- **Hardened Runtime:** habilitado

---

## Fases de implementación

### Fase 1 — Esqueleto + Menubar + Permisos
- `AppDelegate` con menubar icon
- `PermissionsManager` que verifica/solicita Accessibility y Screen Recording
- Build & run → icono en menubar que funciona

### Fase 2 — WindowManager + Show Desktop
- `ScreenWindow` model
- `WindowManager` con listado de ventanas y operaciones básicas
- `ShowDesktopManager` con toggle
- Atajo `⌘⇧D` funcional

### Fase 3 — Tiling Engine
- `TilingEngine` con todos los cálculos de posición
- Atajos de tiling (`⌘⌥ ←/→/↑/↓/M/C`)
- Soporte para monitores múltiples

### Fase 4 — Window Switcher
- `SwitcherPanel` overlay con thumbnails
- Navegación por teclado + búsqueda
- Atajo `` ⌘` ``

### Fase 5 — Preferencias + refinamientos
- Ventana de preferencias
- Personalización de atajos
- Mejoras de UX pulidas
- Comportamiento resta solo en menubar

---

## Consideraciones técnicas

- **CGEventTap** para interceptar teclas globales (necesita Accessibility o ejecutar como root). Alternativa: **RegisterEventHotKey** (Carbon) que funciona sin permisos extra.
- Para el **switcher**, las miniaturas se generan con `CGWindowListCreateImage` que necesita Screen Recording permission.
- El **restore** de Show Desktop debe recordar el estado de cada ventana (minimizada vs oculta, posición z-order).
- **Multi-monitor**: el tiling debe detectar en qué pantalla está la ventana actual y usar ese frame.
