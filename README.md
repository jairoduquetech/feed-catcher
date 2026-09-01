# 🎣 Feed Catcher

> **Lector RSS nativo, moderno y ultra-rápido para macOS inspirado en Reeder.**

Feed Catcher es una aplicación nativa para macOS construida con **Swift**, **SwiftUI** y **SwiftData**. Diseñada para ofrecer una experiencia de lectura limpia, fluida a 120 FPS y altamente personalizable.

---

## ✨ Características

- ⚡️ **Ultra-rápido (120 FPS):** Sistema de caché inteligente en memoria RAM y disco (`ImageCacheService`) con *downsampling* automático para un scroll completamente fluido.
- 🎨 **Diseño inspirado en Reeder:**
  - Lista de noticias con favicon de la fuente, titular, resumen y miniaturas cuadradas a la derecha.
  - Vista de lectura con tipografía cuidada, citas doradas, imágenes centradas y soporte para incrustaciones.
- 🌓 **Soporte de Modo Claro / Oscuro:** Se adapta automáticamente a la apariencia del sistema o permite elegir modo claro u oscuro permanente.
- 📥 **Importación y Exportación OPML:** Compatible con Reeder 4, Feedly, NetNewsWire y cualquier lector RSS estándar.
- 🔄 **Actualización en segundo plano:** Sincronización automática periódica en segundo plano.
- ⚙️ **Panel de Ajustes (`⌘,`):**
  - Personalización de fuentes (Sans-Serif, Serif Georgia, Redondeada, Monoespaciada).
  - Control de tamaño de texto con vista previa en vivo.
  - Opciones de interfaz: activar/desactivar miniaturas, favicons, resúmenes y modo de filas compactas.
  - Gestor de caché para vaciar espacio en disco.
- 🌐 **Soporte completo HTTP / HTTPS:** Configuración de App Transport Security (ATS) para leer feeds y medios sin bloqueos.

---

## 🛠️ Requisitos

- macOS 14.0 (Sonoma) o superior
- Xcode 15.0+ / 16.0+ (para compilar desde código fuente)
- Apple Silicon (M1/M2/M3/M4) o procesador Intel

---

## 🚀 Instalación y Compilación

### Opción 1: Abrir con Xcode
1. Clona el repositorio:
   ```bash
   git clone https://github.com/TU_USUARIO/feed-catcher.git
   cd feed-catcher
   ```
2. Abre el proyecto en Xcode:
   ```bash
   open REEDER.xcodeproj
   ```
3. Presiona `Cmd + R` para compilar y ejecutar la aplicación.

### Opción 2: Compilación por Terminal
```bash
xcodebuild -project "REEDER.xcodeproj" \
  -scheme REEDER \
  -configuration Release build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

---

## 🏗️ Arquitectura del Proyecto

- **`Models/`**: Modelos de datos `@Model` en SwiftData (`Feed.swift`, `Article.swift`).
- **`Services/`**:
  - `RSSService.swift`: Parser SAX nativo (`XMLParser`) para RSS 2.0, Atom 1.0 y Media RSS.
  - `OPMLService.swift`: Parser y generador de archivos de suscripciones OPML.
  - `FeedRefreshService.swift`: Actor en segundo plano para sincronización programada.
  - `ImageCacheService.swift`: Caché multinivel en RAM y disco con *downsampling*.
- **`Features/`**:
  - `Sidebar/`: Lista de feeds, vistas inteligentes y contador de no leídos.
  - `Timeline/`: Línea de tiempo de noticias con filtros y búsqueda.
  - `ArticleDetail/`: Vista de lectura y visor web con inyección CSS.
- **`Shared/`**:
  - `SettingsView.swift`: Ventana de preferencias (`⌘,`).
  - `AddFeedView.swift`: Modal para añadir feeds y sugerencias.

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT.
