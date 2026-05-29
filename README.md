# ScreenOS

Gestor de ventanas para macOS — nativo, ligero, sin dependencias.

## Features

- **Show Desktop** (`⌘⇧D`) — minimiza todas las ventanas, muéstralas de vuelta
- **Window Tiling** (`⌘⌥ ←/→/↑/↓`) — coloca ventanas en posiciones predefinidas
- **Centrar / Maximizar** (`⌘⌥ C` / `⌘⌥ M`)
- **Window Switcher** (`` ⌘` ``) — overlay con miniaturas y búsqueda
- **Menú en barra de menús** — acceso a todas las acciones
- **Preferencias** — personalización de atajos

## Requisitos

- macOS 14.0 (Sonoma) o superior
- Swift 5.9+ (incluido con Xcode 15+)

## Compilar

```bash
./build.sh
```

O manualmente:

```bash
swift build -c release
./build.sh   # para crear el .app
```

## Instalación

1. Compila con `./build.sh`
2. Arrastra `ScreenOS.app` a la carpeta de Aplicaciones
3. Ábrelo (primera vez: botón derecho → Abrir)
4. Concede permisos de **Accesibilidad** cuando se solicite
5. Para el Switcher de ventanas, concede también **Grabación de Pantalla**

## Permisos

ScreenOS necesita dos permisos de macOS:

| Permiso | Para qué |
|---------|----------|
| Accesibilidad | Mover/redimensionar/minimizar ventanas |
| Grabación de Pantalla | Capturar miniaturas en el Switcher |

Ambos se configuran en: **Preferencias del Sistema → Privacidad y Seguridad**

## Estructura del proyecto

```
ScreenOS/
├── Sources/ScreenOS/
│   ├── AppDelegate.swift          ← Entry point
│   ├── WindowManager.swift        ← Core window operations (AXUIElement)
│   ├── ShowDesktopManager.swift   ← Show Desktop toggle
│   ├── TilingEngine.swift         ← Tiling position calculations
│   ├── HotkeyManager.swift        ← Global hotkeys via Carbon API
│   ├── PermissionsManager.swift   ← Privacy permission handling
│   ├── Models/
│   │   └── ScreenWindow.swift     ← Window data model
│   ├── WindowSwitcher/
│   │   ├── SwitcherPanel.swift    ← Overlay panel with collection view
│   │   ├── SwitcherCell.swift     ← Thumbnail cell
│   │   └── SwitcherController.swift ← Navigation & filtering logic
│   └── Preferences/
│       ├── PreferencesViewController.swift ← Preferences UI
│       └── ShortcutRecorder.swift ← Shortcut capture control
├── Resources/
│   └── Info.plist
├── Package.swift
├── build.sh
└── README.md
```

## Atajos por defecto

| Acción | Atajo |
|--------|-------|
| Show Desktop | `⌘⇧D` |
| Tile Left | `⌘⌥ ←` |
| Tile Right | `⌘⌥ →` |
| Tile Top | `⌘⌥ ↑` |
| Tile Bottom | `⌘⌥ ↓` |
| Maximize | `⌘⌥ M` |
| Center | `⌘⌥ C` |
| Window Switcher | `` ⌘` `` |

## Licencia

MIT
