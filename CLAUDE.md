# CLAUDE.md — ScreenOS

> Gestor de ventanas para macOS — nativo, ligero, cero dependencias.
> Corre en la barra de menús. Escrito en Swift + AppKit.

---

## Proyecto

**Nombre:** ScreenOS
**Tipo:** App nativa macOS (Swift + AppKit, menu bar only, sin dock icon)
**Descripción:** Gestor de ventanas con Show Desktop, Tiling, y Window Switcher.
**Repo:** No publicado (local en ~/Projects/ScreenOS)
**Owner:** @clot
**Estado:** Funcional, en desarrollo activo.

---

## Tech Stack

| Capa | Tecnología |
|------|------------|
| Lenguaje | Swift 5.9+ |
| UI Framework | AppKit (menu bar app, LSUIElement=true no usado — usa accessory policy) |
| Window API | AXUIElement (Accessibility API) para mover/redimensionar/minimizar |
| Thumbnails | CGWindowListCreateImage (Screen Recording permission) |
| Hotkeys | Carbon RegisterEventHotKey API (sin Accessibility para interceptar teclas) |
| Build | SwiftPM (`swift build -c release`) + `build.sh` que genera .app bundle |
| Firmado | Ad-hoc signature (`codesign --force --deep --sign -`) |

**CERO dependencias externas.** Todo es AppKit nativo + Carbon APIs.

---

## Archivos Clave

```
~/Projects/ScreenOS/
├── Sources/ScreenOS/
│   ├── main.swift                 ← Entry point. NSApplication + AppDelegate inline
│   ├── HotkeyManager.swift        ← Carbon hotkey registration (sin permisos extra)
│   ├── WindowManager.swift        ← CGWindowList API + AXUIElement wrappers
│   ├── ShowDesktopManager.swift   ← Toggle hide/unhide de todas las apps
│   ├── TilingEngine.swift         ← Cálculos de posiciones tiling
│   ├── PermissionsManager.swift   ← Verificar/solicitar Accessibility + Screen Recording
│   ├── Models/
│   │   └── ScreenWindow.swift     ← Modelo de ventana (id, pid, title, frame, axElement)
│   ├── WindowSwitcher/
│   │   ├── SwitcherPanel.swift    ← NSPanel flotante overlay
│   │   ├── SwitcherCell.swift     ← Celda con miniatura + icono + título
│   │   └── SwitcherController.swift ← Navegación + filtrado por búsqueda
│   └── Preferences/
│       ├── PreferencesViewController.swift ← UI de preferencias
│       └── ShortcutRecorder.swift    ← Captura de atajos personalizados
├── Resources/
│   ├── AppIcon.png / AppIcon@2x.png  ← Iconos menú bar
│   ├── Info.plist                    ← Bundle config
│   └── ScreenOS.entitlements         ← Entitlements (com.apple.security.app-sandbox)
├── Package.swift
├── build.sh                          ← Genera .app bundle firmable
├── README.md                          ← Documentación usuario
└── PLAN.md                            ← Arquitectura y fases de implementación
```

---

## Funcionalidades Implementadas

| Feature | Atajo | Estado |
|---------|-------|--------|
| Show Desktop toggle | ⌘⇧D | ✅ Funcionando |
| Tiling Left | ⌘⌥← | ✅ Funcionando |
| Tiling Right | ⌘⌥→ | ✅ Funcionando |
| Tiling Top | ⌘⌥↑ | ✅ Funcionando |
| Tiling Bottom | ⌘⌥↓ | ✅ Funcionando |
| Maximize | ⌘⌥M | ✅ Funcionando |
| Center | ⌘⌥C | ✅ Funcionando |
| Window Switcher | ⌘` | ⚠️ Panel existe, hotkey no conectado |
| Preferences | — | ⚠️ ViewController existe, no conectado al menú |

---

## Flujo de Ejecución

```
main.swift
  → NSApplication.shared
  → AppDelegate (NSObject, NSApplicationDelegate)
       → setupMenuBar() — icono + menú con todas las acciones
       → requestAccessibilityPermission() — alerta inicial
       → HotkeyManager.shared.registerDefaults() — registra Carbon hotkeys
            → Cada hotkey绑定 a método del AppDelegate
                 → toggleShowDesktop() / applyTiling(position:) / etc.
