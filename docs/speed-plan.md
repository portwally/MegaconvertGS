# Remap speed plan

Where Remap's time goes on a 2.8 MHz IIgs, what can be made faster without changing a
single output pixel, and in what order to do it.

Cycle figures are 65816 cycles counted from the listings (native mode, 16-bit A and X/Y
unless stated, direct page on a page boundary, every buffer in fast RAM). Times are
seconds in MAME at 2.8 MHz, as `build/suite_remap2.txt` and `build/suite_true.txt` log
them. Routine and label names refer to `src/RemapSeg.s`, `src/RemapRender.s`,
`src/SegLib.s` and `src/True.s` as they are on 28 October.

## Summary

| Remap (as measured today) | Now | After steps 1-6 | After step 7 |
|---|---:|---:|---:|
| 320 x 200 RGB picture to 320 mode, calculated palette, pattern dither (R01) | 18.6 s | 7.0 s | 4.5 s |
| the same to 640 mode / 640 dither mode (R09 / R13) | 54.4 / 54.7 s | 10.4 / 10.5 s | 7.4 / 7.4 s |
| error diffusion, greys (R04) | 23.3 s | 12.0 s | 8.9 s |
| 640 mode screen to 320 mode, 2:1 box averages (R23) | 95.5 s | 10.5 s | 10.5 s |
| Quick remap of a 640 mode screen (Q03) | 93.4 s | 9.5 s | 9.5 s |
| opening the 400 x 300 PNG (47.6 s decoding + remap) | 107.3 s | 54.8 s | 54.8 s |
| a 320 x 200 photograph (805 colours) to 320 mode (model) | 50.4 s | 9.9 s | 7.3 s |
| the whole remap2 suite, 36 remaps | 1412 s | 356 s | 282 s |

Three things cost most today:

1. **The box average divides three times for every output pixel** (`DivAvg`, about 720
   cycles each). A 640 mode screen remapped to 320 mode spends 52 % of its 95 s there,
   the fitted 400 x 300 PNG 54 % of its remap.
2. **Per-pixel overhead that does not touch the result.** Plain enlargement (every
   640 mode remap of a 320-wide picture) goes through the general box path with three
   divisions by 1: 57 % of the 54 s. Each line is copied three times (into the planes,
   then out again by `GetLine` for `HistLines` and for `RenderLines`); each pixel goes
   through `PutPixel` and a 50-cycle bit test of the lookup cache.
3. **On real photographs, `Best` and `CalcPalette`.** The test pictures have 6 to 131
   distinct 12-bit colours; photographs have hundreds. Each colour costs two `Best`
   searches of 256 candidates (87,000 cycles, 32 ms), half of a photograph's remap;
   `CalcPalette` adds another 17 %.

Every change below gives bit-identical results. Each arithmetic change was checked
against the original integer arithmetic over its whole input range, and each change in
the order of a search against the original routine on over a million targets, every
12-bit colour among them (section 2 and Appendix B); nothing here changes which
candidate, colour or palette wins a tie.

## 1. Where the time goes

### 1.1 How the figures were made

Each loop body was counted in cycles from its instructions. A model then replays the
remap step by step (the same steps, options and test pictures as the remap2 suite, with
the same palettes, histograms and lookups) and counts how often each loop runs. With one
allowance of 5 % for what the machine does besides the remap (interrupts: the 60 Hz
tick, the cursor), the model agrees with all 36 timed remaps of the remap2 suite to
within 1.1 % (Appendix A). The figures below are the model's.

The test pictures have very few colours (RGB8.PNG: 32 distinct 12-bit colours; the
fitted HUGE.PNG: 131). Four ordinary photographs scaled to 320 x 200 (327 to 805
colours) and one at 400 x 300 (879 colours) were run through the model as well, since
they load `Best` and `CalcPalette` far more.

### 1.2 What each routine costs

