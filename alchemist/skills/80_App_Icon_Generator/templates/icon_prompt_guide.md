# App Icon Prompt Guide

How to generate a professional app icon image when the user has no artwork.
Feed one of these prompts to DALL-E 3, Midjourney v6, Stable Diffusion SDXL, or the
Google Stitch MCP (if connected).

---

## The prompt formula

```
[STYLE PREFIX] A mobile app icon for a [APP_TYPE] called "[APP_NAME]".
[COLOR], [MOOD] aesthetic. Key element: [VISUAL]. Flat 2D vector, clean lines,
2-3 colors max, bold silhouette, no text. Centered with 33% padding.
[FORMAT SUFFIX]
```

## Per-model variants

### DALL-E 3 (via ChatGPT or API)

```
A clean flat 2D vector mobile app icon: [VISUAL] in [PRIMARY_COLOR] on a
[BACKGROUND_COLOR] rounded square background. No text, no shadows, no device
frame, no photo. Bold minimal silhouette, centered with 33% padding.
Professional app icon style for Google Play Store. 1:1 square.
```

### Midjourney v6

```
[VISUAL], flat vector app icon, [SECONDARY_COLOR] on [BACKGROUND_COLOR] rounded
square, minimal bold silhouette, clean lines, 2 colors, centered, padding around
edges --ar 1:1 --stylize 200 --style 2d-vector --no text,letters,words,device,
shadow,photo,realistic,3d,gradient
```

### Stable Diffusion SDXL

```
flat vector app icon, [VISUAL], [PRIMARY_COLOR] and [SECONDARY_COLOR] palette,
bold minimal silhouette, clean lines, 2 colors, centered composition, padding
around edges, rounded square, no text, no shadows, no device, 2d vector art style

Negative prompt: photo, realistic, 3d, shadow, text, letters, words, gradient,
device frame, screenshot, busy, complex, more than 3 colors, background, pattern
```

### Google Stitch MCP (if connected)

Send the MCP a prompt like:
```
Generate a flat vector mobile app icon. Concept: [VISUAL]. Colors: [PRIMARY] and
[BACKGROUND]. Style: bold minimal 2D, clean silhouette, 2-3 colors max, centered
with generous padding. Output: 1024x1024 PNG with transparent background on the
foreground layer and a solid [BACKGROUND_COLOR] background layer.
```

---

## App-type → visual element map

Use this to pick the key visual element. Prefer universal, culturally-neutral symbols.

