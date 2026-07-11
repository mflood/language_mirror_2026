# Language Mirror — Review Panel Proposal

A review panel of persona agents, matching the pattern from `weiji`,
`demons-and-hearts`, and `ios_bagua_burn`: each agent is one voice with a
distinct lens, all read a shared `.claude/review-brief.md` first, critique
**through their own lens**, and answer in a common format
(**Strengths · Findings [Blocker|Major|Minor] with file:line · The one thing ·
Score /10**). Invoke individually, or fan the whole panel out on a build.

## What makes THIS panel different

Language Mirror isn't a game, and it isn't monolingual — that reshapes the roster:

- **"Playtesters" → learner personas**, and there must be **two directions**:
  an English speaker learning Korean *and* a Korean speaker learning English
  (the audience the recent work targets). The apps' whole promise is that it
  works equally well both ways — the panel has to check both.
- **Two native-language lenses.** The one thing I've flagged all along that I
  genuinely can't judge is *naturalness* — Korean gloss register/honorifics,
  English voice quality, MT-stiffness. A **korean-linguist** and an
  **english-linguist** are the highest-value seats on this panel.
- **Pedagogy is the "systems" layer** (the analog to weiji's I-Ching auditor):
  is shadowing + looping + progression-speed + vocab→example→summary
  scaffolding actually sound, or just plausible?
- **Copyright is a live concern** (the verbatim gate, the Dickinson swap, the
  news edition) → a standing **content-copyright-auditor**.
- **ADHD-friendly calm is a stated core value** → accessibility carries extra
  weight, plus an ADHD learner seat.
- **A rich brand system was just built** (plum field, antique-gold ornament,
  parchment bookplate icons, painted Miri, hexagram meter, serif plates) →
  an **art-director** to keep it one authored world.

The panel plugs into the **`/brand-tour` skill** — most craft/persona agents
review its contact sheets and the labeled `NN-*.png` shots, so a tour run feeds
the panel directly.

---

## Proposed roster (13, grouped)

### A. Design & craft — read the brand-tour screenshots
1. **`art-director`** *(opus)* — the Six Wands / Mije-Miri identity: is every
   surface plum-field + antique-gold + parchment, one authored world? Flags
   off-palette fills, stock controls, painted-Miri fidelity (happy/celebrating/
   sleeping), bookplate-icon consistency, the hexagram meter, serif plates.
   Reads brand-tour shots + `brand/miri/` sheets + `AppColors`/`AppFont`.
2. **`staff-ui-engineer`** — UIKit craft: Auto Layout precision, spacing rhythm,
   touch targets (speed chips, transcript taps, medallions), component
   consistency, iPad adaptivity, Dynamic-Type overflow in both appearances.
3. **`accessibility-specialist`** — the ADHD-calm core value first (cognitive
   load, motion restraint during practice, focus), then VoiceOver (hexagram
   meter announces the loop count, transcript gloss, speed controls), Dynamic
   Type, contrast on plum-dusk *and* morning-fog.
4. **`aso-screenshot-reviewer`** — App Store creative for BOTH listings (EN
   store selling KO-learning, KO store selling EN-learning): 3-second test,
   ordering, ≤6-word captions, which frame is the hero.

### B. Learner personas — dogfood the funnel (open → content → practice)
5. **`learner-english-to-korean`** — an English speaker, zero Korean. Is
   onboarding welcoming, content easy to find, the loop self-explanatory, the
   slowed audio reassuring? Honest about confusion and boredom.
6. **`learner-korean-to-english`** — a Korean speaker learning English (the new
   audience). Dogfools the English packs + English news + the Korean glosses;
   doubles as native-Korean eyes on gloss naturalness *in context*. Does the
   app feel made-for-them, not a bolt-on?
7. **`learner-adhd`** — someone with ADHD. Does the app stay calm and hold
   attention or overwhelm? Is the loop a focus aid? Reward feel (streak,
   celebration) motivating or gimmicky? Friction points that lose them.

### C. Content, language & pedagogy — the "systems auditor" analog
8. **`language-pedagogy-reviewer`** *(opus)* — is the method sound? Shadowing,
   looping, M-N-O progression speed, and vocab→easy-example→easy-summary→
   natural-summary scaffolding; TOPIK/CEFR leveling. Does it build fluency or
   just familiarity?
9. **`korean-linguist`** *(opus)* — native-Korean scholar. Judges Korean **audio**
   (pronunciation, prosody, register) and Korean **glosses** (naturalness,
   honorifics, TOPIK level, machine-translation stiffness). The lens I can't
   provide.
10. **`english-linguist`** — native-English mirror. Judges English **audio**
    (ElevenLabs voice naturalness, pacing) and English **content** (CEFR level
    for Korean learners, idiom/phrasal-verb pedagogical value, gloss-worthiness).
11. **`content-copyright-auditor`** — runs `check_verbatim_overlap.py`, audits
    public-domain status of literary content (poems), source-attribution and
    licensing hygiene across packs and feeds, and the news edition's ongoing
    verbatim risk.

### D. Engineering
12. **`staff-swift-engineer`** *(opus)* — architecture: coordinators + AppContainer
    DI, protocol services, the AVPlayer clip-loop engine, the import/catalog/
    remote resolution paths, concurrency (main-actor warnings), robustness,
    testability.
13. **`content-pipeline-reviewer`** — the Python pipelines (daily_news,
    sample_bundle): the studypack/bundler/voicebox seams, edition
    parameterization, S3/CloudFront publish + invalidation hygiene, the QA +
    verbatim gates, cost controls, failure modes (e.g. the ElevenLabs quota
    preflight).

---

## Recommended starting core (6)

If you'd rather not stand up all 13 at once, these cover the highest-value,
hardest-for-me-to-judge, most-LM-distinctive lenses:

**`korean-linguist` · `english-linguist` · `language-pedagogy-reviewer` ·
`art-director` · `accessibility-specialist` · `learner-korean-to-english`**

That's: both native-language quality checks (the real gap), the pedagogy audit,
the brand guardian, the ADHD core value, and the new audience's own eyes.

## Plumbing (built once, shared by all)

- **`.claude/review-brief.md`** — what the app is, the **bidirectional**
  audience, the brand vocabulary, the current state, and the output format.
  I'd seed it from `MEMORY.md`, `brand/miri/`, `CLAUDE.md`, and this session's
  work (English packs, dual news, remote catalog).
- Agents live in **`.claude/agents/*.md`** (same as the other three projects).
- Screenshot-driven agents point at the `/brand-tour` output; code/pipeline
  agents grep the source; linguist/pedagogy agents read the pack content +
  `sample_bundle_pipeline/samples/*/script.json`.

## Status: BUILT (23 agents, 2 briefs)

Built 2026-07-11 in `.claude/agents/` with two shared briefs
(`.claude/review-brief.md` for design/learner/content, `.claude/code-review-brief.md`
for engineering). The proposal's two engineering seats were expanded into a full
**code-review sub-panel** (12 agents) covering codebase + repo health, matching the
bagua-burn split.

Models are explicit per agent, by the established convention:
- **opus (9)** — deep correctness/authenticity/architecture: art-director, both
  linguists, language-pedagogy, content-copyright, code-architect, code-concurrency,
  code-frameworks, code-security.
- **sonnet (10)** — substantive analysis: staff-ui-engineer, accessibility, aso, the
  three learner personas, code-audio, code-persistence, code-testing, code-pipeline.
- **haiku (4)** — mechanical sweeps: code-build, code-robustness, code-style,
  repo-health.

Design/learner/content panel (11): art-director · staff-ui-engineer ·
accessibility-specialist · aso-screenshot-reviewer · learner-english-to-korean ·
learner-korean-to-english · learner-adhd · language-pedagogy-reviewer ·
korean-linguist · english-linguist · content-copyright-auditor.

Code-review sub-panel (12): code-architect · code-concurrency · code-frameworks ·
code-audio · code-persistence · code-security · code-robustness · code-style ·
code-testing · code-build · code-pipeline · repo-health.

Invoke any agent by name via the Agent tool, or fan out a panel on a build. The
screenshot-driven seats read the `/brand-tour` output; linguist/pedagogy/copyright
read the pack content; code seats grep the source.