| Stage | Routine, loop | Cycles | Notes |
|---|---|---|---|
| Screen to true colour | `ScreenToTrue` `:pix` (three `:x17` calls a pixel) | 296 a pixel on a 320 line, 359 on a 640 line (`:sh` shifts 0 to 6 times) | plus `NewTrue`'s `FillBig`, 15 a byte (45 a pixel), all of it overwritten. 640 x 200 screen: 52 M cycles, 19.0 s; 320 x 200: 22 M, 8.0 s |
| Spans | `MakePlanes` `:col` → `SpanOf`: 2 `Mul16`, 2 `Div32` | about 4,900 an output column | `Div32` is 32 rounds of 58-62: 1,900. Each line: `SpanOf` again and `Mul16` for its address, 5,400. In all 1.0 s a remap 320 wide, 1.5 s 640 wide |
| Scaling 1:1 | `ScaleRow` `:unit` + `SetLine` | 209 a pixel | `SetLine` alone 146 (JSR included) |
| Scaling, general | `ScaleRow` `:general` (`:pix`, `:srcRow`, `:srcPix`) | 295 a pixel + 55 a source line + 91 a source pixel + `Mul16` (113) + 3 `DivAvg` | 2:1 box: 2,805 a pixel, 2,160 of it `DivAvg`. Enlarged pixel (n = 1): 665, all overhead |
| Division | `DivAvg` (`:sh` 7 shifts, `:bit` 8 rounds) | 37 when n = 1, else 652 + 17 per 1 bit of the quotient (about 720) | three an output pixel |
| Planes store | `MakePlanes` `:c`, `:g` | 61 a pixel | + `PlaneRow`'s `Mul16`, 540 a line |
| Line copy | `GetLine` `:c`, `:g` | 59 a pixel | run by `HistLines`, `RenderLines`, `Diffuse`, `Quick`, `Multi` |
| Histogram | `HistLines` `:pix` | 38 a pixel + `GetLine` | + 53,000 to clear 4,096 words |
| Palette | `CalcPalette`, `ArgMax`, `Reduce`, `Dist` | `ArgMax` 106,000 a call (4,096 entries); bias about 2,800 a colour present (`Dist`, `Mul16`, `Div32`); `Reduce` 78,000 for the empty entries + 350 a colour present + 2,400 more for each colour nearer than 50 (`Mul16`, `Div32`) | a 320 calculated palette: 15 `ArgMax`, 16 `Reduce`. RGB8: 3.8 M cycles (1.4 s); the 805-colour photograph 23 M (8.5 s). `Dist` alone: 291-307 |
| Candidates | `BuildCands` `:cand` | 904 a two-colour candidate, 1,481 a four-colour one | 0.08 to 0.14 s a palette |
| Best | `Best` `:try` | 163-175 a usable candidate (three `Abs` calls of 15-19), 16 a reserved one; 43,300 a call with 256 candidates | `Lookup` with patterns: 2 `Best` + 227, about 87,000 (32 ms) a colour. Closest match, 16 candidates: 2,800 |
| Lookup cache | `RenderLines` `:colourPix` | 71 a pixel (50 for the bit test, 21 to fetch) | each colour is looked up once a palette, as it should be; checking costs more than it needs |
| Rendering | `RenderLines` `:pix`, `PutPixel`, `ClearRowOut`, `StoreRow` | 254 a pixel in 320 mode, 261 in 640 (cache 84, `:bytes` 18, `PutPixel` 74/81, loop 19, `GetLine` 59) | each line also 1,054 (`ClearRowOut`) + 2,205 (`StoreRow`) |
| Error diffusion | `Diffuse` `:pix`, `GreyOf` | 430 a pixel (320), 484 (640), 498 (640 dither), + `GetLine` | each line 21,400: `:sw` swaps 645 words whatever the width |
| Quick remap | `Quick` `:pix` | 224 a pixel (+9 per channel at or above the threshold) + `GetLine` | |
| Multipalette | `MinDist`, `Multi` `:line`/`:try`/`:px`, `MPTables` | `MinDist` 5,600 a palette and colour (16 `Dist`); 50 a pixel tried per palette; each pass rebuilds every palette (`HistLines`, `CalcPalette`) | |

### 1.3 Shares in typical remaps

Seconds from the model; for the timed remaps, measured / model in brackets.

**320 x 200 RGB to 320 mode, calculated, pattern dither (R01, 18.6 s / 18.5 s):** `RenderLines` 6.3 s (34 %), `ScaleRow` 1:1 4.9 s (27 %), `HistLines` 2.3 s
(13 %), planes store 1.5 s (8 %), `CalcPalette` 1.4 s (8 %), `Best` 1.0 s (6 %, 32
colours), spans 1.0 s (5 %). Most of it is overhead per pixel: of `RenderLines`' 254
cycles a pixel, 71 check the lookup cache, 74 are `PutPixel` and 59 copy the line back;
`HistLines` is 97 cycles a pixel, 59 of them copying the line; the planes store 61 more.

**The same to 640 mode (R09, 54.4 s / 54.5 s):** the general box path for the 2x
enlargement 26.0 s (48 %) and its three divisions by 1, 5.2 s (10 %); `RenderLines`
12.5 s (23 %); `HistLines` 4.6 s (8 %); store 2.9 s (5 %); spans 1.5 s (3 %). The 640
dither mode (R13) is the same to a tenth of a second.

**640 mode screen to 320 mode, 2:1 box averages (R23, 95.5 s / 95.7 s):** `DivAvg`
50.0 s (52 %), `ScreenToTrue` 16.9 s + its fill 2.1 s (20 %), the box sums 15.1 s (16 %),
`RenderLines` 6.3 s (7 %), `HistLines` 2.3 s (2 %). Quick remap of the same screen (Q03,
93.4 s / 93.7 s) scales the same way; only its 7.1 s of ordered dither differ.

**Error diffusion (R04, 23.3 s / 23.2 s):** `Diffuse` 13.1 s (56 %), `ScaleRow` 4.9 s
(21 %), `HistLines` 2.3 s (10 %).

**400 x 300 PNG fitted to 266 x 200 (BIG.PNG; the remap of its 107.3 s load):**
`DivAvg` 32.0 s (54 %), box sums 13.9 s (23 %), `RenderLines` 5.3 s (9 %), `Best` 2.4 s
(4 %). The load measured 107.3 s and the remap is 59.7 s of it, so decoding the PNG is
47.6 s (RGB8.PNG: 26.3 s of 44.8 s).

**A photograph, 320 x 200, 805 colours, to 320 mode (model, 50.4 s):** `Best` 25.7 s
(51 %), `CalcPalette` 8.5 s (17 %), `RenderLines` 6.3 s (12 %), `ScaleRow` 4.9 s (10 %).
The other photographs: `Best` 34-47 %, `CalcPalette` 14-16 %. Fitted from 400 x 300:
`DivAvg` 31.7 s (36 %), `Best` 25.5 s (29 %), box sums 13.9 s (16 %), `CalcPalette` 8.2 s
(9 %), 88.9 s in all.

