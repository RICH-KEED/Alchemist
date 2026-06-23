# Alchemist UI Style Taxonomy

A reference catalog of 140+ visual design styles, categorized by implementation tier,
domain fit, and Flutter approach. Referenced by skills 04 (Premium Design System),
05 (App Preview), 43 (Design Critic), and 79 (Initialize — app DNA → visual direction).

**How skills use this:** When a user names a style ("cyberpunk habit tracker") or the
app domain implies one ("fintech dashboard"), skill 04 picks the matching style(s)
from this taxonomy and translates them into Material 3 ThemeData + AppTokens overrides.
The result is always a coherent M3 foundation flavored by the chosen aesthetic,
never a raw custom paint unless the style demands Tier 3+.

---

## Implementation Tiers

| Tier | Name | Meaning | Flutter approach |
|---|---|---|---|
| T1 | M3 Native | Achievable with ColorScheme + AppTokens alone | `fromSeed` + spacing/radius tweaks |
| T2 | M3 Extended | Needs custom ThemeData overrides + component themes | Above + `*ThemeData` overrides + custom clipper/shape |
| T3 | Custom Paint | Needs shaders, CustomPainter, or significant canvas work | Above + `BackdropFilter`, `ShaderMask`, `CustomPaint` |
| T4 | Platform Kit | Uses Cupertino / Fluent / platform-specific widgets | `flutter/cupertino.dart`, `fluent_ui` package |
| T5 | Conceptual | A philosophy, not a visual layer | Informs interaction patterns, not pixels |

---

## Style Catalog

### Material / Platform-Native

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Material Design (classic) | T1 | General | Blue | 4dp | Cards + shadows + FAB |
| Material You (M3) | T1 | General | User wallpaper / seed | 12dp | Dynamic color, large top app bars, tonal surfaces |
| Material Expressive | T2 | Consumer apps | Bold primaries | 16-28dp | Exaggerated shapes, playful motion, oversized FABs |
| Cupertino | T4 | iOS-first apps | System blue | 10dp | Translucent nav bars, SF font, segmented controls |
| Human Interface Design | T4 | iOS, visionOS, macOS | System colors | System | Flat + depth, SF Symbols, haptic feedback |
| Fluent Design | T4 | Windows / enterprise | Accent color | 4dp | Reveal highlight, acrylic, fluent icons |
| Metro Design | T1 | Windows phone era | Bold tiles | 0dp | Flat squares, horizontal scroll, typography as hierarchy |
| Carbon Design System | T2 | Enterprise / IBM | Blue 60, Gray 100 | 0dp | Dense data, IBM Plex, structured forms |
| Ant Design | T2 | Enterprise B2B | Blue #1890FF | 2dp | Dense tables, form-heavy, Chinese-friendly spacing |
| Chakra UI Style | T2 | Dev tools / B2B | Teal, purple | 6dp | Accessible by default, composable, dark-mode-first |
| Shadcn Style | T2 | Dev tools / startups | Neutral stone/slate | 8dp | Unstyled base, beautiful defaults, Tailwind-inspired |
| Radix Style | T1 | Dev tools / headless | Neutral | 6dp | Accessible primitives, no default style |
| Atlassian Design | T2 | Productivity / SaaS | Blue #0052CC | 3dp | Dense, functional, sidebar-heavy layouts |
| Stripe-Style UI | T2 | Fintech / SaaS | Indigo #635BFF | 6dp | Gradient buttons, dark headers, generous whitespace |
| Apple-Style UI | T4 | Premium consumer | System gray/blue | 10dp | Frosted glass, large titles, SF font, minimal chrome |
| Google-Style UI | T1 | Consumer web/mobile | Google Blue/Red/Yellow/Green | 16dp | Bold, colorful, friendly, rounded everything |
| Microsoft Fluent UI | T4 | Windows / Office | Accent colors | 4dp | Acrylic, reveal, fluent depth shadows |

---

