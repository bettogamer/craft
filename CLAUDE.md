# Craft — Claude Code

> Leer **`AGENTS.md`** — es la fuente de verdad única para reglas, arquitectura,
> contrato de componente, tokens, guardrails y flujo de trabajo.

Las instrucciones de `AGENTS.md` aplican íntegramente a Claude Code.

## Comandos rápidos

```bash
luacheck Craft/ --config .luacheckrc   # lint
busted tests/                           # tests
bash scripts/bump-build.sh              # bump CRAFT_BUILD antes de release
```

```
/check-traceability      # gaps en BRD→MRD→PRD→FSD
/update-design-tokens    # actualizar tokens desde CSS shadcn + revisar layouts
```