**Multipalette (R17, 46.5 s / 46.4 s):** the line costs 17.7 s (38 %), `RenderLines`
6.3 s (14 %), `MPTables` 5.4 s + its `CalcPalette` 2.0 s (16 %), `ScaleRow` 4.9 s (11 %),
`Present` 2.4 s, `MinDist` 2.1 s, `BuildCands` 1.4 s (once a run of lines). On the
photograph it takes 337 s: `CalcPalette` 131 s (39 %; 48 palette calculations of about
190 colours each), `Best` 96 s (28 %), `MinDist` 53 s (16 %), line costs 31 s (9 %).

## 2. Optimisations that keep the output identical

Gains are the model's, applied in the order of section 3; each step's gain is measured
after the steps before it.

### 2.1 Box averaging without DivAvg (MakePlanes, ScaleRow, SpanOf)

**Spans by stepping.** `SpanOf` computes `a = i*src/out` and `b = (i+1)*src/out` with
two `Mul16` and two `Div32` for every column and line. Divide once per axis instead
(`src/out` and `src%out`) and step: add the quotient, add the remainder, and carry one
when the remainder reaches `out`. About 40 cycles a column instead of 4,900.
*Check:* every source/output pair that `Sizes` and `Quick` can produce (pictures 1 to
4,096 each way, all 23 steps, both pixel shapes, 320 and 640 wide: 62,634 pairs across,
19,693 down), every span the scaler computes: 16,897,967 spans, all equal.

**At most four divisors a remap, each with its cheapest exact method.** A span is
either `floor(src/out)` or `ceil(src/out)` pixels long, so a remap meets at most four
box sizes `n` (two across times two down). Choose a method for each before scaling:

- `n = 1`: no division.
- `n` a power of two: shift right (`LSR` k times; 2 cycles each).
- other `n <= 64`: a quotient table, `T[s] = s/n` for `s = 0 .. 255n` (at most 16,066
  bytes), filled by counting: each quotient written `n` times, no division. 15 cycles a
  channel (`LDY sum`, `LDA [qt],Y`, `AND #$FF`).
- `64 < n <= 257`: the same eight rounds as `DivAvg`, but in 16-bit registers with no
  scaling loop: about 170 cycles a channel.
- `n > 257`: today's 32-bit sums and `DivAvg`. This only happens when the output is a
  few pixels wide or tall (a box can reach 63 x 31 = 1,953 pixels when a small picture
  is shrunk to one pixel), so its speed does not matter.

For `n <= 257` the sums fit 16 bits (255 x 257 = 65,535), so they can live in the
direct page without the carry into a high word.

*Check:* for every box size that can occur up to 257 (202 of them) and every sum
`0 .. 255n` (6,058,747 cases): `DivAvg` as written (step by step) = `s / n` = the
shift = the counted table = the 16-bit eight rounds. All equal.

Reciprocal multiplication was checked too and is not worth it here: to be exact over
`0 .. 255n` it needs a 10- to 16-bit multiplier and a 19- to 31-bit product (n = 3:
`(s*683) >> 11`; n = 63: `(s*16645) >> 20`; n = 255: `(s*32897) >> 23`). The 65816
has no multiply instruction, and a software multiply of that size costs more than the
table or the shift.

**Fast paths.**

- *Spans of one pixel* (1:1, and every enlargement, such as a 320-wide picture in a 640
  mode): three byte loads, the colour word and grey level from byte tables, about 170
  cycles a pixel instead of 209 (1:1) or 665 (enlarged). When enlarging, a column whose
  source pixel is the same as the column before's copies its result (25 cycles), so a 2x
  enlargement converts each source pixel once.
- *Boxes up to 2 x 2* (n = 2, the 2:1 of 640 mode screens; and the 1, 2, 4 mix of 3:2
  reductions and of halving): sums unrolled, 16-bit loads splitting two channels with
  `XBA`, `LSR` for the division: 140 + 39 a source pixel, so 218 for a 2:1 box instead of
  2,805.
- *General:* 16-bit sums in the direct page, no `Mul16` per pixel (each column's count
  and box kind are set once), a jump to the box size's method: 30 + 38 a source line + 71
  a source pixel + 12 for the jump + the division + 110 for the colour and grey.

The colour word and grey level come from six 256-entry tables:
`(R&$F0)<<4`, `G&$F0`, `B>>4` (or the same doubled, giving the cache and histogram
index directly) and `5R`, `8G`, `3B`, summed and shifted right 4.
*Check:* all 16,777,216 RGB values: colour, doubled colour and grey equal to `SetLine`.

A 2:1 box, the first channel (Y: the left pixel's offset; each 16-bit load gives two
channels):

```
        lda   [q0],y        ; 7  G0 R0
        tax                 ; 2
        and   #$00FF        ; 3
        sta   sr            ; 4  R0 (direct page)
        ...                 ;    G0 from XBA of X; B0 R1 from the next word, G1 B1 after
        lda   r1            ; 4
        clc                 ; 2
        adc   sr            ; 4
        lsr                 ; 2  (R0 + R1) / 2, exactly DivAvg's answer for n = 2
```

**Gain:** the remap2 suite 1412 s → 822 s. R23 (640 screen to 320) 95.5 → 34.3 s; R09
(640 mode) 54.4 → 25.4 s; R20 (BIG.PNG, steps 19/9) 61.9 → 13.9 s; R01 18.6 → 16.2 s;
the fitted BIG.PNG remap 59.7 → 16.9 s, HUGE.PNG 84.7 → 29.0 s; Quick remap of the 640
screen 93.4 → 32.2 s.
**Effort:** medium; `MakePlanes`, `ScaleRow`, `SpanOf`, `DivAvg` rewritten, about 300
lines. **Risk:** low: self-contained, and the planes it makes can be compared byte for
byte with today's.

