---
title: "Let's build a VORON: Quality of life mods"
tags: ["3D printing", "VORON"]
series: voron_trident
---

I can print, but there are still some parts I've had to print myself to complete the mods included in the LDO kit, and I also wanted to add more mods I've found.

It's a wonderful feeling to augment the printer with parts made by the printer itself.

# RockNRoll

![](/images/trident/rocknroll.jpg)

Flipping over the printer to access the electronics apartment is a huge pain.
There's a very cool [inverted electronics bay mod][] for Trident printers, but it's a tall ask for me to redo _all_ the wiring at this point.

But then I found the simple [RockNRoll][] mod that allows you to easily tilt the printer.
Just having the rockers doesn't work as the center of gravity is too high for the Trident, but with [these additional stilts][rock-stilts] it works great.

# Removable panels

![](/images/trident/magnetic_top.jpg)

Having to screw and unscrew the panels when modding or messing around with the toolhead got old fast.
Therefore I made the panels easily removable by using magnets and snap latches.

The top is completely magnetic using the [Magnetic panels with Magnet Inserts][] mod and is very easy to remove and replace.

![Installation of the corner magnets.](/images/trident/corner_jig.jpg)

I played around with the amazing [snap latches][] mod to hold the panels together:

![The latch closes with a very satisfying thud.](/images/trident/snap_latch.jpg)

But they're a bit cumbersome to lock and unlock, so I compromised and used the latches in the middle of the side panels and used magnets for the corners:

![](/images/trident/magnetic_side.jpg)

I also made the bottom panel magnetic using [the bottom panel mag clip][] mod:

[snap latches]: https://mods.vorondesign.com/detail/9Rdnf5vD2oaJLmR7BpAuQ "Printable snap latches for 2020 extrusion"
[the bottom panel mag clip]: https://mods.vorondesign.com/detail/mRnQfulRJGN3pfPBbSjzA "Bottom Panel Mag Clip"
[Magnetic panels with Magnet Inserts]: https://mods.vorondesign.com/detail/GawFyXN2J0rlSecCAJUpZQ "Magnetic panels with Magnet Inserts"

![](/images/trident/magnetic_bottom.jpg)

# Angry cam

![](/images/trident/angrycam_mount.jpg)

TODO HA screnshot

<https://mods.vorondesign.com/detail/RYpQW53mtem8Nj1JKqiSQ>

# Purge bucket

The kit comes with a steel brush and references the [Decontaminator Purge Bucket & Nozzle Scrubber][purge] mod that I was quite excited for.

Unfortunately, Tap decreases the range of motion for the toolhead so that the nozzle no longer can reach back behind the bed:

![This is as far back the nozzle can go. As you can see, it doesn't reach the (now unused) z endstop, and there's no room for a purge bucket / nozzle scrubber.](/images/trident/noise_y_reach.jpg)

There are some things I could do:

- Ditch Tap and use Klicky probe instead.

- Replace the printed Tap with a CNC Tap.

  The Chaoticlab CNC Voron Tap v2 should save around 4mm in the y-axis while Vitalii's version should save around 1.4mm.

- [Sensorless XY homing][sensorless] might also give back some range.

- Moving the bed is a theoretical solution, but that seems difficult to me.

I bought a [Chaoticlab CNC Voron Tap][chaotic_tap], but had I known about the sensorless homing I might have tried that out first.

[sensorless]: https://docs.vorondesign.com/community/howto/clee/sensorless_xy_homing.html "Setting Up and Calibrating Sensorless XY Homing"
[chaotic_tap]: https://www.3djake.com/chaoticlab/cnc-voron-tap-black-v2

# Filament runout sensor

- BTT Smart filament sensor 2.0: https://www.3djake.com/bigtreetech/smart-filament-sensor-v20
- Mounting bracket: https://www.printables.com/model/683859-bigtreetech-smart-filament-sensor-v20-mounting-bra

<https://mods.vorondesign.com/detail/yrBU4iTiddQRSvLqSDWMuA>

<https://mods.vorondesign.com/detail/6QtRuihC2dy6oBljKYymw>


# Flex plate stops

<https://www.printables.com/model/411428-voron-24-flex-plate-stops>

# Gridfinity mounts

[Noctua FN-A6x25]: https://noctua.at/en/nf-a6x25-flx
[4pin]: https://www.nicksherlock.com/2022/01/driving-a-4-pin-computer-pwm-fan-on-the-btt-octopus-using-klipper/
[noctua-pins]: https://faqs.noctua.at/en/support/solutions/articles/101000081757
[nevermore-trident]: https://www.ldomotion.com/p/guide/Nevermore-V5-Duo--Trident
[purge]: https://github.com/VoronDesign/VoronUsers/tree/master/orphaned_mods/printer_mods/edwardyeeks/Decontaminator_Purge_Bucket_%26_Nozzle_Scrubber
[inverted electronics bay mod]: https://github.com/VoronDesign/VoronUsers/tree/master/printer_mods/LoganFraser/TridentInvertedElectronics
[RockNRoll]: https://mods.vorondesign.com/detail/tiIhFDTh9tHJY0JNJK9A
[rock-stilts]: https://www.printables.com/model/638776-voron-rocknroll-mod-stilts/files
