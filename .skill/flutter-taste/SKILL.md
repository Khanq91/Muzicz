---
name: flutter-taste
description: Design taste, layout thinking, and clean-architecture rules for Flutter/Android UI so agent-generated screens stop looking like default `flutter create` output or generic Material boilerplate. Trigger this for any request to build, redesign, restyle, or review a Flutter screen, widget, theme, or app structure. If the brief mentions Liquid Glass, frosted glass, translucent, glassmorphism, or "iOS 26 style," or `liquid_glass_widgets` already sits in pubspec.yaml, also read references/liquid-glass.md before writing any code.
---

# Flutter Taste

Same anti-slop idea behind taste-skill and impeccable (both web-focused: CSS, Tailwind, GSAP), rebuilt from the ground up for Flutter widget code. Framework fluency was never the gap: a model already knows every Material 3 widget. The gap is defaulting to the first recipe that compiles instead of the one the brief actually calls for. Read this before generating or editing UI code.

## 1. Read the brief before touching a widget

State one line before writing code: `Reading this as: <screen kind> for <audience>, <platform scope>, leaning <visual direction>.`

Work out:

- **Screen kind**: list/browse, detail/read, form/input, dashboard/overview, media/immersive, onboarding, settings. Each wants a different default composition, not the same `AppBar + ListView + FAB` skeleton stamped on every route.
- **Platform scope**: phone only, or adaptive across phone/foldable/tablet? Android has real width variance (a Pixel Fold, a tablet in split screen); don't assume one hand, one width.
- **Existing design system**: does the project already have a `ThemeExtension`, a tokens file, a `theme/` folder? If yes, extend it. Don't start a second, competing set of colors and spacing next to it.
- **Vibe words the user actually used**: "playful," "clinical," "premium," "brutalist," "Apple-y," "dense dashboard." The brief decides the aesthetic. A default preference for rounded cards and soft shadows is not a design decision, it's a habit.

## 2. Dials

Hold these as running defaults for the session. Move them the moment the user's words imply a different value; don't ask them to go edit this file.

| Dial | Range | Baseline | Meaning |
|---|---|---|---|
| `LAYOUT_VARIANCE` | 1-10 | 5 | 1 = safest stock Material recipe. 10 = custom composition, asymmetry, non-grid layout. |
| `MOTION_INTENSITY` | 1-10 | 5 | 1 = static, snaps between states. 10 = physics-driven, hero transitions everywhere. |
| `DENSITY` | 1-10 | 4 | 1 = airy, generous whitespace. 10 = dashboard-packed, small type, tight rows. |
| `GLASS_INTENSITY` | 0-10 | 0 | 0 = pure Material 3, no translucency. Raise it only when the brief asks for glass/frosted/Apple-style, or the project already has it. Never raise this on your own initiative. |

A finance app's transaction list and a music player's now-playing screen should not read off the same dial values. Reset them per screen if the brief's character changes mid-project.

## 3. Anti-slop checklist

These are the tells that make a screen instantly recognizable as "generated from a one-line prompt." Each one is fine in isolation; the problem is reaching for all of them by default because they're the first thing that compiles.

- **Seed color**: `ColorScheme.fromSeed(seedColor: Colors.deepPurple)` is the `flutter create` template default. Pick a seed, or a full custom `ColorScheme`, from the brand or brief. Never leave it at deep purple unless purple is actually the brand.
- **Button hierarchy**: not every action is an `ElevatedButton`. One primary action per screen (`FilledButton`), secondary as `OutlinedButton` or `FilledButton.tonal`, tertiary as `TextButton`. If everything is emphasized, nothing is.
- **Card soup**: not every container is a `Card`. Reserve elevation/tonal surfaces for things that are genuinely separate, liftable objects. A plain grouping doesn't need a card shell around it.
- **ListTile for everything**: a settings row, a chat bubble, and a product tile are not the same shape. Reach for `ListTile` when the content really is icon + title + subtitle + trailing. Build a real custom layout when it isn't.
- **Happy-path-only screens**: design the empty state, the loading state, and the error state as deliberately as the loaded state. A screen that only renders correctly when the API returns a full list isn't finished.
- **Magic numbers**: no bare `EdgeInsets.all(16)` or `SizedBox(height: 12)` sprinkled by feel. Pull from the spacing scale in Section 4 so rhythm stays consistent across screens.
- **Hardcoded color literals**: no `Colors.grey`, `Colors.black54`, `Color(0xFF...)` inline in widget code outside the theme file. Route everything through `Theme.of(context).colorScheme` or a semantic token, or dark mode quietly breaks.
- **One radius for everything**: Material 3's shape system has small/medium/large/extra-large roles for a reason. A chip, a card, and a bottom sheet sharing one border radius out of laziness is a tell.
- **Icon-plus-text as the only section header pattern**: fine occasionally, wrong as the default for every section on every screen.
- **No motion, or the same fade on everything**: either the screen snaps between every state with zero transition, or literally every change gets the same generic `FadeTransition` regardless of what happened. Match motion to the dial in Section 2 and the actual interaction in Section 5.
- **File and widget proliferation**: `home.dart`, `home2.dart`, `home_final.dart`, `test_page.dart` sitting next to each other is a sign the agent forked instead of editing. See Section 6.
- **1000-line `build()` methods**: extract into named widgets. A screen that doesn't decompose is unreadable for the next person, or the next agent, that touches it.
- **Missing `const`**: every subtree that doesn't depend on runtime state should be `const`. Both a perf point and a taste point: non-const widgets in a static tree read as unfinished.

