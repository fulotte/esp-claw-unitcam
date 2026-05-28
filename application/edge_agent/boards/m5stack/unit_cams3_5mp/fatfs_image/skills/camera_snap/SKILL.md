---
{
  "name": "camera_snap",
  "description": "Capture a 5MP photo from the Unit CamS3-5MP OV5640 camera and save it as JPEG. Requires camera device.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# Camera Snap (5MP)

Use this skill when the user asks to take a photo, capture a picture, snap an image,
or save a camera still. This skill is optimized for the Unit CamS3-5MP board with
OV5640 5MP sensor.

Run exactly one script with `lua_run_script` after reading `board_hardware_info`.

If `lua_run_script` returns an error, report that error directly to the user.
Do not retry with changed arguments or run another camera script in the same turn
unless the user explicitly asks.

## Script Args Schema

`json
{
  "type": "object",
  "properties": {
    "filename": {
      "type": "string",
      "default": "camera_snap.jpg",
      "description": "JPEG filename to create under the storage root or under dir."
    },
    "dir": {
      "type": "string",
      "default": "",
      "description": "Optional single directory name under the storage root."
    },
    "width": {
      "type": "integer",
      "default": 2592,
      "minimum": 1,
      "description": "Requested capture width. Snapped to nearest supported size."
    },
    "height": {
      "type": "integer",
      "default": 1944,
      "minimum": 1,
      "description": "Requested capture height. Snapped to nearest supported size."
    },
    "timeout_ms": {
      "type": "integer",
      "default": 5000,
      "minimum": 0
    },
    "skip_frames": {
      "type": "integer",
      "default": 3,
      "minimum": 0,
      "description": "Number of warm-up frames to discard before saving the photo."
    }
  }
}
`

Path rules:
- `filename` must be a simple `.jpg` or `.jpeg` filename.
- `filename` must not contain `/`, `\`, or `..`.
- `dir` is optional and must be a single directory name under the storage root.
- `dir` must not contain `/`, `\`, or `..`.

## Tool Call Inputs

Take a 5MP photo with the default output name:

`json
{"path":"{CUR_SKILL_DIR}/scripts/camera_snap.lua","args":{}}
`

Take a photo with a custom filename:

`json
{"path":"{CUR_SKILL_DIR}/scripts/camera_snap.lua","args":{"filename":"photo.jpg"}}
`

Take a photo into a storage-root-relative directory:

`json
{"path":"{CUR_SKILL_DIR}/scripts/camera_snap.lua","args":{"dir":"photos","filename":"latest.jpg","timeout_ms":5000}}
`

Take a lower-resolution photo:

`json
{"path":"{CUR_SKILL_DIR}/scripts/camera_snap.lua","args":{"width":1920,"height":1080,"filename":"hd.jpg"}}
`

## Recommended Flow

1. Activate the `board_hardware_info` skill and confirm that a `camera` device is listed.
2. If no camera is listed, tell the user that the board does not declare a camera and stop.
3. Choose a safe filename. Use the default unless the user requested a specific output name.
4. Run `{CUR_SKILL_DIR}/scripts/camera_snap.lua` with the selected `args`.
5. Report the saved path, byte count, resolution, pixel format, skipped warm-up frames,
   and any error directly from the script output.
