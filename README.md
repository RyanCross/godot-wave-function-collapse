# Function
This repository provides a 2D node: `TerrainGenerator`, that accepts an input Godot node: `TileMap`, of `[width, height]`. It then uses this to generate a random similar TileMap. It uses an implementation of Wave Function Collapse (hereby WFC) that I wrote from scratch for the Godot4 Engine.

The impl was largely inspired by [this](https://robertheaton.com/2018/12/17/wavefunction-collapse-algorithm/) blog post written by Robert Heaton, who describes an implementation of WFC known as the *Even Simpler Tiled Model*, or ETSM.

# Disclaimer
This implementation was done as a learning exercise, with two goals in mind: 
1. To perform the simplest terrain generation possible in Godot with an ETSM implementation. 
2. To gain a better conceptual understanding of the algorithm by implementing on my own, using the [spec](https://github.com/mxgmn/WaveFunctionCollapse?tab=readme-ov-file).

As such, the code is not particularly efficient or well-optimized, and it lacks the sophistication of more complex WFC implementations. However, it's well documented, and it's simplicity makes it a great learning tool for those interested in WFC or are wanting to learn more about terrain generation.  It's also easy to use, so it's a great source if you just want to create some simple tilemaps for your game project.

# Usage

## Sample Map Constraints
This implementation supports processing input TileMaps whose rects occupy positive space, as such, they should be drawn such that all cells x and y coordinates are >= 0.