### Minimal / Clean

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Minimalism | T1 | Premium, productivity, tools | Monochrome + 1 accent | 2-8dp | White space, one accent color, no ornament |
| Flat Design | T1 | General, CRUD apps | Bold primaries | 2-4dp | No shadows, solid colors, clean shapes, typography-led |
| Swiss Design | T1 | Editorial, design tools, agency | Red + black + white | 0-2dp | Grid, Helvetica, asymmetric, photography |
| Bauhaus | T2 | Creative, education, galleries | Primary yellow/red/blue | 0dp | Geometric shapes, "form follows function", circles/squares/triangles |
| Monochromatic UI | T1 | Luxury, portfolio, night-mode apps | One hue, varied saturation | 4-8dp | Single color family, texture over color contrast |
| Invisible UI | T5 | Content-first, reading, immersive | Neutral + content | Minimal | Chrome disappears until needed; content is the UI |
| One-Handed Mobile UI | T1 | Utilities, quick actions | Any | 8-16dp | Critical actions in thumb zone (bottom 40%), large targets |

---

### Depth & Texture

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Neumorphism | T3 | Wellness, meditation, calculators | Soft pastels | 12-20dp | Soft inset/outset shadows, light source top-left, debossed inputs |
| Claymorphism | T3 | Kids, creative, playful | Bold pastels | 24-40dp | Soft 3D blob shapes, double inner+outer shadow, bubbly |
| Glassmorphism | T2 | Premium, fintech, card-based | Background-dependent | 12-20dp | BackdropFilter blur, translucent surface, subtle border |
| Liquid Glass | T3 | VisionOS-style, futuristic | Frosted system | 16-24dp | Glass + depth + dynamic refraction, light-responsive |
| Glass Neon | T3 | Nightlife, music, gaming | Dark + neon accents | 12dp | Frosted glass + neon glow borders, dark backgrounds |
| Skeuomorphism | T3 | Niche/retro, games, music apps | Real-world textures | Variable | Leather, wood, metal textures; realistic shadows |
| Soft UI | T2 | Wellness, health, lifestyle | Pastels | 16-24dp | Gentle shadows, soft colors, rounded everything, friendly |
| Depth UI | T2 | Productivity, file managers | Neutral + accent | 4-12dp | Multiple elevation layers, strong shadows, z-space navigation |
| Layered UI | T2 | Card-based, dashboards | Any | 8-16dp | Visual z-depth, stacked cards offset, overlapping elements |
| Aurora UI | T3 | Creative, music, meditation | Northern-lights gradients | 12dp | Flowing gradient meshes, smooth color transitions, organic |

---

### Brutalist / Experimental

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Brutalism | T2 | Creative portfolios, art, underground | Raw gray, black, white | 0dp | Raw, unpolished, heavy borders, monospace, default system font |
| Neo-Brutalism | T2 | Gen Z consumer, startups, social | Bold primaries + black | 0dp | Heavy black borders + hard shadows (offset 4-8px), primary colors, rounded-but-chunky |
| Cyberpunk | T3 | Gaming, dev tools, nightlife | Neon on black | 0-4dp | Dark bg + neon cyan/magenta/yellow, glitch effects, scanlines, monospace |
| Futurism | T2 | AI startups, tech, innovation | Cool gradients | 8-16dp | Sleek, metallic accents, dynamic lines, fast motion, holographic |
| Sci-Fi HUD | T3 | Gaming, industrial, dashboards | Cyan/amber on black | 0-2dp | Wireframe overlays, corner brackets, data streams, thin lines, monospace |
| Holographic UI | T3 | Sci-fi, entertainment, AR/VR | Iridescent | 8dp | Hologram effect, transparency + cyan tint, scanning lines |
| Vaporwave | T3 | Music, retro, nostalgic | Hot pink + cyan + purple | 0-8dp | 80s/90s, chrome text, purple sun grid, geometric shapes |
| Y2K Design | T2 | Fashion, Gen Z, retro-nostalgic | Metallic + pink + baby blue | 8-16dp | Bubblegum, chrome, gradients, rounded blobs, early-2000s optimism |
| Retro UI | T2 | Games, nostalgia, themed apps | Era-specific | Variable | Pixel-art, 8/16-bit, old monitor phosphor, era-specific |
| Memphis Design | T2 | Creative, event, playful | Bold pastel clashing combos | 8-16dp | Geometric shapes, squiggles, triangles, clashing colors, 80s postmodern |
| Experimental UI | T3 | Art, generative, research | Any | Any | No rules; every convention is optional; feels intentional |
| Parametric UI | T5 | Generative, data-art, creative tools | Algorithmic | Variable | UI generated by parameters/rules; data sculptures |

---

