---
{
  "name": "camera_snap",
  "description": "Take a photo with the camera and save it. Requires a camera device.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# Camera Snap

Use this skill when the user wants to take a photo, capture an image, snap a picture, or use the camera to take a shot.

Requires a camera device configured in the board.

## Usage

Tool call:
```json
{"path":"{CUR_SKILL_DIR}/scripts/camera_snap.lua","args":{}}
```

## Output

The script will:
1. Open the camera with JPEG format at 1920x1080 (or nearest supported resolution)
2. Capture one frame
3. Save it to `/fatfs/snap_<timestamp>.jpg`
4. Return the file path

## Example Response

After running the script, you can:
- Send the file path to the user
- Use the IM capability to send the image file
- Display it on screen if available

## Error Handling

If the camera is not available or capture fails, the script will return an error message. Report this to the user.