```

---

## Permisos Requeridos

| Permiso | Para qué | Cuándo se pide |
|---------|----------|---------------|
| **Accessibility** | Mover/redimensionar/minimizar ventanas (AXUIElement) | En launch si no está concedido |
| **Screen Recording** | Capturar miniaturas para el Switcher | Antes de abrir el Switcher |

Ambos: Preferencias del Sistema → Privacidad y Seguridad → Accessibility / Screen Recording.

---

## Build y Run

```bash
# Compilar
./build.sh

# Abrir el .app
open .build/release/ScreenOS.app

# Primera vez: botón derecho → Abrir (bypass Gatekeeper)
# Luego concede permisos en Preferencias del Sistema
```

**Problemas comunes:**
- "Accessibility permission required" → Settings → Privacy → Accessibility → añadir ScreenOS
- Hotkey no responde → Accessibility no concedido (Carbon funciona sin permisos, pero AX para mover ventanas necesita Accessibility)
- El .app no se abre → ejecutar con `open -b ScreenOS` o desde Finder con "Abrir"

---

## Architecture Notes

### Por qué Carbon para hotkeys
RegisterEventHotKey (Carbon) funciona SIN Accessibility permission. El problema es que solo intercepta teclas, no puede escuchar keyUp. Para el Window Switcher (Cmd+`) esto es suficiente.

### Por qué no LSUIElement
El proyecto usa `NSApp.setActivationPolicy(.accessory)` en lugar de `LSUIElement=true` en Info.plist. Ambos ocultan el dock icon, pero accessory policy permite cambiar a `.regular` si en el futuro se quiere una ventana principal.

### main.swift contiene AppDelegate
El proyecto no usa `AppDelegate.swift` separado — todo el setup está en `main.swift`. Esto es poco convencional pero funcional.

### ScreenRecording para thumbnails
`CGWindowListCreateImage` necesita Screen Recording permission. El SwitcherPanel genera miniaturas bajo demanda con polling para detectar nuevas ventanas.

---

## Workflow

### Para tareas simples
Sé directo: "Añade tile top-left con ⌘⌥Home" — no necesitas explicar contexto.

### Para tareas complejas (>3 pasos)
1. Agent propone plan primero
2. Usuario confirma
3. Agent ejecuta
4. Agent verifica

### Para cada tarea
1. **Plan** → Si son >3 pasos, escribir en `tasks/todo.md`
2. **Verify** → Confirmar antes de cambios grandes
3. **Execute** → Cambio más pequeño posible
4. **Document** → Actualizar si es necesario

---

## Code Quality

### SIEMPRE
- Código legible y mantenible
- DRY — no duplicar lógica
- Probar cambios compilando con `swift build -c release` antes de declarar OK
- Mantener cero dependencias externas

### NUNCA
- Hardcodear paths — usar `~/Projects/ScreenOS` con expansión
- Commits sin mensaje descriptivo
- Usar dependencias externas (CocoaPods, SPM, Carthage) — objetivo es cero deps

---

## Debugging

**Build falla:**
```bash
swift build -c release 2>&1
```

**El .app no se genera:**
```bash
ls -la .build/release/
./build.sh
```

**Hotkey no funciona:**
1. Verificar Accessibility en System Settings
2. Ver que el .app esté abierto (menu bar icon visible)
3. Probar desde otra app (el hotkey debe funcionar globalmente)

**Tiling no mueve la ventana:**
- Verificar que AXIsProcessTrusted() returns true
- Añadir ScreenOS a Accessibility en Settings

---

## Recursos

**Vault Saraiba (contexto personal):**
- `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Saraiba/`
- Skills en: `~/.hermes/skills/`

**Repos relacionados:**
- SyncSalud: `/Users/clot/Projects/SyncSalud/`
- workouts-dashboard: `/Users/clot/Projects/workouts-dashboard/`

---

## Contacto

**clot** — owner del proyecto
**Issues:** Preguntar directamente o en Telegram

---

*Último actualizado: 2026-06-08*
*Versión: Funcional (hotkeys funcionando, tiling OK, switcher en progreso)*
