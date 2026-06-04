# App Store listing — Contextual Contacts (SocialGraph)

Ready-to-paste metadata for App Store Connect, with character counts. Apple
limits are hard caps — every value below is within them.

> **Where each field lives in App Store Connect**
> - **App Information** page (localizable, applies to all versions): **Name**, **Subtitle**.
> - **Version** page (the one shown in the screenshot): **Promotional Text**,
>   **Description**, **Keywords**, **Support URL**, **Marketing URL**,
>   **Version**, **Copyright**, **Screenshots**.

---

## Name (max 30)

`Contextual Contacts` — 19 chars

> The in-app title and legal docs use "Contextual Contacts". If you'd rather
> brand it "SocialGraph", that's 11 chars — but pick one and keep it consistent
> with the legal pages.

## Subtitle (max 30) — indexed for search

**Recommended:** `Nurture your relationships` — 26

Alternatives:

| Subtitle | Chars | Angle |
| --- | --- | --- |
| Nurture your relationships | 26 | relationship-care (recommended) |
| Your personal relationship CRM | 30 | CRM keyword |
| Never lose touch again | 22 | benefit |
| Your people, visualized | 23 | visual graph |
| Level up your network | 21 | gamified |

Tips: don't repeat the app name ("Contacts") — it's already indexed. Benefit
beats feature.

---

## Promotional Text (max 170) — editable anytime without review

```
Turn your contacts into a living map of your relationships. Get gentle nudges before you drift apart, log catch-ups in a tap, and level up as your circle grows.
```

160 chars. Use this field for timely hooks (new features, seasonal) since it
updates without a new build.

---

## Keywords (max 100) — comma-separated, NO spaces

```
CRM,network,reminder,reconnect,birthday,friend,family,social,graph,stay,touch,follow,manager,circle
```

99 chars. Apple combines individual words (ignoring stop words like "in") into
search phrases — e.g. `stay`+`touch` → "stay in touch", `contact`(from name)+
`manager` → "contact manager". Don't repeat words already in the Name/Subtitle.

---

## Description (max 4000)

```
Contextual Contacts turns your address book into a living map of the people in your life — so you actually stay in touch with the ones who matter.

Most contact apps are just a list. Contextual Contacts shows your world as a glowing constellation: see who connects to whom, where you met people, and how your network has grown over time.

WHY YOU'LL LOVE IT
• Visualize your network — explore your contacts as an interactive graph, a map of where you met, or a timeline of your relationships.
• Never drift apart — choose how often you want to reach out to each person and get gentle reminders before a friendship goes quiet.
• Reach out in a tap — call, text, email or message straight from a contact, and the catch-up is logged for you.
• See your strongest bonds — relationship-strength scoring highlights who you're closest to and who needs attention.
• Level up your circle — earn XP, levels, streaks and badges as you grow and tend your network, and follow your progress on a journey roadmap.
• Remember birthdays — get a heads-up before the people you care about have their big day.

YOUR DATA, YOUR CONTROL
• Offline-first — your contacts live on your device.
• Optional secure cloud backup and sync across your devices when you sign in.
• Import from your phone in one tap, and export back to your phone's address book whenever you like.
• No ads. We never sell your data.

Whether you're nurturing close friendships, growing a professional network, or just trying to be a better friend, Contextual Contacts helps you show up for the people who matter.

Privacy Policy: https://socialgraph.codelio-legal.pages.dev/privacy-policy
Terms of Use: https://socialgraph.codelio-legal.pages.dev/terms-of-use
Questions? contact@codelio.fr
```

~1,500 chars (well under 4,000). Plain text — App Store doesn't render Markdown;
the `•` bullets and line breaks display as-is.

---

## Support URL (required)

`https://socialgraph.codelio-legal.pages.dev/`

> Apple requires a reachable page with a way to get help. The deployed site's
> index links to the policy/terms; make sure it shows the support email
> (contact@codelio.fr). If you add a dedicated support page later, point this
> there.

## Marketing URL (optional)

`https://socialgraph.codelio-legal.pages.dev/`  (or leave blank)

## Version

`1.0`

## Copyright (max 200)

`© 2026 Codelio`

---

## Screenshots (iPhone 6.5" — 1242 × 2688 or 1284 × 2778)

Required for iOS. **Only the first 3** are used on the install sheet, so order
matters. Capture on the largest iPhone in the simulator/device; Apple scales for
smaller sizes.

Recommended order (first 3 do the heavy lifting):

1. **The constellation graph** (Mutuals view) — the "wow" differentiator.
2. **The Stats / journey** tab — levels, streak, badges (shows depth + fun).
3. **A contact card** with reach-out status + quick actions (the daily value).
4. Needs-attention / reminders list.
5. Map view (where you met people).
6. Timeline view.

Tip: add a one-line caption band at the top of each screenshot (e.g. "See your
whole network at a glance") — bare screenshots convert worse.

---

## Pre-submit checklist

- [ ] Name + Subtitle set on the **App Information** page.
- [ ] Promotional Text, Description, Keywords, Copyright on the **Version** page.
- [ ] Support URL resolves and shows a contact method.
- [ ] At least 3 iPhone 6.5" screenshots uploaded.
- [ ] Privacy Policy URL (in App Privacy section) =
      `https://socialgraph.codelio-legal.pages.dev/privacy-policy`.
- [ ] App Privacy "data collection" answers match the policy (contacts, account).
- [ ] Build uploaded and selected for the 1.0 version.