### 2.2 ScreenToTrue from per-line colour tables

Per line, write the line's 16 colours times 17 into three 16-byte tables (R, G, B); per
byte of the screen, find the pixels' entries (320: the two nibbles; 640: the four bit
pairs plus 8, 12, 0, 4, from static 256-entry tables) and store the table bytes, the
whole line loop in 8-bit accumulator mode. Skip `NewTrue`'s fill for this picture:
every byte is written anyway. A line in 640 mode inside a 320 mode picture is the one
case that reads past its 16-entry table (entry up to 27, into the next colour table);
such lines keep today's per-pixel code, so even that stays identical.

```
:byte   ldx   bi            ; 4  byte index (direct page); 8-bit A, high byte of C zero
        lda   Line,x        ; 5  the screen line, copied once
        tax                 ; 2
        lda   HiNib,x       ; 5  the left pixel's entry
        tax                 ; 2
        lda   R17,x         ; 5
        sta   [q0],y        ; 6
        iny                 ; 2  ... G17, B17; then the right pixel with LoNib
```

About 60 cycles a pixel (320) and 50 (640) instead of 296 and 359 plus the fill.
*Check:* both fixtures and eight random screens (random pixels, colour tables and SCBs,
with mixed 320 and 640 lines), each read as a 320 and as a 640 picture: 20 conversions,
all identical.

**Gain:** 640 x 200 screen 19.0 → 2.4 s; 320 x 200 screen 8.0 → 1.5 s. R23 34.3 → 17.7
s, Q03 32.2 → 15.6 s, R30/R31 46.6 → 30.0 s, R22 32.8 → 26.3 s; suite 822 → 726 s.
**Effort:** small, about 100 lines. **Risk:** low.

### 2.3 Best: fewer candidates, cheaper scores, searched outwards

`Best` returns the candidate with the lowest score, ties going to the highest index (it
scans downwards and keeps only a strictly lower score), or 0 if nothing scores below
$7D00. Three changes keep exactly that:

1. **Compaction** (in `BuildCands`): leave out candidates with a reserved entry, and of
   candidates with the same `AvgR, AvgG, AvgB, Penalty`, keep only the highest index.
   Equal candidates always score the same, so the lower one could never win. A 320
   pattern table keeps at most 136 of 256 (a pattern and its mirror image are equal); a
   640 mode table at most 35 (four pixels from four colours); 640 dither at most 100 (84
   when black and white are shared by the two halves, as in its calculated, default and
   grey palettes).
2. **Table scores:** per call, point three direct-page pointers into tables of `3|k|`,
   `4|k|` and `2|k|` (511 words each) at the target; each candidate keeps
   `2*AvgR`, `2*AvgG`, `2*AvgB` and `Penalty>>4`. 60 cycles a candidate instead of 169:

   ```
   :try    ldy   CR2,x         ; 6  2*AvgR of candidate x
           lda   (pR),y        ; 7  3|AvgR-R|   (pR = W3 + 2*(255-R), set per call)
           ldy   CG2,x         ; 6
           clc                 ; 2
           adc   (pG),y        ; 7  + 4|AvgG-G|
           ldy   CB2,x         ; 6
           adc   (pB),y        ; 7  + 2|AvgB-B|
           adc   CP16,x        ; 6  + Penalty/16
           cmp   BestScore     ; 4  (direct page)
           bcc   :better       ; 2
           dex
           dex                 ; 4
           bpl   :try          ; 3
   ```

3. **Search outwards by green:** sort the kept candidates by `AvgG` (a counting sort, 256
   buckets) and keep a 256-entry table of where each green value starts. Walk up and
   down from the target's green; stop each way as soon as `4|AvgG-G|` alone is above the
   best score (nothing further out can win or tie). A candidate with an equal score wins
   if its index is higher, which gives today's answer in any order. On the photographs'
   real lookups this scores 27 to 32 candidates a call instead of 256: about 2,000-2,800
   cycles a `Best` instead of 43,300.

Leaving a candidate early when a partial score (green first) is already not lower, in
today's order, was measured as well: on real lookups it saves nothing over compaction and
tables (8,400 against 8,200 cycles a call), because in index order the best score is
found late.

*Checks:* the three weight tables against the arithmetic for every candidate and target
value (65,536 pairs each); compaction with table scores, the outward search, and the
early exit, each against today's `Best`, for 56 palettes (default, greys and every other
palette of each mode, the calculated palettes of the test pictures and photographs, and
random palettes with reserved and repeated entries, including some with every entry
reserved), each with and without patterns, on every 12-bit colour, the second target each
one leads to, every grey level and 3,000 random targets: 1,052,800 searches, all equal.

**Gain:** a `Lookup` from 87,000 cycles to about 5,000. The 805-colour photograph 48.0 →
24.0 s (`Best` 25.7 s → 1.7 s); R05 (grey levels, 110 lookups) 16.7 → 13.2 s; suite 726
→ 702 s (the test pictures have few colours).
**Effort:** medium, about 200 lines in `BuildCands` and `Best`; about 6 KB of tables.
**Risk:** low to medium: the tie rule must be exactly right; the remap2 suite covers
many palettes, but add a picture with many colours (section 3).

### 2.4 Rendering loops and one pass less

- **Histogram while scaling.** For one-palette remaps, count each pixel's colour in
  `MakePlanes`' loop (about 26 cycles a pixel) instead of `HistLines` copying every line
  back with `GetLine` (97 a pixel). Keep the 16-bit count saturating at $FFFF.