## 4. Tokens, not literals

Before generating screens, find the project's existing tokens or propose a small set. Don't invent a new one per screen.

- **Spacing scale**: a small fixed set (e.g. 4/8/12/16/24/32/48) referenced by name or constant, never typed as raw numbers at the call site.
- **Type scale**: drive text from `Theme.of(context).textTheme`, customized once in the app's `ThemeData`, not `TextStyle(fontSize: 22, fontWeight: FontWeight.w600)` typed inline on every headline.
- **Radius scale**: 2-4 radii tied to component role (chip/button small, card medium, sheet/dialog large), reused rather than invented per widget.
- **Motion tokens**: a couple of named durations/curves (roughly: fast ~150ms `easeOut` for micro-interactions, medium ~300ms `easeInOutCubic` for page-level transitions) instead of a different duration typed at every `AnimatedContainer`.
- **Color via `ColorScheme` + a semantic extension**: base Material roles (`primary`, `surface`, `error`...) plus a small `ThemeExtension` for anything domain-specific (an `income`/`expense` pair for a finance app, say), so light/dark and dynamic color stay correct automatically instead of breaking per screen.

## 5. Layout and motion, thought through rather than defaulted

- Match structure to the screen kind from Section 1. A five-row settings screen doesn't need `CustomScrollView` + `SliverAppBar`; a media browse screen with a collapsing hero image might. Reach for Slivers when there's an actual scroll-linked effect to earn, not as a default "more sophisticated" scaffold.
- Use implicit animations (`AnimatedContainer`, `AnimatedSwitcher`, `AnimatedOpacity`) for state changes within a screen, and `Hero` for the one or two transitions per flow that genuinely benefit from shared-element continuity (list thumbnail to detail image, say). Not every navigation needs a custom transition.
- Loading states: prefer a skeleton/shimmer shaped like the real content over a centered `CircularProgressIndicator` for anything list-shaped. A spinner is fine for a short, whole-screen wait.
- Handle `SafeArea` / `MediaQuery.of(context).padding` explicitly rather than letting content collide with the status bar or the gesture nav area, especially since edge-to-edge is now the Android default and the app draws behind system bars unless told otherwise.

## 6. Architecture guardrails

Default to this shape unless the project already dictates otherwise:

```
lib/
  core/           # theme, tokens, routing, shared utils, DI setup
  features/
    <feature>/
      data/       # repositories, DTOs, remote/local sources
      domain/     # models, use cases (if the project separates these)
      presentation/
        screens/
        widgets/
        providers/  # or controllers, per state-management choice
  widgets/        # cross-feature shared widgets
```

- Default state management: Riverpod. Default routing: `go_router`. Both are swappable if the project already uses something else, but don't introduce a second state-management approach alongside an existing one.
- One screen, one file, named for what it is (`transaction_list_screen.dart`, not `page2.dart`). If a near-duplicate screen feels tempting, parameterize the existing widget instead of forking a new file.
- No hardcoded padding or color literals outside `core/theme` (this enforces Section 4 at the architecture level, not just the style level).
- `const` constructors wherever the widget doesn't depend on runtime values.

## 7. Small native details that separate a real app from a wrapped webpage

- Haptic feedback (`HapticFeedback.lightImpact()` / `selectionClick()`) on primary confirm actions and drag-reorder, not on every tap.
- Treat Material You dynamic color (`dynamic_color` package, Android 12+) as an option to raise with the user, not a silent default. It reshapes the app's whole palette per device wallpaper, which some products want and some explicitly don't.
- Predictive back gesture and edge-to-edge are Android platform defaults now. Design for content sitting behind system bars intentionally rather than fighting it with hardcoded padding.

## 8. Liquid Glass

If the brief mentions Liquid Glass, frosted glass, translucent, glassmorphism, or "iOS 26 style," or the project already depends on `liquid_glass_widgets`, stop here and read `./LIQUID_GLASS_UI_PLAN-package_liquid_glass_widgets.md` in full before writing a single widget. Don't hand-roll a `BackdropFilter` clone as a shortcut; that file explains why, and gives the real pattern.

If glass wasn't asked for, leave `GLASS_INTENSITY` at 0 and don't introduce it, even if the last project the user built did use it.

## 9. Before you hand back code

Check this against what you're about to output:

- Does the seed color, button hierarchy, and radius set trace back to the brief, not the framework default?
- Does every screen have a real empty/loading/error state, not just the happy path?
- Is every spacing/color/radius value coming from a token, not typed by feel?
- Would this screen survive being opened next to four other screens in the same app and look like it belongs to the same product?
- If glass was requested: did you actually read `./LIQUID_GLASS_UI_PLAN-package_liquid_glass_widgets.md`, or just reach for `BackdropFilter` and call it done?