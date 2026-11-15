# Rejnox — Coral / Anthracite

Pôvodný futuristický znak Rejnox: svetlé R a koralový diagonálny pruh.

- Značka a hlavné akcie: **Coral #FF6247**.
- Pozadie: **Anthracite #14171B**.
- Karty: **#1A1E23**, okraje **#343B44**.
- Hlavný text: **#F4F5F7**; na koralovom tlačidle **#14171B**.
- Úspech: **#3DDA8D**, iba pre významové stavy.

`rejnox-mark.svg` je hlavný vektor a `rejnox-mark-light.svg` jednofarebný svetlý variant. Oba majú priehľadné pozadie.
`rejnox-mark.png` je priehľadný export; `rejnox-icon.png` má nepriehľadné antracitové pozadie.

Zdroj geometrie: `lib/core/widgets/rejnox_mark.dart`.
Úvod vykreslí obrys a vyplní znak; načítavanie používa pokojný pulz.
Obmedzenie animácií v systéme vypne pulz a vynechá úvod.

Pre vytvorenie všetkých ikon z rovnakej geometrie spusti z koreňa projektu:

```sh
flutter test scripts/brand/export_assets.dart --dart-define=REJNOX_EXPORT_BRAND=true
```

Export pokrýva Android (vrátane adaptívnej ikony), iOS (RGB bez alfa kanála)
a ikony Flutter PWA. Samostatného projektu `webapp/` sa netýka.