- **Planes read in place:** `RenderLines`, `Diffuse` and `Quick` read the line with
  `[p1],y`; no `GetLine` copy (59 a pixel).
- **A cheaper cache check:** a word per colour holding the number of the
  `RenderLines` call that filled it (no clearing between runs; clear all only if the
  number wraps), instead of the bit test: 12 cycles instead of 50, and the cached value
  is fetched with the same index.
- **Bytes built directly:** two pixels make a byte in 320 mode, four in 640 mode. Take
  each pixel's bits from the even or odd line's pattern byte with a fixed mask
  (`$F0`/`$0F`; `$C0`/`$30`/`$0C`/`$03`), OR them together and store a word every four
  (320) or eight (640) pixels through a long pointer into the screen line. No `PutPixel`,
  `ClearRowOut` or `StoreRow`.

  ```
  * even line, 320 mode; Val = even byte * 256 + odd byte
  :px     lda   [p1],y        ; 7  colour * 2 (planes, read in place)
          tax                 ; 2
          lda   Gen,x         ; 6  looked up during this call?
          cmp   CurGen        ; 4
          bne   :miss         ; 2
          lda   Val,x         ; 6
          and   #$F000        ; 3  left pixel: the even byte's high nibble
          sta   acc           ; 4  ... right pixel with #$0F00, ORA, XBA, store
  ```

  About 47 cycles a pixel in 320 mode and 50 in 640 mode and for greys, instead of 254-261.
- **Diffuse:** same arithmetic; the grey shown (`GreyOf`) taken from a table by level and
  column (it depends only on those); `PutPixel` inlined; one loop each way instead of
  adding `DStep`; the next line's error buffer cleared over its width + 2 words, not 645.
  About 250 cycles a pixel instead of 489.
- **Quick remap:** the ordered dither from four tables of 4,096 entries (one for each
  line and column parity), built once: about 35 cycles a pixel instead of about 290.

*Checks:* output bytes built directly against `PutPixel` ORing into a cleared `RowOut`
on 20,000 random lines (both modes, odd widths): identical. `GreyOf` by level and column
against `GreyOf` for every column, for 38 grey palettes in all three modes (the greys and
the grey "other" palettes of each mode, and 30 random grey ones; 5,242,880 cases):
identical. The Quick tables against the threshold test for every colour and
parity: identical.

**Gain:** R01 15.2 → 8.3 s; R09 24.3 → 10.8 s; R04 20.6 → 12.0 s; R24 27.4 → 13.8 s;
Q03 15.6 → 9.5 s; suite 702 → 394 s. The largest step after the box averages, for
every remap.
**Effort:** large: about 400 lines, as each of 320/640, colour/grey and even/odd line
wants its own loop. **Risk:** medium: many combinations, but the remap2 and dialog
suites cover every mode, palette kind and rendering.

### 2.5 CalcPalette over the colours present

- **A colour list.** Build the list of colours present once, in colour order (4,096
  steps), and make the counting, the bias, `ArgMax` and `Reduce` walk the list (D
  colours) instead of 4,096 entries. `ArgMax` over the list in colour order with
  "strictly greater" still lets the first colour win; zeroed counts stay in the list and
  are skipped as now.
- **`Dist` from tables.** Keep `3r`, `4g`, `2b` and `3r+4g+2b` with each listed colour,
  the same for the target; then
  `|a| + |b| + |c| + (|a+b+c| >> 2)` is three subtractions into an `|x|` table and one
  into an `|x|>>2` table: about 110 cycles instead of 300.
- **The popularity bias** `d * peak / 9` (a `Mul16` and a `Div32` per colour today)
  from a 91-entry table (90 is the largest distance to $777) filled by adding `peak` and
  carrying the remainder: one division per palette. The table holds
  `min(q, $FFFF)`; a colour's count is at least 1, so a quotient above $FFFF saturates
  the sum either way, as today.
- **`Reduce`'s** `count * d / 50` (a `Mul16` and a `Div32` per near colour) as
  `a*d + T50[b][d]`, where `count = 50a + b` comes from `count = 256h + l`:
  `a = 5h + Q[6h+l]`, `b = R[6h+l]` (quotient and remainder by 50, 1,786 entries each),
  and `T50` holds `floor(b*d/50)` for `b, d < 50` (2,500 bytes). About 200 cycles
  instead of 2,300.

*Checks:* `Dist` from tables for all 16,777,216 colour pairs; the bias table for every
peak 1 to 65,535 and every distance 0 to 90 (with the counts 1 and peak); `count*d/50`
for every count 0 to 65,535 and every `d < 50`; and the whole of `CalcPalette` with all
of these, against today's, on 1,958 cases (89 histograms: the test pictures',
the photographs', sixteen multipalette bands and 60 random ones with saturated counts and
ties, each with all 22 prototypes): all equal.

**Gain:** the photograph's `CalcPalette` 8.5 s → 1.2 s (17.2 → 9.9 s for the remap);
multipalette on it 131 s → 16 s of `CalcPalette`; R01 8.3 → 7.0 s; suite 394 → 383 s.
**Effort:** medium, about 250 lines and 22 KB of tables (16 KB of them the channel
values of each 12-bit colour; working those out from the colour instead costs about 25
cycles more a distance). **Risk:** low to medium; the suites compare every colour table.

### 2.6 Multipalette

- `MinDist` with the table `Dist` of 2.5: about 2,000 cycles a palette and colour
  instead of 5,600.