### Modern SaaS / Startup

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Bento UI | T2 | Dashboards, SaaS, personal sites | Neutral + accent | 16-24dp | Grid of rounded cards, different sizes, info hierarchy by card weight |
| SaaS UI | T2 | B2B, productivity, CRUD | Blue/Purple/Indigo | 8-12dp | Sidebar + content, data tables, consistent component library |
| AI Startup UI | T2 | AI tools, chatbots, generative | Dark + gradient accent | 12-20dp | Gradient buttons, dark mode, conversational, "magic" sparkle icon |
| Fintech UI | T2 | Banking, investing, crypto | Dark + green/blue/gold | 8-12dp | Dense data, charts, real-time numbers, trust cues, card-based transactions |
| Super App UI | T2 | Multi-service, emerging markets | Bold primaries | 12dp | Mini-apps grid, wallet, chat, services, deep nested navigation |
| Dashboard UI | T2 | Analytics, monitoring, ops | Dark + status colors | 4-12dp | Widget grid, real-time charts, KPI cards, data-dense, responsive |
| Data-Dense UI | T2 | Trading, analytics, industrial | Dark | 2-4dp | Maximum information density, monospace numbers, compact tables |
| Command Center UI | T2 | Ops, monitoring, security | Dark + red/green status | 2-4dp | Real-time feeds, alert tiers, maps, status grids |
| Terminal UI | T1 | Dev tools, CLI fans | Green on black | 0dp | Monospace, text-only, keyboard-driven, zero chrome |
| Developer Tool UI | T2 | IDEs, APIs, CLIs | Dark + accent | 4-8dp | Monospace, syntax-highlighting, tree views, terminal panels |
| Notion-Style UI | T1 | Docs, wikis, knowledge bases | Neutral | 4dp | Typography-first, minimal chrome, slash commands, blocks |
| Linear-Style UI | T2 | Project management, SaaS | Dark + accent | 8dp | Keyboard-first, fast, minimal, command palette, sleek |
| Workspace UI | T2 | Productivity, collaboration | Neutral + accent | 8-16dp | Multi-panel, resizable, tabs, drag-and-drop |
| Kanban UI | T2 | Project management, boards | Any | 8dp | Columns, draggable cards, swimlanes |
| Timeline UI | T2 | Project, history, feeds | Any | 4-8dp | Horizontal/vertical time axis, event markers |
| Progressive Disclosure UI | T1 | Complex tools, onboarding | Any | Any | Show basics first, reveal advanced on demand; accordion, "show more" |
| Enterprise UI | T2 | Large orgs, compliance, legacy | Corporate colors | 2-4dp | Dense, RBAC, audit trails, complex forms, accessible |

---

### Visual Spectacle

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| Gradient UI | T1 | Creative, marketing, consumer | Gradient pairs | 8-16dp | Bold gradients as backgrounds, gradient text, gradient borders |
| Dynamic Color UI | T1 | Any (Android 12+) | User wallpaper | 12dp | Material You dynamic color, wallpaer-derived palette, automatic light/dark |
| Morphing UI | T3 | Creative, animation-heavy | Any | Variable | Shapes morph between states, liquid-like transitions |
| Floating UI | T2 | Creative, immersive, AR-style | Any | 16dp | Elements float in 3D space with parallax, tilt, depth |
| Motion-First UI | T2 | Creative, storytelling, premium | Any | Any | Animation is the primary communication; every transition tells a story |
| Microinteraction-Driven UI | T2 | Premium consumer, delight-focused | Any | Any | Every gesture has a response; tap, swipe, scroll all animate |
| Delight-Driven UI | T2 | Consumer, games, kids | Bright, playful | 12-24dp | Surprise + joy in every interaction; confetti, bounce, sparkle |
| Emotional Design | T2 | Wellness, social, storytelling | Warm, human | 8-16dp | Color/font/motion evoke specific emotions; empathy-led design |
| Storytelling UI | T2 | Onboarding, education, narrative | Story-dependent | Variable | Narrative structure; scroll-driven, chapter-based |
| Immersive UI | T3 | Games, galleries, experiences | Content-led | 0dp | Full-bleed, no chrome, ambient audio, haptics |
| Living Interface Design | T3 | Generative, AI, ambient | Algorithmic | Variable | UI changes organically over time; day/night, seasons, user behavior |
| Generative UI | T5 | AI-native, adaptive, experimental | Algorithmic | Variable | UI generated by AI at runtime; no fixed layout |

