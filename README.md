# Mobilenes

An on-screen gamepad around your Godot game: a touch pad on phones and web pages, keyboard and real-gamepad
support, a skin system, button remapping, turbo, vibration and a settings menu - without writing any code.

Mobilenes only **presses buttons**. It never talks to your game and never moves the window.

## The three files

| File | What is in it |
|---|---|
| `mobilenes.gd` | the node you put in your scene; settings; layout; the touch pad; the button list |
| `mobilenes_menu.gd` | the menu; what the player chose (saved); the red **M** handle you pull open |
| `mobilenes_skin.gd` | a gamepad look (pictures, where each button is); the reader of `skin.ini` files |

Each file starts with a table of its parts, and every part has a heading.

## Quick start (3 steps)

1. Copy the `addons/mobilenes` folder into your project.
2. Open `Mobilenes.tscn` and drag **your game scene** into the **Game Scene** slot in the Inspector.
3. Make it your main scene and press Play.

The game screen size is the one in Project Settings > Display > Window > Size (or type another **Game Size**).

## What the player sees

* **Computer:** just the game. The pad is hidden. (The window is sized and centered by your game, not by Mobilenes.)
* **Phone / web page:** the game with a gamepad on both sides. The game is shown at 1x, 2x, 3x ... (whole numbers
  only, so pixels stay perfect); there may be a margin around it.
* To test the phone layout on a computer, set **Screen Layout** to **Mobile** (and turn on **Show Touch Areas**).

## The menu: pull the red M

On the phone layout there is a bright red circle with an **M**, centered on the bottom-left corner of the screen.
**Pull it almost all the way (85 %) to the opposite corner**: the circle GROWS as you pull until it covers the whole screen; the menu then sits on that color. Let go
early and it springs back; let go past the line and the menu opens. On a computer press **F1** (or the Guide
button on a gamepad). In the menu the player can:

* **pick a skin** (every folder inside `addons/mobilenes/skins`),
* **change the keyboard key and gamepad button** of every button,
* switch **turbo** on or off for each button, and **vibration** on or off,
* press **Reset this skin**.

The game is paused while the menu is open. Choices are remembered, separately for each skin.

## The buttons

Mobilenes creates these buttons in the Input Map and presses them (keyboard, real gamepad and touch all work):

| Button | Name | Default keyboard |
|---|---|---|
| Direction cross | `pad_up` `pad_down` `pad_left` `pad_right` | Arrow keys or W A S D |
| A / B | `pad_a` `pad_b` | X or K / Z or J |
| X / Y | `pad_x` `pad_y` | U / O |
| Start / Select | `pad_start` `pad_select` | Enter / Backspace or Shift |
| Shoulders | `pad_l1` `pad_l2` `pad_r1` `pad_r2` | Q F / E G |
| Stick clicks | `pad_l3` `pad_r3` | (none) |
| Right stick | `pad_rs_up` `pad_rs_down` `pad_rs_left` `pad_rs_right` | (none) |
| Menu | `pad_menu` | F1 |
| Turbo A / B | `pad_turbo_a` `pad_turbo_b` | C / V |

A skin only **draws** the buttons it has pictures for (the ascii skin draws the cross, A, B, Select and Start);
a keyboard or real gamepad can use all of them.

Your game does not need these names: AsciiTopper turns them into its own button names in one table, `PAD_TO_GAME`
in `global.gd` (section INPUT ALIASES).

## Settings you can change (select the Mobilenes node)

* **Game Scene**, **Game Size**, **Screen Layout**, **Web Always Shows Pad**
* **Pixel Perfect** (leave ON), **Side Ratio**, **Background Color**
* **Skin Folder**, **Vibration**, **Vibration Ms**, **Turbo Rate**, **Show Touch Areas**
* **Remember Player Settings**, **Pause Game In Menu**, **Show Menu Handle**

## Skins: change the look of the gamepad

A skin is a **folder** with a `skin.ini` text file and some PNG pictures. To add one, drop its folder into
`addons/mobilenes/skins`; it shows up in the menu. To make one, copy the `ascii` folder, change the pictures and
edit its `skin.ini` (it explains itself). The `menu_color =` line sets the colour of the red M circle.
Mistakes in `skin.ini` never crash the game: they show up as yellow warnings in Godot's Output panel.

**Exporting your game?** Godot only includes `.ini` files if you ask: in Export > Resources, add `*.ini` to
**Filters to export non-resource files**.

## Notes

* Vibration works on Android (apps and Chrome web builds). iPhones do not allow web vibration.
* Pixels are only perfect at 1x and up. On a canvas smaller than the game plus its pad (1280 x 400 with the default
  side ratio) the game has to be drawn smaller than 1x, which cannot be perfect.

## Licence

MIT (see `LICENSE`): the code and the pictures of the skins that come with it.