- The line costs: planes read in place, and the line's own palette tried first. It
  gives a low bound at once, so the others stop sooner. To keep today's choice (the
  first palette with the lowest cost, or the line's owner if none ends below $FFFF, with
  the same 16-bit overflow rule), the others are then dropped once their cost is above
  the best (not equal), and an equal cost wins if its palette number is lower. 21 % fewer
  pixels summed.
- `HistLines` per palette reads the planes in place and clears only the listed colours;
  `Present` takes its list from the histogram `MakePlanes` already counted.
- `BuildCands`, run for each run of lines, with the tables of 2.3: about 500 cycles a
  candidate instead of 900.

*Check:* the palette chosen for every line of every pass of six multipalette remaps
(the test picture and two photographs, standard, max 8 and optimized) and 20,000 random
lines with ties and overflows: 23,600 lines, all equal.

**Gain:** R17 36.3 → 22.3 s, R19 27.8 → 16.5 s, R18 10.8 → 9.0 s; on the photograph
123.7 → 71.5 s (what remains: line costs 19.9 s, `MinDist` 19.4 s, `CalcPalette` 15.6 s).
**Effort:** small to medium, about 150 lines. **Risk:** low.

### 2.7 No planes when every span is one pixel

At 1:1, and when only enlarging, the planes are just the source pixels converted. Then
`MakePlanes` can count the histogram alone (colour from three bytes and the tables,
about 75 cycles a pixel) and store nothing, and the render loops convert again from the
source (about 55 cycles a pixel more), colour or grey as they need. This saves the grey
level of colour remaps, the store and the 192 to 384 KB buffer.

**Gain:** R01 7.0 → 4.5 s, R09 10.4 → 7.4 s, R24 13.8 → 8.7 s, R04 12.0 → 8.9 s; suite
356 → 282 s. **Effort:** medium, about 150 lines. **Risk:** medium: a second source for
the render loops.

### 2.8 General points

- **Direct page:** each absolute variable access costs a cycle more than a direct page
  one. Put the inner loops' variables (sums, targets, `BestScore`, `PixX`, `Cost`,
  pointers) in the direct page as the loops are rewritten: 5-10 % of those loops.
- **8-bit modes:** an 8-bit accumulator saves a cycle on each memory access and suits
  byte loops (`ScreenToTrue`, the quotient tables, output bytes), as long as the whole
  loop stays in one width: each `SEP`/`REP` costs 3. Index registers stay 16-bit (every
  array is longer than 256 bytes).
- **Memory speed:** everything Remap touches is in fast RAM (only banks $E0 and $E1 are
  slow, and Remap writes its screen to `ScreenP`, not to bank $E1), so moving buffers
  gains nothing.
- **Room:** the Remap segment is $D191 bytes, leaving about 12 KB of its bank. The new
  tables (about 40 KB: weights 3 KB, colour and grey 3 KB, generation words 8 KB, palette
  tables 22 KB, sorted candidates 3 KB, screen tables 1.5 KB) belong in one handle that
  does not cross a bank, with the data bank set to it in the inner loops; `Hist`,
  `CacheVal` and `PList` (24 KB) can move there too. The quotient tables (up to 4 x 16
  KB) go in a handle of their own, made for each remap.
- **Banks:** the true colour picture and the planes may cross banks, so keep `[dp],Y`
  addressing for them (it carries into the bank byte); `MVN` would wrap within a bank.
- **The dialog's `Stats`** (counted once per picture when the Remap dialog opens) costs
  66 cycles a pixel: 1.5 s for 320 x 200, 3 s for a 640 mode screen. It can be counted
  while `ScreenToTrue` or the decoder writes the picture if that ever matters.

### 2.9 Considered and not recommended

- Reciprocal multiplication for the box averages: exact only with 10- to 16-bit
  multipliers (2.1), slower than tables or shifts on a CPU without a multiply.
- Early exit on partial scores in `Best`'s own order: no gain (2.3).
- Per-line colour counts for the multipalette line costs: they need a multiply per
  colour, which costs more than the additions it saves.
- Copying lines with `MVN`: not safe while buffers may cross banks, and unnecessary once
  lines are read in place.

## 3. Recommended order and expected timings

1. **Box averaging (2.1).** The largest gain, the problem the README names, and
   self-contained.
2. **ScreenToTrue (2.2).** Small, independent; halves what is left of a screen picture's
   remap.
3. **Best (2.3).** Independent of the rest; the largest cost on real photographs.
4. **Rendering (2.4).** The largest remaining cost of every remap; the biggest change.
5. **CalcPalette (2.5).**
6. **Multipalette (2.6).**
7. **No planes at 1:1 (2.7),** if more is wanted.

Expected times (model), after each step in that order, seconds at 2.8 MHz:

