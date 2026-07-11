# Language Mirror — Review Brief (design · learner · content)

Every design/persona/content agent reads this first, then the artifacts named in
its own file, then critiques **through its own lens**. Judge the CURRENT build,
not effort.

## What the app is

**Language Mirror** (by Six Wands Studios) — an iOS language-learning app built on
**simultaneous shadowing**: import or open real audio, and the app loops short
clips (with a slow→fast progression speed) so you shadow a sentence until it feels
native. Not flashcards, not a chatbot — *ear and mouth* practice on real speech.
UIKit, programmatic Auto Layout, iOS 18.5+. Live on the App Store since ~2026-04.

**It is bidirectional — this is central.** It serves BOTH English speakers learning
Korean AND **Korean speakers learning English**, and is built to work equally well
each way (future: Spanish, Chinese, Thai). Content packs carry the audio in the
*target* language and per-span **translations** keyed by base language code
(`ko`/`en`/…) as the on-screen gloss. A panel that only checks one direction has
done half the job.

**ADHD-friendly calm is a stated core value**, not a nice-to-have: low cognitive
load, restrained motion, a focused practice loop, gentle rewards.

## Audience

- English speakers learning Korean (the original audience).
- **Korean speakers learning English** (the newer audience the recent work targets:
  five English starter packs + a dual daily-news edition).
- Design-sensitive learners who want something beautiful and calm, not gamified/
  hardcore. Benchmarked to out-shine "Speak" on brand, real-audio shadowing, and
  import-anything.

## Brand (the Six Wands / Mije–Miri system)

- **Miri** (미리) — the mascot, a painted antique hand-mirror sprite (aqua→lavender
  moonstone face, gold filigree frame, crimson ribbon), in `brand/miri/`. Three
  expressions: happy (onboarding), celebrating (completion), sleeping (empty states).
  Kin to **Mije**, the pop-surrealist keeper-of-secrets on sixwandsstudios.com.
- **Palette:** plum field (dusk in dark, morning-fog in light), **antique gold**
  ornament (rules, hairline plate borders, medallions), **Mirror Aqua** = "Miri's
  attention"/interactivity, crimson & coral accents, parchment for bookplate icons.
- **Type:** serif "plate" face (New York) for titles/captions; body stays sans for
  Hangul legibility.
- **Signature marks:** engraved bookplate icons (Add screen), the **I Ching
  hexagram loop meter** (Practice), ink-wash cover plates, silk-ribbon pack headers,
  matte paper grain. Motion is drift-and-glow, never Duolingo bounce.
- Everything is defined in `AppColors.swift`, `AppFont.swift`, `Views/*` and the
  `brand/miri/` sheets. The `/brand-tour` skill screenshots every screen.

## Current state (recent work to assess)

- Universal onboarding (the "which language?" question was removed — locale drives
  direction).
- Five **English** starter packs (greetings, directions, cafe, "A Rainy Sunday
  Morning", Dickinson's "Hope is the Thing with Feathers") — remote bundles, live in
  the catalog, with Korean glosses.
- Dual **daily news** rows (Korean + English editions), locale-ordered.
- The whole Six Wands rebrand across every screen.

## How to look

- Screenshots: run the `/brand-tour` skill (or read its latest contact sheets /
  `NN-*.png` shots in the scratchpad). Read the pixels.
- Content: `sample_bundle_pipeline/samples/*/script.json` (bilingual pack scripts),
  the embedded/remote bundles, the news pipeline output.
- Read `MEMORY.md` pointers and `CLAUDE.md` for vocabulary; don't take this brief
  as gospel — flag anything here that's itself wrong.

## Output format (every agent)

Answer in this shape:

- **Verdict** — one line.
- **Strengths** — what genuinely works (be specific, cite the screen/file).
- **Findings** — each marked **[Blocker | Major | Minor]**, with a concrete cite
  (screen filename, or `file:line`) and a concrete, implementable fix. Blockers
  are ship-stoppers.
- **The one thing** — if you could change only one thing, this.
- **Score /10** — your lens's grade for the current build, with a one-line why.

Be candid. A bare "looks good" wastes the seat. Both directions, or say which you
couldn't assess.
