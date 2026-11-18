# Chip In welcome page

Public route: `?view=welcome`. On GitHub Pages the QR destination is:
`https://therealbiebs.github.io/IDidTheDishes/?view=welcome`.
The ordinary root URL remains the app/login page. Native Android always opens the app, including if `view=welcome` is supplied. There are no sign-in requirements or household API calls for the welcome page. Deployment is required before sharing the production QR destination.

The page has exactly three main sections: the original hero, household testimonials (Andrew/Mia, Morgan/Steph and Callie/Taylor, using user-supplied quotes), and the household admin quick start. The quick start has three steps: Create your Household, Select your Rewards, and Peel, stick, connect. The install panel and on-page QR sharing card have been removed; the QR PNG/SVG files remain downloadable directly. The hero and non-metal peel-and-stick felt guidance remain. Reduced-motion preferences disable animation. Generated images illustrate the felt-chip concept; they are not photographs of a manufactured product or customer endorsements. All current testimonial quotes and their names were supplied by the user; generated example copy has been replaced.

## Images

Generated with the built-in image-generation tool, then exported as WebP with Sharp. Both final images use the user's reference of thin, flat, multicolored craft-felt circles, replacing earlier images with padded/embroidered buttons. Keep the original generated PNGs outside the repository; the following optimized project assets are authoritative:

- `public/marketing/felt-chip-hero.webp` (1536 × 1024)
- `public/marketing/household-teamwork.webp` (1536 × 1024; retained asset, not used by the concise three-section page)

Final hero prompt:

> Use case: ads-marketing. Generate a NEW original photorealistic wide 3:2 marketing photo for the Chip In household chore app. The attached image is a PRODUCT MATERIAL REFERENCE, not the target photo: match those exact thin, flat, die-cut colorful craft-felt CIRCLES. They are small featureless solid-color discs with a fuzzy felt texture, NO holes, NO stitches, NO embroidered symbols, NO puffiness or raised dome, NO thick needle-felt wool pucks. Show a realistic hand holding a modern smartphone close to one flat solid teal felt circle, about 3 cm diameter, attached flush to a cream-painted wooden cupboard beside a clean white kitchen sink. Several matching thin felt circles in bright coral, yellow, turquoise, pink and purple are scattered on the natural oak counter in the foreground; some slightly overlap, like the reference. A concealed NFC sticker inside/behind the mounted felt circle is invisible. Phone screen softly glows green with one white checkmark and no words. Warm sunshine, natural green plants and ceramic dishes blurred behind, premium tactile editorial product photography, intimate close framing, natural anatomy. No text, logo, watermark. Never mount on metal. Focus sharply on the flat felt disc, phone and authentic fuzzy craft-felt cut edges.

Final lifestyle prompt:

> Use case: ads-marketing. Generate a NEW photorealistic wide landscape 3:2 household teamwork marketing photo for Chip In. Attached image is a PRODUCT REFERENCE: use these exact thin FLAT die-cut solid-color craft-felt circles, fuzzy flat texture, about 3 cm in diameter. No holes, no embroidery, no stitching, no symbols, no thick padded domes. A warm candid editorial kitchen photo of a smiling adult couple, woman with dark curly hair and man with short hair, both around 30, exchanging a playful high-five after finishing chores. Their school-age child behind them is happily arranging colorful books on a low wooden shelf. Small solid teal and coral felt circles from the reference are attached flush to cream painted wooden cupboard doors beside the clean white sink; a handful of multicolored thin felt circles is casually stacked on a near corner of an oak countertop, shown clearly but not dominating the scene. Warm sunlight, houseplants, folded tea towels, cheerful shared relief, realistic lived-in room, cream, teal and coral accents. Natural anatomy and hands, high quality documentary lifestyle photography. No words, logos or watermarks. Do not mount felt circles on metal. Do not create thick puffy buttons or embroider the felt discs.

## QR assets

- `public/marketing/chip-in-welcome-qr.png`: 1600 px downloadable/printable raster.
- `public/marketing/chip-in-welcome-qr.svg`: scalable print master.

Generated using `qrcode` 1.5.4, H error correction, four-module quiet zone, dark green on white. Independently decoded using `jsQR` 1.4.0 both from the PNG and from a browser screenshot of the displayed QR. QR tooling is local to the outer workspace, not a client-side dependency. Keep the encoded production URL unchanged when deploying this repository at its current Pages address.

Install guidance is based on Apple's iPhone Safari home-screen web app guide and Google's Chrome Android web-app guide, linked in the page. Instructions always start from the app's root URL, and the existing manifest's start URL remains the app.