---

### Domain-Specific

| Style | Tier | Domain fit | Seed | Radius | Key traits |
|---|---|---|---|---|---|
| E-Commerce UI | T2 | Shopping, retail | Brand colors | 8-12dp | Product grids, carousels, cart FAB, checkout flow, sales banners |
| Social Media UI | T2 | Social, community | Brand | 12-20dp | Feed, stories, reactions, comments, share sheet |
| Productivity UI | T2 | Tasks, notes, calendars | Neutral + accent | 4-8dp | List/detail, quick capture, search-first, keyboard shortcuts |
| Health & Wellness UI | T1 | Fitness, meditation, health | Calming greens/blues | 12-24dp | Progress rings, gentle colors, encouraging copy, health data |
| Education UI | T2 | Learning, courses, kids | Playful, warm | 8-16dp | Progress, quizzes, gamification, bite-sized content, achievements |
| Travel UI | T2 | Booking, guides, maps | Warm, aspirational | 12-16dp | Hero images, maps, itineraries, exploration-first |
| Banking UI | T2 | Finance, banking | Dark blue / trusted | 4-8dp | Security cues, transaction lists, account cards, biometric locks |
| Web3 UI | T2 | Dapps, wallets, NFTs | Dark + gradient | 12-16dp | Wallet connect, transaction confirmations, block explorers, tokens |
| Crypto UI | T2 | Exchanges, portfolios, DeFi | Dark + green/red | 4-12dp | Price charts, order books, real-time tickers, green/red semantics |
| Gaming UI | T3 | Games, gamified apps | Game palette | Variable | HUD overlays, health bars, XP/level, achievement popups, custom fonts |
| Industrial UI | T2 | Factory, IoT, monitoring | Dark | 0-4dp | Gauge clusters, real-time metrics, alarm states, touch-optimized |
| Automotive UI | T2 | Car dashboards, HUDs | Dark | 0-4dp | Glanceable, large touch targets, night mode, voice-enabled |
| Smart Home UI | T2 | IoT, home automation | Neutral + accent | 8-12dp | Room/device cards, toggle grids, status indicators, quick controls |
| Wearable UI | T2 | Watch, fitness band | Dark + accent | Full round/rect | Glanceable, list-based, single-action, complications, bezel scroll |
| Kiosk UI | T2 | Public terminals, check-in | Brand | 0-4dp | Large targets, no keyboard, timeout, guided flow, accessibility |
| Embedded UI | T2 | Small screens, appliances | System | 0-4dp | Minimal text, icon-heavy, status indicators, physical button mapping |
| TV UI | T2 | Android TV, streaming | Dark | 0-8dp | D-pad navigation, focus rings, lean-back, 10-foot UI |
| Foldable UI | T2 | Foldables, dual-screen | Any | Variable | Multi-window, continuity, hinge-aware, unfold→expand |
| Spatial UI | T3 | Vision Pro, AR glasses | Glass + depth | 16dp | 3D space, gesture, gaze, depth layers, volumetric |
| AR UI | T3 | Augmented reality | Real-world + overlay | Variable | World-locked panels, gesture, occlusion-aware |
| VR UI | T3 | Virtual reality | Immersive 3D | Variable | Diegetic UI, gaze+pointer, comfortable viewing cone |
| Mixed Reality UI | T3 | MR headsets | Glass + spatial | 16dp | Passthrough + virtual, spatial anchors, hand tracking |
| Conversational UI | T2 | Chatbots, AI assistants | Neutral + accent | 12-20dp | Chat bubbles, typing indicators, suggested replies, markdown |
| Voice-First UI | T5 | Voice assistants, accessibility | Any | Any | Visual feedback for audio state, waveform, minimal text |
| Zero-UI | T5 | Background, ambient, sensors | N/A | N/A | No visual interface; haptic, audio, sensor-driven |
| Agentic UI | T5 | AI agents, autonomous | Adaptive | Variable | Agent decides what to show; minimal human chrome, intent-driven |
| AI-Native UI | T5 | Generative, adaptive, agent-first | Algorithmic | Variable | UI composed by AI at runtime; no hand-crafted screens |
| Contextual UI | T1 | Smart, adaptive | Any | Any | UI changes based on context (time, location, activity, user state) |
| Predictive UI | T2 | Smart assistants, anticipatory | Any | Any | Predicts intent; pre-loads next action; reduces steps |
| Reactive UI | T2 | Real-time, collaborative | Any | Any | Immediate feedback to data changes; streaming, WebSocket-driven |
| Multimodal UI | T2 | Input-flexible | Any | Any | Accepts voice/touch/keyboard/gesture interchangeably |
| Accessibility-First UI | T1 | All apps | High contrast | Any | Built from a11y outward; labeled, contrast-checked, screen-reader-native |
| Adaptive UI | T1 | Cross-platform | Any | Any | Adapts layout/input per device class (phone/tablet/desktop/TV) |
| Responsive UI | T1 | All apps | Any | Any | Fluid grids, breakpoints, orientation-aware — skill 17 owns this |
| Gesture-Driven UI | T2 | Creative, immersive, gaming | Any | Any | Primary input = gesture (swipe, pinch, drag); minimal visible controls |
| Card-Based Design | T2 | Feeds, dashboards, e-commerce | Any | 8-16dp | Content organized into discrete cards; elevation or outlined |
| Magazine Style UI | T2 | News, editorial, blogs | Brand | 0-4dp | Typography-heavy, asymmetric grid, pull quotes, hero images |
| Editorial Design | T2 | Long-form, publishing, journalism | Serif + neutral | 0-2dp | Typography is the UI; drop caps, columns, figure captions |
| Data Visualization UI | T2 | Analytics, dashboards, reports | Dark or white | 2-4dp | Charts, graphs, maps as primary UI; interactive data exploration |
| Infographic UI | T2 | Reports, marketing, education | Brand | 4-8dp | Information as visual story; data + illustration hybrid |
| Ribbon UI | T2 | Microsoft Office era | System | 0dp | Tabbed toolbar, grouped commands, contextual tabs |
| Luxury/Premium UI | T2 | Fashion, jewelry, high-end | Dark + gold/cream | 0-4dp | Serif typography, generous whitespace, gold/champagne accents, slow reveals |
| Organic Design | T2 | Wellness, nature, eco | Earth tones | Organic curves | Curved, asymmetrical, leaf/nature motifs, flowing shapes |
| Biomorphic Design | T2 | Health, science, art | Nature palette | Organic | Cell-like, curved forms, natural patterns, coral/bone textures |
| Dynamic Island Style UI | T2 | iOS interactive notifications | Dark | Full pill | Pill-shaped animated surface, expands/collapses, live activities |
| VisionOS Style UI | T3 | Spatial computing | Frosted glass | 16dp | Glass material, depth, eye+hand tracking, spatial audio, window ornaments |
| Glass Panel UI | T2 | Premium overlays, music, widgets | Frosted | 12-20dp | Translucent panels, light blur, subtle border, depth ordering |
| Ambient UI | T2 | Smart home, IoT, calm tech | Subtle | Variable | Peripheral, calm, glanceable, non-intrusive; fits the environment |
| Adaptive Theme UI | T1 | Any | Dynamic | 12dp | Theme adapts to time, ambient light, battery, context |
| Computational Design UI | T3 | Generative, data-art | Algorithmic | Variable | Data-fed design systems; parameters drive layout/color/scale |

---

## Style Selection Guide (for skill 04)

When the user names a style or the app domain implies one:

1. **Look up the style in this catalog.** If found, use its seed color, radius, and key traits.
2. **If no style is named**, default to **Material You (M3)** for consumer apps, **SaaS UI** for B2B, **Dashboard UI** for data apps.
3. **Mixed styles:** combine at most TWO — one domain style + one visual aesthetic (e.g. "Bento UI + Glassmorphism" = bento card grid with frosted glass cards).
4. **Tier 3+ styles:** warn the user that parts require custom painting/shaders and will take longer. Offer the nearest T1/T2 approximation as a fast alternative.
5. **All styles ultimately compile to Material 3 `ThemeData` + `AppTokens` overrides.** The taxonomy informs the token values (spacing scale, radius set, motion curve, type scale, color roles), not the rendering engine.

## Anti-patterns

- Picking a style because it's trendy, not because it fits the domain.
- Mixing three or more styles — becomes incoherent.
- Using Tier 3+ for an MVP (ships slowly and the custom code is hard to maintain).
- Applying a style's traits as raw values in widgets instead of encoding them in ThemeData + AppTokens.
