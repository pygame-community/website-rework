---
title: 'Performance Comparisons Against the Original Pygame'
author: 'Starbuck5'
pubDate: 'November 03 2025'
heroImage: '../../assets/blog-placeholder-5.jpg'
---

## Introduction

This page exists to showcase the efforts of the pygame-ce development team in the area
of runtime performance. This page focuses on performance increases for classic pygame
functions, not performance increases pygame-ce users can get from new APIs-- although
those also exist. For example, the new
[Surface.fblits](https://pyga.me/docs/ref/surface.html#pygame.Surface.fblits)
function, which allows blitting a sequence of Surfaces more rapidly than `blits`
(trading some flexibility for speed). Performance showcases compare against the
pygame library.

## Vectors

In pygame and pygame-ce, the Vector2/3 classes are written in C. So whenever
something needs to happen in a Vector, the input needs to be converted from Python
objects into C types. In pygame-ce we've optimized that process in a few places,
so it will be faster to create a Vector, use Vector methods that take Vector-like
inputs, or do math between Vectors and scalar numbers. See
[#3458](https://github.com/pygame-community/pygame-ce/pull/3458),
[#3454](https://github.com/pygame-community/pygame-ce/pull/3454), or
[#2443](https://github.com/pygame-community/pygame-ce/pull/2443).

We have done microbenchmarks in those PRs, but do these optimizations hold up in
something more involved? I wrote a Vector2-based particle simulation with 30000
particles to test it out. When visualized, it looks like this--

![Vector simulation](https://github.com/user-attachments/assets/879ffead-2a5a-4c12-9b5d-e293a098bd9a)

<details>
<summary> Vector simulation script </summary>

```py
import random
import itertools
import time

import pygame

# SETTINGS
WIDTH = 500
HEIGHT = 500
ENABLE_VISUALIZATION = False

# Set seed for consistent re-runs
random.seed(46)

if ENABLE_VISUALIZATION:
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    point_color = pygame.Color("red")

anchors_to_points: dict[tuple[int, int], list[pygame.Vector2]] = dict()
# Grab a bunch of random points before benchmark starts, we want to benchmark
# pygame.math, not random.
random_points = [
    (random.randint(0, WIDTH), random.randint(0, HEIGHT)) for _ in range(30000)
]

start = time.time()

# Setup base conditions. This is part of the benchmark because it involves
# constructing vectors.
for _ in range(5):
    anchors_to_points[random_points.pop(0)] = []
key_iter = itertools.cycle(anchors_to_points.keys())
while random_points:
    anchors_to_points[next(key_iter)].append(pygame.Vector2(random_points.pop()))

any_alive = True
while any_alive:
    any_alive = False
    for anchor, points in anchors_to_points.items():
        for point in points:
            point_relative_to_anchor = point - anchor
            distance_from_anchor = point_relative_to_anchor.length()

            if ENABLE_VISUALIZATION:
                pygame.draw.circle(
                    screen,
                    point_color.lerp(
                        "blue", pygame.math.clamp(distance_from_anchor / 200, 0, 1)
                    ),
                    point,
                    3,
                )

            if distance_from_anchor > 0.0:
                any_alive = True

            point_speed = ((point_relative_to_anchor.angle_to((1, 1)) % 90) + 90) / 15
            point.move_towards_ip(anchor, point_speed)

    if ENABLE_VISUALIZATION:
        pygame.event.get()
        pygame.display.flip()
        screen.fill("black")

print("Vector simulation finished in", time.time() - start, "seconds")
```

</details>

|           | Time to complete (lower is better) |
| --------- | ---------------------------------- |
| pygame-ce | 2.4 seconds                        |
| pygame    | 2.9 seconds                        |

Note that these numbers are from runs without visualization enabled.

(This benchmark was run using pygame-ce 2.5.6, pygame 2.6.1, Python 3.11.9,
with a Ryzen 4800H on Windows 11)

## pygame.transform.scale

<details>
<summary> pygame.transform.scale </summary>

As of writing, the most recent release versions of `pygame-ce` (2.3.2) and `pygame` (2.5.2) were tested on Python 3.10, Python 3.11, and Python 3.12.

3 sizes of surface were created and randomly populated with pixels

- 10 x 10 pixels (SMALL)
- 100 x 100 pixels (MEDIUM)
- 1000 x 1000 pixels (LARGE)

6 scale factors were used

- 1.5 (XSMALL)
- 2 (SMALL)
- 5 (SUBMEDIUM)
- 10 (MEDIUM)
- 25 (SUPERMEDIUM)
- 50 (LARGE)

Each surface was scaled up by each scale factor 1,000 times and each iteration was timed with the `timeit` library. In the graphs below, some of the times have been filtered out according to the following rule:

Each data set is assumed to be normally distributed. Following that assumption, each data set had its mean (μ) and standard devation (σ) calculated. Any data points that lied outside of the closed interval [μ-2σ, μ+2σ] was assumed to be an outlier and was not plotted.

The tests were performed with a `main.py` script run for each python/pygame(-ce) version combo, and after all the test runs were done, `visualize.py` was run to create the graphs.

<details>

<summary>main.py</summary>

```python3
from timeit import repeat
from random import randint
from platform import python_version
from os.path import exists
from os import mkdir

import json

import pygame

def get_random_color() -> tuple[int, int, int]:
    r = randint(0, 255)
    g = randint(0, 255)
    b = randint(0, 255)

    return (r, g, b)

def fill_surf_with_random_pixels(surf: pygame.Surface) -> None:
    cols, rows = surf.get_size()

    for col in range(cols):
        for row in range(rows):
            surf.set_at((col, row), get_random_color())

pygame.init()

screen = pygame.display.set_mode((1, 1))

SMALL_SIZE = 10
MEDIUM_SIZE = 100
LARGE_SIZE = 1000

XSMALL_MULTIPLIER = 1.5
SMALL_MULTIPLIER = 2
SUBMEDIUM_MULTIPLIER = 5
MEDIUM_MULTIPLIER = 10
SUPERMEDIUM_MULTIPLIER = 25
LARGE_MULTIPLIER = 50

small_surf = pygame.Surface((SMALL_SIZE, SMALL_SIZE))
fill_surf_with_random_pixels(small_surf)

medium_surf = pygame.Surface((MEDIUM_SIZE, MEDIUM_SIZE))
fill_surf_with_random_pixels(medium_surf)

large_surf = pygame.Surface((LARGE_SIZE, LARGE_SIZE))
fill_surf_with_random_pixels(large_surf)

iterations = 1_000

def time_scale_with_multiplier(surf: pygame.Surface, multiplier: float) -> list[float]:
    print(f"Scaling a surface of size {surf.get_size()} by {multiplier}")
    new_width = surf.get_width() * multiplier
    new_height = surf.get_height() * multiplier

    return repeat(lambda : pygame.transform.scale(surf, (new_width, new_height)), repeat=iterations, number=1)

times = {
    "Small Surface": {
        "XSmall Multiplier": time_scale_with_multiplier(small_surf, XSMALL_MULTIPLIER),
        "Small Multiplier": time_scale_with_multiplier(small_surf, SMALL_MULTIPLIER),
        "SubMedium Multiplier": time_scale_with_multiplier(small_surf, SUBMEDIUM_MULTIPLIER),
        "Medium Multiplier": time_scale_with_multiplier(small_surf, MEDIUM_MULTIPLIER),
        "SuperMedium Multiplier": time_scale_with_multiplier(small_surf, SUPERMEDIUM_MULTIPLIER),
        "Large Multiplier": time_scale_with_multiplier(small_surf, LARGE_MULTIPLIER)
    },
    "Medium Surface": {
        "XSmall Multiplier": time_scale_with_multiplier(medium_surf, XSMALL_MULTIPLIER),
        "Small Multiplier": time_scale_with_multiplier(medium_surf, SMALL_MULTIPLIER),
        "SubMedium Multiplier": time_scale_with_multiplier(medium_surf, SUBMEDIUM_MULTIPLIER),
        "Medium Multiplier": time_scale_with_multiplier(medium_surf, MEDIUM_MULTIPLIER),
        "SuperMedium Multiplier": time_scale_with_multiplier(medium_surf, SUPERMEDIUM_MULTIPLIER),
        "Large Multiplier": time_scale_with_multiplier(medium_surf, LARGE_MULTIPLIER)
    },
    "Large Surface": {
        "XSmall Multiplier": time_scale_with_multiplier(large_surf, XSMALL_MULTIPLIER),
        "Small Multiplier": time_scale_with_multiplier(large_surf, SMALL_MULTIPLIER),
        "SubMedium Multiplier": time_scale_with_multiplier(large_surf, SUBMEDIUM_MULTIPLIER),
        "Medium Multiplier": time_scale_with_multiplier(large_surf, MEDIUM_MULTIPLIER),
        "SuperMedium Multiplier": time_scale_with_multiplier(large_surf, SUPERMEDIUM_MULTIPLIER),
        "Large Multiplier": time_scale_with_multiplier(large_surf, LARGE_MULTIPLIER)
    }
}

if not exists("raw_stats"):
    mkdir("raw_stats")

filename = f"raw_stats/({python_version()})"
if not hasattr(pygame, "IS_CE"):
    filename += "pygame-output.json"
else:
    filename += "pygame-ce-output.json"
with open(filename, "w") as dump_file:
    json.dump(times, dump_file, indent=4)
```

</details>

<details>

<summary>visualize.py</summary>

```python3
import json
from statistics import mean, stdev
from os.path import exists
from os import mkdir

import matplotlib.pyplot as plt

upstream_data = {}
ce_data = {}

def filter_outliers(data: list[float]) -> list[float]:
    data_mean = mean(data)
    data_sigma = stdev(data)

    filtered_data = [point for point in data if abs(point-data_mean) <= 2 * data_sigma]

    return filtered_data

if not exists("figures"):
    mkdir("figures")

for python_version in ["3.10.11", "3.11.5", "3.12.0"]:
    with open(f"raw_stats/({python_version})pygame-output.json", "r") as upstream:
        upstream_data = json.load(upstream)

    with open(f"raw_stats/({python_version})pygame-ce-output.json", "r") as ce:
        ce_data = json.load(ce)

    for size in ["Small", "Medium", "Large"]:
        for scale in ["XSmall", "Small", "SubMedium", "Medium", "SuperMedium", "Large"]:
            upstream = filter_outliers(upstream_data[f"{size} Surface"][f"{scale} Multiplier"])
            ce = filter_outliers(ce_data[f"{size} Surface"][f"{scale} Multiplier"])

            fig = plt.figure()
            fig.set_size_inches((fig.get_size_inches()[0], fig.get_size_inches()[1]+1))
            plt.plot(range(len(upstream)), upstream)
            plt.plot(range(len(ce)), ce)
            plt.legend(["Upstream Pygame 2.5.2", "Pygame-ce 2.3.2"])
            plt.xlabel("Iteration")
            plt.ylabel("time taken (seconds)")
            title = f"Pygame vs Pygame-ce pygame.transform.scale\n{python_version = }\n"
            match size:
                case "Small":
                    title += "10x10 pixel source surface, "
                case "Medium":
                    title += "100x100 pixel source surface, "
                case "Large":
                    title += "1000x1000 pixel source surface, "

            match scale:
                case "XSmall":
                    title += "1.5x scale"
                case "Small":
                    title += "2x scale"
                case "SubMedium":
                    title += "5x scale"
                case "Medium":
                    title += "10x scale"
                case "SuperMedium":
                    title += "25x scale"
                case "Large":
                    title += "50x scale"

            plt.title(title)
            plt.savefig(f"figures/{size}-{scale}.png")
            plt.close()
```

</details>

_note_: `visualize.py` has hardcoded python versions because that is what was installed on my system to use, and what `main.py` saved the files as. I could have written a parser for it to generalize, but I deemed that not worth the effort right now.

Now for the result graphs (names are in the format `${SURFACE_SIZE}-${SCALE_FACTOR}.png`)

<details>
  <summary>Small-XSmall.png</summary>

![Small-XSmall](https://github.com/pygame-community/pygame-ce/assets/49015102/1afe4f41-e4ba-4c21-9f35-3bf0fc09b967)

</details>

<details>
  <summary>Small-Small.png</summary>

![Small-Small](https://github.com/pygame-community/pygame-ce/assets/49015102/d1760259-4103-471d-9dad-fb906f18b331)

</details>

<details>
  <summary>Small-SubMedium.png</summary>

![Small-SubMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/033ce192-45bd-41bc-a93a-de5e828dadb9)

</details>

<details>
  <summary>Small-Medium.png</summary>

![Small-Medium](https://github.com/pygame-community/pygame-ce/assets/49015102/af8980e6-0abe-4e25-a4ba-2120d82c9572)

</details>

<details>
  <summary>Small-SuperMedium.png</summary>

![Small-SuperMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/5d8d10ab-d430-42c2-9840-13f0d1708623)

</details>

<details>
  <summary>Small-Large.png</summary>

![Small-Large](https://github.com/pygame-community/pygame-ce/assets/49015102/5545cac5-c290-45fa-8c45-1744703f561a)

</details>

<details>
  <summary>Medium-XSmall.png</summary>

![Medium-XSmall](https://github.com/pygame-community/pygame-ce/assets/49015102/be57211c-27f3-4b09-baa5-7094f4ebdda2)

</details>

<details>
  <summary>Medium-Small.png</summary>

![Medium-Small](https://github.com/pygame-community/pygame-ce/assets/49015102/805695d4-38ab-469d-bbcb-1e214d90ee7b)

</details>

<details>
  <summary>Medium-SubMedium.png</summary>

![Medium-SubMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/fd84032e-72d9-4256-aaab-4aa93bf99406)

</details>

<details>
  <summary>Medium-Medium.png</summary>

![Medium-Medium](https://github.com/pygame-community/pygame-ce/assets/49015102/b4d891c6-35ba-4018-a397-20d5e3d6e358)

</details>

<details>
  <summary>Medium-SuperMedium.png</summary>

![Medium-SuperMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/c950e703-b860-40c8-88bb-b9843882496e)

</details>

<details>
  <summary>Medium-Large.png</summary>

![Medium-Large](https://github.com/pygame-community/pygame-ce/assets/49015102/d5622c68-c5a6-4e6c-9095-86212456b350)

</details>

<details>
  <summary>Large-XSmall.png</summary>

![Large-XSmall](https://github.com/pygame-community/pygame-ce/assets/49015102/5eff211f-a9dd-49cf-b4c5-fe5b1d44f938)

</details>

<details>
  <summary>Large-Small.png</summary>

![Large-Small](https://github.com/pygame-community/pygame-ce/assets/49015102/3268e66f-fdf9-4b56-8482-bbc014d86074)

</details>

<details>
  <summary>Large-SubMedium.png</summary>

![Large-SubMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/be178ab9-03b2-44fa-a530-99c15bb152d0)

</details>

<details>
  <summary>Large-Medium.png</summary>

![Large-Medium](https://github.com/pygame-community/pygame-ce/assets/49015102/02ffa47f-b691-4a57-834a-e068529afbfa)

</details>

<details>
  <summary>Large-SuperMedium.png</summary>

![Large-SuperMedium](https://github.com/pygame-community/pygame-ce/assets/49015102/72b187bc-44dd-4993-8bc1-19d17a2df135)

</details>

<details>
  <summary>Large-Large.png</summary>

![Large-Large](https://github.com/pygame-community/pygame-ce/assets/49015102/2d43db7c-3662-4035-aa44-21b75decbad2)

</details>
</details>

## We've done lots more optimizations, so more sections coming in the future hopefully.