| Remap | Now | 1 box | 2 screen | 3 Best | 4 render | 5 palette | 6 multi | 7 no planes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| R01 RGB 320, calculated, pattern | 18.6 | 16.2 | 16.2 | 15.2 | 8.3 | 7.0 | 7.0 | 4.5 |
| R04 RGB 320, greys, diffusion | 23.3 | 20.8 | 20.8 | 20.6 | 12.0 | 12.0 | 12.0 | 8.9 |
| R05 RGB 320, greys, pattern | 19.1 | 16.7 | 16.7 | 13.2 | 7.1 | 7.1 | 7.1 | 4.6 |
| R09 RGB 640, calculated, pattern | 54.4 | 25.4 | 25.4 | 24.3 | 10.8 | 10.4 | 10.4 | 7.4 |
| R11 RGB 640, greys, diffusion | 67.7 | 38.5 | 38.5 | 38.5 | 21.0 | 21.0 | 21.0 | 16.8 |
| R13 RGB 640 dither, calculated, pattern | 54.7 | 25.6 | 25.6 | 24.6 | 11.0 | 10.5 | 10.5 | 7.4 |
| R17 RGB multipalette, calculated | 46.5 | 44.1 | 44.1 | 42.3 | 37.2 | 36.3 | 22.3 | 22.3 |
| R20 BIG 320, steps 19/9 | 61.9 | 13.9 | 13.9 | 12.7 | 7.6 | 6.2 | 6.2 | 6.2 |
| R22 SCR 640, calculated | 61.9 | 32.8 | 26.3 | 25.8 | 12.2 | 11.9 | 11.9 | 8.9 |
| R23 S64 320 (640 screen, 2:1) | 95.5 | 34.3 | 17.7 | 17.4 | 10.5 | 10.5 | 10.5 | 10.5 |
| R24 S64 640 dither | 31.9 | 27.6 | 27.6 | 27.4 | 13.8 | 13.8 | 13.8 | 8.7 |
| Q03 S64 quick remap | 93.4 | 32.2 | 15.6 | 15.6 | 9.5 | 9.5 | 9.5 | 9.5 |
| RGB8.PNG load (26.3 s decoding) | 44.8 | 42.5 | 42.5 | 41.5 | 34.6 | 33.3 | 33.3 | 30.8 |
| BIG.PNG load, 400 x 300 (47.6 s decoding) | 107.3 | 64.5 | 64.5 | 62.2 | 56.4 | 54.8 | 54.8 | 54.8 |
| HUGE.PNG load, 700 x 500 (134.1 s decoding) | 218.8 | 163.1 | 163.1 | 159.1 | 153.1 | 150.9 | 150.9 | 150.9 |
| photograph 320 x 200 to 320 (model only) | 50.4 | 48.0 | 48.0 | 24.0 | 17.2 | 9.9 | 9.9 | 7.3 |
| photograph 400 x 300, fitted (model only) | 88.9 | 46.5 | 46.5 | 22.6 | 16.8 | 9.8 | 9.8 | 9.8 |
| photograph to 640 mode (model only) | 81.0 | 51.9 | 51.9 | 27.2 | 13.6 | 11.5 | 11.5 | 8.5 |
| photograph, multipalette (model only) | 337.5 | 335.2 | 335.2 | 244.5 | 239.3 | 123.7 | 71.5 | 71.5 |
| remap2 suite, 36 remaps | 1412 | 822 | 726 | 702 | 394 | 383 | 356 | 282 |

Once this is done, decoding dominates opening a file: RGB8.PNG would spend 26 s decoding
and 4.5 s remapping, BIG.PNG 48 s and 7 s. The decoders (`Inflate.s` and `PNG.s` for
these; not looked at here) are then the next target.

**Before starting**, add to the remap2 list:

- BIG.PNG with steps 0/0 (box sizes 256: shift, and 272: today's path), 3/3 (64: shift,
  and 72: the eight rounds) and 4/4 (36 and 42: tables), in 320 mode. Today the suites
  meet only the box sizes 1, 2, 4 (shift), 6 and 9 (tables).
- A test picture with many colours (a few hundred distinct 12-bit colours, like a
  photograph); today's pictures have 6 to 131, so `Best`, the lookup cache and
  `CalcPalette` are hardly exercised.
- A screen picture with both 320 and 640 mode lines, for `ScreenToTrue`.

**After each step**, run the remap2, true and dialog suites (every pixel, line mode and
colour table must still match GS Remap) and compare each logged time with this table;
the model should stay within a few per cent, which also checks the cycle counts the next
steps rely on.

## Appendix A: the model against the measured times

Measured (`build/suite_remap2.txt`) and model, seconds:

| Run | Measured | Model | Run | Measured | Model | Run | Measured | Model |
|---|---:|---:|---|---:|---:|---|---:|---:|
| R01 | 18.6 | 18.5 | R13 | 54.7 | 54.7 | R25 | 4.6 | 4.6 |
| R02 | 17.5 | 17.5 | R14 | 53.6 | 53.6 | R26 | 16.5 | 16.4 |
| R03 | 17.2 | 17.2 | R15 | 54.1 | 54.1 | R27 | 4.2 | 4.2 |
| R04 | 23.3 | 23.2 | R16 | 68.7 | 68.4 | R28 | 17.2 | 17.2 |
| R05 | 19.1 | 19.0 | R17 | 46.5 | 46.4 | R29 | 24.1 | 24.1 |
| R06 | 17.2 | 17.2 | R18 | 20.9 | 21.0 | R30 | 50.8 | 50.9 |
| R07 | 23.1 | 23.0 | R19 | 37.4 | 37.2 | R31 | 50.8 | 50.9 |
| R08 | 18.2 | 18.2 | R20 | 61.9 | 62.0 | R32 | 95.5 | 95.7 |
| R09 | 54.4 | 54.5 | R21 | 50.9 | 51.0 | R33 | 4.5 | 4.5 |
| R10 | 53.3 | 53.3 | R22 | 61.9 | 61.9 | Q01 | 14.5 | 14.5 |
| R11 | 67.7 | 67.6 | R23 | 95.5 | 95.7 | Q02 | 14.5 | 14.5 |
| R12 | 54.1 | 54.1 | R24 | 31.9 | 31.9 | Q03 | 93.4 | 93.7 |

Largest difference 1.1 %. Time = cycles x 1.05 / 2,863,636. The model also reproduces
the suite's quirks: R32 (S64 in 320 mode with its current palette) becomes a calculated
palette, as `PalOK` decides, and takes as long as R23; R25 (calculated, diffusion) is
rendered with pattern dither.

