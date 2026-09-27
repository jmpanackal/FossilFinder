Fossil Finder art pipeline
==========================

Folders
-------
art/templates/   blank exact-size PNG guides (faint grid + filename)
art/ai/          generated reference placeholders for the artist
art/final/       your finished PNGs; the only folder the game loads

Same subfolders in each: cells/  bones/  tools/  scraps/  museum/

The live game never reads art/ai/ or art/templates/. Until a real PNG
is in art/final/, it keeps the original _draw look (tan dirt #C4A36A,
tool glyphs, bone doodles, scrap icons).

Sizes (exact pixels)
--------------------
cells    64 x 40
bones    64 x 40 per cell; multi-cell parts use the bounding box
         (cols x 64) x (rows x 40). Empty cells in the box are hatched.
tools    32 x 32
scraps   16 x 16
museum   256 x 128  (brachiosaurus is 256 x 160)

Filenames match game ids, for example:
  art/templates/cells/dirt_loose.png
  art/templates/tools/shovel.png
  art/templates/scraps/pebble.png
  art/templates/bones/t_rex_tooth.png
  art/templates/bones/t_rex_skull.png
  art/templates/museum/t_rex.png

Workflow
--------
1. Open art/templates/foo.png in Aseprite or LibreSprite
   (or Photoshop: nearest neighbor, no antialias).
2. Paint on the pixels. Keep the canvas the same size.
3. Export PNG, same size, with transparency.
4. Save as the SAME filename in art/final/cells/
   (or bones/ tools/ scraps/ museum/).
5. In Godot, Filter is Off (nearest). A real final PNG overrides _draw.
   Delete the final file to fall back to _draw.

Notes
-----
- Do not edit art/ai/ if you want a keepable original; paint from templates.
- Empty, white, or tiny files in art/final/ are ignored so _draw stays.
- Re-run art/generate_art.py only if you need to rebuild guides/placeholders.
- Godot import: lossless, no mipmaps, Filter Off.
- Museum hall keeps the assembled doodle until you drop a PNG in
  art/final/museum/. Dirt, tools, scraps, and bones keep _draw until then.
