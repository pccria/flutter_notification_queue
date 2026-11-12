# NFQ Studio

An interactive workbench and design tool for **FlutterNotificationQueue** (`FNQ`).

NFQ Studio allows developers and UI designers to configure spatial queues, design notification channels, explore gestures, test priority eviction rules, and preview real-time notification dynamics across desktop, tablet, and mobile layouts.

---

## 🌟 Key Features

### 1. Live In-Place Draft Card Preview (`LiveCardPreview`)
* **3-Gear Cascading Theme Resolution**: Resolves queue archetype (`Filled`, `Outlined`, `Flat`), channel theme, and notification overrides in real-time.
* **Glassmorphic Transparency**: An optical checkerboard backdrop reveals real-time container opacity and backdrop filters.
* **Presentational Sandbox**: Pure presentational rendering with zero countdown timers, dismiss timers, or queue side effects.
* **Instant Dispatch**: Fire drafts directly into the live stage with one click or via `Ctrl + Enter` (`⌘ + Enter` on macOS).

### 2. 3×3 Spatial Stage Radar (`LiveStageRadar`)
* **Real-Time Stage Telemetry**: Subscribes to `QueueCoordinator.events` and `activeQueues` to reflect live status across all 8 spatial anchors (`topLeft` through `bottomRight`).
* **Active & Pending Badges**: Green badges for active cards on screen; amber badges for pending items waiting in backlog.
* **Permanent Relocation Detection**: Visual amber arrow indicators reveal when a queue has been permanently relocated to another anchor.
* **Stage Quick Actions**: Instantly clear stage items using `"DISMISS NEWEST"` or `"DISMISS ALL"`.

### 3. Configurator & Code Generation
* **Channel & Queue Editor**: Customize archetypes, border radii, elevations, glassmorphic opacities, safe-area margins, and gesture interactions.
* **Modern Egress Controls**: Live selection of `DismissEgressOption` (`Horizontal`, `Natural`, `Outward`, `Cross`, `Any`), dynamic card tilt (`Enable Tilt`), and in-slot reveal backdrop (`Show Underlay`).
* **Payload Builder**: Adjust titles, messages, priority tiers (`low`, `normal`, `high`, `critical`), permanent flags, dismiss timers, accent tints, and action buttons.
* **Production Code Generator**: Emits clean, copy-pasteable Dart code matching your current live setup, complete with modern `DismissEgress` configurations.

### 4. Global Keyboard Shortcuts
The Studio responds globally to hardware keyboard shortcuts—even when text input fields are focused:

| Shortcut | macOS | Action |
|:---|:---|:---|
| **`Ctrl + Enter`** | `⌘ + Enter` | Fire current notification draft |
| **`Ctrl + E`** | `⌘ + E` | Reset draft to default values |
| **`Ctrl + L`** | `⌘ + L` | Load a random notification draft scenario |

---

## 🚀 Running the Studio Locally

You can run NFQ Studio across any supported Flutter platform:

### Web (Chrome)
```bash
flutter run -d chrome
```

### Linux Desktop
```bash
flutter run -d linux
```

### macOS Desktop
```bash
flutter run -d macos
```

### Windows Desktop
```bash
flutter run -d windows
```

### Scripts
A convenience script is provided in `example/scripts/run.sh`:
```bash
./scripts/run.sh linux
```
