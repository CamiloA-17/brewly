# Brewly

App iOS para baristas: gestiona tus granos e inventario, crea recetas con temporizador guiado, lleva una bitácora de cada taza y compártelas con una comunidad de café (seguidores, "me gusta", comentarios y copias de recetas). Todo lo personal es privado por defecto.

| Capa | Tecnología | Carpeta |
|---|---|---|
| Base de datos | PostgreSQL (Supabase) con RLS, triggers y funciones RPC | [`supabase/migrations`](supabase/migrations) |
| Backend | Supabase Auth, PostgREST, Storage, Realtime y Edge Functions | [`supabase`](supabase) |
| Frontend | SwiftUI (iOS 17+), Swift Package modular | [`ios`](ios) |

La arquitectura completa (modelo de datos, privacidad, API, módulos del cliente y cómo escala) está en **[docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)**.

## Inicio rápido

```bash
# 1. Probar el esquema SQL contra un PostgreSQL local
supabase/tests/run.sh

# 2. Levantar Supabase localmente (requiere Docker + Supabase CLI)
supabase start && supabase db reset

# 3. Configurar y generar el proyecto de Xcode
cp ios/Brewly/Config/Secrets.example.xcconfig ios/Brewly/Config/Secrets.xcconfig   # completar valores
brew install xcodegen && (cd ios && xcodegen generate) && open ios/Brewly.xcodeproj
```

Sin `Secrets.xcconfig` la app arranca con un backend en memoria para explorar la interfaz.