## Appendix B: check results

The checks are small Python scripts (standard library only) in `test/speed/`:
`check_spans.py`, `check_division.py`, `check_best.py`, `check_best_partial.py`,
`check_calcpal.py`, `check_misc.py`, `check_multi.py`, and `mutation_test.py`, which
breaks each fast version on purpose to show the checks catch it. `model.py` and
`optmodel.py` are the timing models. They read the test pictures from `build/fixtures`
(run `./test/fixtures.sh` and `test/make_true.py` first) and photographs, as 24-bit BMP
files, from `test/speed/photos` (or `PHOTOS=...`); the photographs aren't included. Their output (a few
long lines wrapped or shortened):

```
check_spans.py
distinct (source, output) pairs: across 62634  down 19693
spans compared: 16897967  mismatches: 0
span lengths across: 1 .. 63  down: 1 .. 31
box sizes n = across x down: 791 values, largest 1953
n <= 257 (sums fit 16 bits): 202

check_division.py
box sizes checked: 202 (n = 1..257 that occur), sums checked: 6058747, mismatches: 0
powers of two (shift): 9; quotient tables (n <= 64): 57, largest 16066 bytes;
8-round division (64 < n <= 257): 136
reciprocal multiply, smallest exact k:  n, sum bits, k, m, m bits, product bits
    (3, 10, 11, 683, 10, 19)    (5, 11, 13, 1639, 11, 21)    (6, 11, 12, 683, 10, 20)
    (9, 12, 14, 1821, 11, 22)   (12, 12, 15, 2731, 12, 23)   (25, 13, 17, 5243, 13, 25)
    (63, 14, 20, 16645, 15, 28) (255, 16, 23, 32897, 16, 31)

check_best.py
score tables, all 65536 (candidate, target) pairs per weight: mismatches 0
targets checked: 1052800; mismatches: compacted+tables 0, pruned 0
candidates scored: original 169206112, pruned 21265130 (12.6 %)
compacted list sizes (kind, entries, pattern): min/avg/max of the kept candidates
    ('calc', 4, False) 4 4.0 4  of 4
    ('calc', 4, True) 35 35.0 35  of 256
    ('calc', 8, False) 15 15.0 15  of 16
    ('calc', 8, True) 84 84.0 84  of 256
    ('calc', 16, False) 16 16.0 16  of 16
    ('calc', 16, True) 135 135.9 136  of 256
    ('fixed', 4, False) 4 4.0 4  of 4
    ('fixed', 4, True) 35 35.0 35  of 256
    ('fixed', 8, False) 15 15.0 15  of 16
    ('fixed', 8, True) 66 75.0 84  of 256
    ('fixed', 16, False) 16 16.0 16  of 16
    ('fixed', 16, True) 135 135.5 136  of 256
    ('other', 4, False) 2 3.2 4  of 4
    ('other', 4, True) 5 22.5 35  of 256
    ('other', 8, False) 3 8.7 15  of 16
    ('other', 8, True) 5 32.7 66  of 256
    ('other', 16, False) 2 10.2 16  of 16
    ('other', 16, True) 3 67.5 136  of 256
    ('random', 4, False) 2 3.2 4  of 4
    ('random', 4, True) 5 22.5 35  of 256
    ('random', 8, False) 0 6.5 16  of 16
    ('random', 8, True) 0 33.8 100  of 256
    ('random', 16, False) 8 12.8 16  of 16
    ('random', 16, True) 36 93.5 136  of 256

check_best_partial.py   (photo: one of the photographs; mode 0 = 320, 1 = 640, 2 = 640 dither)
partial-score early exit, original order: 1052800 targets, mismatches 0
cycles per Best call on real lookups (first and second Best of each colour present):
   case                               original  compact+tables  +early exit  sorted walk
   RGB            mode 0 (136 kept)     43305           8220         8417         1993
   photo:Parrot   mode 0 (136 kept)     43305           8220         7437         2797
   photo:Zebra    mode 0 (136 kept)     43305           8220         7866         2499
   photo:Parrot   mode 1 ( 35 kept)     43305           2160         2339         1338
   photo:Parrot   mode 2 ( 84 kept)     43305           5100         4753         2582

check_calcpal.py
a. Dist from tables, all 16777216 colour pairs: mismatches 0; largest distance to $777: 90
b. bias table, every peak 1..65535 and d 0..90 (counts 1 and peak): mismatches 0
c. count*d/50 by tables, every count 0..65535 and d 0..49: mismatches 0
d. CalcPalette over the colour list with a-c: 1958 (histogram, prototype) cases, mismatches 0

check_misc.py
a. SetLine from tables, all 16777216 RGB values (colour, doubled colour, grey): mismatches 0
b. output bytes written directly, 20000 random lines (320 and 640): mismatches 0
c. Diffuse's grey shown, by level and column parity: (cases, mismatches) (5242880, 0)
d. Quick remap from 4 tables of 4096 entries, every colour and parity: mismatches 0
e. ScreenToTrue from per-line tables, fixtures and random screens: (pictures, mismatches) (20, 0)

check_multi.py
lines compared: 23600, mismatches: 0
pixels summed on the remaps' lines: original 11392704, owner first 9006700 (79 %)

mutation_test.py (each must be caught)
bad quotient table caught: 1
too-short reciprocal for n=9 caught: 454
span walk without carry caught: 3
Dist without the last term caught: True
bad T50 entry caught: True
ties to the lower index caught: True
```
