# Suno Song Generation — Skill Guide

This folder holds **Suno song specs** used to generate promo/marketing songs for
**SocialGraph** (by Codelio). Each file is a self-contained brief you can paste
straight into [Suno](https://suno.com) to generate a track.

This README is written as a **skill for Claude**: follow it to produce another
song file that matches the house format.

---

## What's in this folder

| File | Vibe | Tagline / hook |
| --- | --- | --- |
| [socialgraph_anthem.md](socialgraph_anthem.md) | Bright indie electro-pop anthem | "Who's in your orbit?" |
| [socialgraph_funk_rap.md](socialgraph_funk_rap.md) | Funk-hop / nu-disco, cheeky rap | "Keep in touch, don't ghost me" |

---

## The two Suno workflows (every file supports both)

1. **Custom mode** — you provide the lyrics and the style separately.
   Paste the **Style** block into *Style of Music*, the **Title**, and the
   **Lyrics** block into *Lyrics*.
2. **Simple mode** — Suno writes the lyrics for you.
   Paste the one-paragraph **Song Description** into the *Song Description* box.

So every song file must contain **both**: a prose description (for Simple mode)
*and* explicit style + lyrics (for Custom mode).

---

## File template (copy this structure)

````markdown
# SocialGraph — Suno Song <#/name>

<1–2 sentence summary of the vibe and who it's for.>

Paste the **Style** into Suno's *Style of Music* box and the **Lyrics** into the
*Lyrics* box. Title suggestion: **"<Title>"**.

---

## Song Description (Simple mode — let Suno write the lyrics)

Use this when you want Suno to generate the lyrics itself. Switch Suno to
**Simple** mode and paste this whole paragraph into the *Song Description* box.

```
<One dense paragraph: genre + tempo, instrumentation, vocal style, the
narrative arc (what HAPPENS in the song), the app features woven in, and the
tagline hook. Plain prose, no line breaks needed.>
```

---

## Style (paste into "Style of Music")

```
<Comma-separated style tags: genre, BPM, key instruments, drum feel, mood,
vocal type, "radio-ready / feel-good". Keep it under ~200 characters.>
```

## Title

```
<Catchy title>
```

---

## Lyrics (paste into "Lyrics")

```
[Intro]
...
[Verse 1]
...
[Pre-Chorus]
...
[Chorus]
...
[Verse 2]
...
[Bridge]
...
[Final Chorus]
...
[Outro]
...
```

---

## Notes

- Style siblings to try: <2–4 alternate genres>.
- Short ad cut (~30s): <which sections>.
- Feature callouts woven in: <list>.
````

---

## How to write a good one (recipe for Claude)

1. **Know the product.** SocialGraph turns a messy contact list into a living
   **graph** of relationships. Real features to weave into lyrics (pick a few,
   don't list all mechanically):
   - the glowing social **graph** view (friends as nodes/stars/constellations)
   - **search** + one-tap **call / text / email**
   - **duplicate** detection & **merge**
   - **stay-in-touch reminders** + **birthday** alerts ("reach out before you drift")
   - **streaks**, achievement **badges**, and **stats** (gamification)
   - **cloud sync & backup** (never lose your people)
   - **relationship strength** (closer friend = brighter/thicker connection)

2. **Pick a distinct lane.** Don't repeat an existing file's genre. Options:
   synthwave/80s, acoustic folk-pop ukulele, lo-fi hip-hop, epic cinematic
   trailer pop, west-coast G-funk, disco-house, country, EDM festival.

3. **Tell a tiny story.** Arc: *overwhelmed/disconnected → discovers the app →
   reconnects & grows the circle → triumphant.* This makes a song "entertaining"
   rather than a feature list.

4. **Lock a tagline hook.** Reuse **"who's in your orbit?"** somewhere (usually
   the outro) so all songs share brand DNA, even with a new chorus hook.

5. **Use Suno meta-tags** in lyrics: `[Intro] [Verse] [Pre-Chorus] [Chorus]
   [Bridge] [Outro]`, and parenthetical `(backing vocals)` / `(oh-oh-oh)`.

6. **Keep it clean & positive** — it's a phone-ad anthem: feel-good,
   radio-ready, no profanity.

7. **Always include both modes** (Description + Style/Lyrics) and a **Notes**
   section with genre siblings + a 30-second ad cut.

8. **Naming:** `socialgraph_<vibe>.md` (e.g. `socialgraph_synthwave.md`).
   Add the new file to the table at the top of this README.
