# FR-114 — `Craft.Sidebar`: un ítem puede llevar una textura cuadrada en el hueco del icono

**Solicitante:** SMRT (editor de «Auras personalizadas», lista de auras, 2026-10-15).
**Componente:** `Craft/components/Sidebar.lua` (build vendoreado 2.34.0, `CRAFT_BUILD = 36`).
**Estado:** ✅ Cerrado — implementado y verificado in-game (2026-10-18), release v2.35.0. `itemConfig.texture = { image | atlas, crop?, texCoord? }` — mismo vocabulario que Avatar (`crop` en vez de un default fijo: el consumidor pasa `crop = 0.08`). Demo: §5d de `Craft_Browser/pages/Sidebar.lua`.
**Tipo:** Feature (campo nuevo en `itemConfig`, retrocompatible).
**Prioridad:** Baja. **No bloquea:** SMRT usa el `avatar` de FR-095 mientras tanto (abajo).

---

## Problema

La lista de auras de SMRT copia la de WeakAuras: cada fila enseña el icono del aura (el hechizo de su
trigger o el icono manual). Son **iconos de hechizo**, cuadrados por naturaleza, y en WA se ven cuadrados.

Hoy el hueco del icono de un ítem solo admite un lucide (`itemConfig.icon`) o un `Craft.Avatar`
(`itemConfig.avatar`, FR-095), que es **siempre circular** (forma intrínseca del Avatar, ADR-0018). Un icono de
hechizo recortado en círculo pierde las esquinas y no se parece a WA.

## Qué se pide

`itemConfig.texture = { image | atlas, texCoord? }` (o el nombre que encaje mejor): una textura
**cuadrada**, sin máscara, en el mismo hueco de 16 px (`ICON_SIZE`), excluyente con `icon` y `avatar`.

- `image`: ruta o FileDataID (sin `filterMode`, por el crash #132 de FR-062).
- `atlas`: nombre de atlas (validado con `C_Texture.GetAtlasInfo`, como Avatar).
- `texCoord` opcional; por defecto `0.08, 0.92, 0.08, 0.92` sería cómodo para iconos de hechizo, pero basta
  con que se pueda pasar.
- Como el avatar: el color de hover/active **no** la tiñe; `disabled` la baja al 50 %.

En shadcn es un `<img>` dentro de `SidebarMenuButton` en lugar del `<svg>`: misma composición que FR-095,
sin el redondeo del Avatar.

## Taint / 12.1

Nada: el consumidor pasa texturas de datos estáticos (`C_Spell.GetSpellTexture` de un id guardado).
Si algún día llega un valor secreto, `SetTexture` lo acepta como sumidero.

## Apaño actual en SMRT (a retirar al re-vendorear)

`SMRT/modules/Auras/ui/Editor.lua` (`avatarOf`): la fila pasa
`avatar = { image = tex, crop = 0.08 }` (o `{ atlas = … }`) → el icono sale **redondo**. Al llegar este FR,
`avatarOf` devuelve `texture = { … }` en su lugar.
