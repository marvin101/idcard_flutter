# PDF renderer parity audit

Baseline: Phase 1 `606b9bb`, Phase 2 `2dada08`. This work changes shared rendering interpretation and PDF output, not Designer interactions.

| Property | Before | Phase 3 behavior / boundary |
| --- | --- | --- |
| Document width/height, orientation | Already used saved dimensions | Preserved; one PDF point conversion, 72/25.4 per mm; no preset or orientation swap |
| Background colour | Forced opaque | Shared RGBA interpretation; explicit PDF opacity |
| Background image | Shared URL resolution, independent painting | Scene selects source; centered cover with page clipping; failed image omitted |
| X/Y, width/height | Same model, independently traversed | Both adapters consume the same visible, ordered scene elements; source geometry is unchanged |
| Rotation | Same positive angle despite opposing Y axes | PDF negates Flutter's angle; both rotate about box center |
| Visibility, stacking | Repeated sorting/filtering | Shared scene filters visibility and orders by z-index |
| Static/student/custom/school/academic text | Shared binding helper invoked independently | Binding helper invoked once per scene element; actual values never change geometry |
| Font family | Flutter platform default vs built-in Helvetica | Bundled Noto Sans in both card adapters; regular and all 100–900 weights; surrounding app UI fonts unchanged |
| Font size | Both used mm | Preserved; shared finite positive size normalization |
| Font weight | PDF collapsed 600–900 to bold | Nine actual static font faces, matching model weights |
| Baseline / vertical position | PDF used its own glyph-box metrics | Flutter TextPainter measures line baselines; PDF draws vector text at those positions |
| Alignment | Independently interpreted | Shared left/center/right mapping and measured per-line offsets |
| Line height / wrapping | Different line-building engines | Flutter determines line breaks and baselines; height 1, zero additional spacing in both |
| Text box limits / clipping | PDF Text overflow behavior differed | Authoritative dimensions and max lines; PDF clips vector content to the saved box |
| Text colour | Alpha discarded | Shared RGBA and explicit PDF text opacity |
| Rectangles / fills | Transparent defaults could paint opaque black | Explicit fill opacity; zero-alpha fills omitted |
| Borders / stroke width | Alpha discarded; zero-width strokes risk PDF hairlines | Shared mm width and colour; explicit stroke opacity; omit zero-width strokes |
| Corner radius | Independently interpreted | Shared radius; rounded image clipping is applied to the outer decorated box |
| Lines | Same basic centered rectangle | Shared colour/width, alpha and corrected rotation |
| Photo / logo sources | Shared URL helper, duplicated selection rules | Scene chooses override/student/school URL once |
| Photo / logo geometry | Saved bounds | Preserved; image interior inset by border width as in Flutter Container |
| Contain / cover / crop | Similar fit, different clipping nesting | Shared fit mode; centered crop, matching outer bounds/background/rounded clip |
| Missing-image fallback | Flutter icons vs PDF PHOTO/LOGO text | Under validation; source failure must not change bounds |
| Latin / accents / punctuation | Helvetica could reject/replace characters | Embedded Unicode font, selectable PDF text and ToUnicode mapping |
| Devanagari | No reliable shaping | Explicitly unsupported: export fails with a descriptive error rather than printing incorrectly shaped student names |
| Other scripts / emoji | Platform fallback vs limited PDF fonts | Not claimed supported; font coverage and complex shaping remain explicit limits |
| Kerning / ligatures | Different engines | Line positions shared; vector PDF glyph advances may still differ subtly from Flutter shaping |
| Bulk output / filtering | One page per supplied card | Preserved; shared images cached for the duration of an export; no filtering changes |

## Architecture

`DesignDocument → DesignBindings + DesignRenderScene → DesignDocumentView / PdfDocumentRenderer`.

The scene owns interpretation only: resolved values, visibility/order, colours, font/style values, image source/fit, and rotation. It references immutable document geometry. It stores no selection, guides, undo history or mutable Canvas state.

`layoutDesignText` uses the same explicit TextStyle as the Flutter card renderer to measure vector PDF line positions in millimetres. It does not rasterize widgets or create page-sized images. PDF drawing stays selectable and scalable.

## Typography boundary

The installed `pdf` 3.13.0 font implementation maps code points to glyphs and has Arabic-specific processing but no general Indic GSUB/GPOS shaper. Noto Sans alone cannot reliably render Devanagari conjuncts and reordered vowel marks. PDF export therefore rejects Devanagari explicitly; the saved design and student data remain intact. Adding such a font without shaping would conceal a data-fidelity defect.

Bundled Noto Sans is licensed under SIL Open Font License 1.1; source and hashes accompany the font files. Fonts load offline and are embedded/subset into each PDF. The family applies only to rendered card text, not the Designer's controls or application chrome.

## Validation plan

Portrait CR80, landscape CR80 and custom-canvas fixtures exercise geometry, translucent backgrounds and shapes, borders/radii, rotated lines, text weights/alignment, accented Latin, long/multiline bindings, photos/logos and image fit. Check normalized values and vector PDF structure, compare first baselines to actual Flutter RenderParagraph, rasterize sample PDFs, and inspect beside Flutter captures. Run existing PDF, Cards parity and Designer regressions plus the full Flutter suite and static analysis.
