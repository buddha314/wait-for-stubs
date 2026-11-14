# Stream bending (add-stream-building spikes 1.1–1.3, 2026-11-13)

**1.1 Asset Library re-check.** No maintained Godot 4 addon bends an authored,
multi-material glTF along a `Curve3D` and keeps its blend shapes:
- Line3D (GDExtension) and CurveMesh3D generate tubes; they don't deform a mesh.
- MeshCurver is listed for Godot 3.1.
- godot-deformablemesh is a deformer stack, not a curve follower.
- Goshapes extrudes profiles along `Path3D`; its last release is 2023.

So design D4 stands: we bend on the CPU (`scenes/stream/stream_bender.gd`).

**1.2 Bending.** Blend shapes survive. The staff lines keep `WaveSin`/`WaveCos`
(`surface_get_blend_shape_arrays` bent with the same frames; the mode is read per
mesh, normalized or relative). Measured headless on this machine (GDScript):

| Work | Time |
| --- | --- |
| plan + hologram, 2 segments | ~4.6 ms |
| plan + hologram, 8 segments | ~8.1 ms |
| chevron scroll (re-bend of the `Flow` pieces), 8 segments | ~0.4 ms per frame |

That misses the 2 ms target. Sharing one frame cache per path across all pieces didn't
change much: the cost is the per-vertex GDScript loops. Mitigation shipped: the
builder re-plans at most every 0.1 s and only when the aim moves 25 cm or more. A
laid stream is bent once. If it shows up in play, move `bend_mesh` into C++ (it's a
pure function of arrays and frames).

Parts that ship hidden at scale 0 (the port halos) are baked at scale 1 and shown or
hidden, rather than baked to nothing.

**1.3 Frame stability.** The frame is built horizontally: the flattened tangent, Y up,
and side = tangent × up. `sample_baked_with_transform` isn't used, so no plan within
the bend limit can flip it. Alpha sorting at joins still needs checking in a window.