| App type | Primary visual | Alternate |
|---|---|---|
| Habit tracker | Checkmark inside circle | Streak flame, calendar with check |
| To-do / tasks | Checkmark in rounded box | Clipboard with check, gear+check |
| Notes / writing | Pencil at 45° | Open book + pen, paper + lines |
| Fitness / workout | Dumbbell silhouette | Running figure, heart + pulse line |
| Running / cardio | Running shoe silhouette | Wing, stopwatch + wing |
| Meditation / wellness | Lotus flower | Infinity loop, leaf + water drop |
| Finance / budget | Shield + dollar sign | Upward arrow in circle, wallet |
| Investing / stocks | Upward arrow + graph line | Candlestick, building + arrow up |
| Banking | Building columns | Keyhole + shield, vault door |
| Messaging / chat | Speech bubble | Two overlapping bubbles, send arrow |
| Social network | People silhouette (2 heads) | Network nodes, heart in circle |
| Dating | Heart | Two hearts overlapping, flame |
| Food delivery | Fork + knife crossed | Bag + scooter, plate + star |
| Restaurant finder | Map pin + fork | Plate with star, chef hat |
| Recipe / cooking | Chef hat + spoon | Pot with steam, whisk |
| Grocery / shopping | Shopping cart | Bag, barcode + cart |
| E-commerce | Shopping bag | Tag + bag, cart + star |
| Travel / booking | Airplane at 45° | Compass, globe + pin |
| Hotel / lodging | Building + bed | Key + building, moon + building |
| Navigation / maps | Map pin | Compass needle, route line |
| Music player | Headphones | Music note, waveform, vinyl |
| Podcast | Microphone | Headphones + mic, sound waves |
| Video streaming | Play triangle in circle | Film strip, clapboard |
| Photo / camera | Camera lens | Aperture blades, photo frame |
| Education / learning | Lightbulb | Graduation cap, open book |
| Language learning | Speech bubble + globe | Open book + A,B,C |
| Kids / parenting | Star + moon | Balloon, building blocks |
| Health / medical | Cross in circle | Heart + cross, heartbeat line |
| Mental health | Brain + heart | Sun rising, hands holding heart |
| Weather | Sun + cloud | Umbrella + raindrop, cloud + snow |
| News | Newspaper fold | Globe + headline lines |
| Sports scores | Trophy | Megaphone, stadium |
| Calendar / events | Calendar page | Clock + star, bell + calendar |
| Email | Envelope | Inbox tray, @ symbol |
| File manager | Folder | File cabinet, document |
| Settings / tools | Gear | Wrench, slider toggles |
| Security / VPN | Shield + keyhole | Padlock, fingerprint |
| Password manager | Key | Padlock + key, fingerprint |
| Dating / romance | Heart | Rose, two overlapping hearts |
| Pet / animal | Paw print | Dog/cat silhouette, bone |
| Plant / garden | Leaf | Sprout, watering can |
| Sleep / alarm | Alarm clock + moon | Moon + stars, bell |
| Loyalty / rewards | Star + gift | Trophy + star, ribbon |
| Auction / bidding | Gavel | Paddle + star, bid hammer |
| Real estate | House silhouette | Building + key, house + heart |
| Job search | Briefcase | Building + person, handshake |
| Ride sharing | Car silhouette | Map pin + car, steering wheel |
| Parking | P (parking sign) | Car + square, location + car |
| Charity / donation | Heart in hands | Ribbon, open hands |
| Religion | Respectful abstract symbol | Dove, open book |

---

## Icon color formulas

Pick 2 colors max. Formula: **primary on background**.

| Mood | Background | Icon foreground | Good for |
|---|---|---|---|
| Fresh / healthy | #E8F5F0 (mint tint) | #0D9488 (teal) | Health, wellness, habit |
| Trust / calm | #E3F2FD (blue tint) | #1565C0 (blue) | Finance, banking |
| Energy / action | #FFF3E0 (orange tint) | #E65100 (orange) | Fitness, food delivery |
| Creative / warm | #FCE4EC (pink tint) | #C62828 (red) | Social, dating |
| Focus / clarity | #F5F5F5 (white tint) | #212121 (near-black) | Productivity, notes |
| Premium / luxury | #1A1A1A (near-black) | #FFD700 (gold) | Premium, investing |
| Nature / earth | #E8F5E9 (green tint) | #2E7D32 (green) | Travel, garden |
| Night / calm | #263238 (blue-grey 900) | #80DEEA (cyan 200) | Meditation, sleep |
| Playful / kids | #FFF9C4 (yellow tint) | #F9A825 (amber) | Kids, games, education |
| Clean / minimal | #FFFFFF (white) | #0D47A1 (blue 900) | Tools, utilities |

---

## After generating the image

1. Download the best variant at the highest resolution available.
2. Resize/crop to exactly 1024×1024 (or 2048×2048 for headroom).
3. Split into layers if needed:
   - **Foreground:** the icon mark, with transparent background (everything not the mark = alpha 0%).
   - **Background:** a solid color fill (the brand background color, or white).
   - **Monochrome:** the foreground converted to pure black (all non-alpha pixels → #000000).
4. Save all layers and the full-color icon as PNGs.
5. Place in `assets/icon/`.
6. Run `dart run flutter_launcher_icons`.
