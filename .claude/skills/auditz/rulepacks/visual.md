# Pack: visual — screenshot audit (input = rendered variants of one screen)

Filename convention: `screen__WxH_light|dark_ts1.0|1.3.png`. Compare variants of the same screen against each other.

### rule_id: overflow_or_clipping
requires: core
Yellow/black overflow stripes, clipped text, truncated buttons, content cut at screen edges — especially in the small-width and ts1.3 variants.

### rule_id: textscale_break
requires: core
Layout that holds at ts1.0 but breaks at ts1.3: overlapping labels, buttons pushed off-screen, rows wrapping badly, fixed-height containers squeezing text.

### rule_id: contrast_low
requires: core
Text or icons with visibly insufficient contrast against their background (aim WCAG AA ~4.5:1 for body text). Check the dark variant separately — greys that work on white often die on dark.

### rule_id: dark_theme_artifact
requires: core
Dark variant showing pure-inversion bugs: hardcoded white cards on dark background, invisible dividers, shadows that turned into smudges, images with white matte edges.

### rule_id: hierarchy_unclear
requires: core
No clear primary action or reading order: multiple equally-weighted buttons, headings indistinguishable from body, the screen's main purpose not visually dominant.

### rule_id: cramped_or_uneven_spacing
requires: core
Elements touching, inconsistent gutters/margins between similar elements, unbalanced padding (tight top, huge bottom), misaligned edges across rows/cards.

### rule_id: touch_target_visual
requires: core
Interactive elements that look smaller than ~44-48dp on the small-device variant, or crowded so close that mistaps are likely.

### rule_id: truncation_of_critical_info
requires: core
Ellipsis eating information the user actually needs (amounts, names, dates) with no way to see the full value.

### rule_id: inconsistent_components
requires: core
The same concept styled differently across variants/screens shown: mismatched button styles, two card radii, inconsistent icon sets or caption styles.

### rule_id: empty_or_broken_render
requires: core
A variant rendering blank/partially blank, placeholder boxes, missing images, or an obviously broken frame compared to sibling variants.
