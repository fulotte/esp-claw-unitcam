-- --------------------------------------------------------------
-- camera_snap.lua
-- Capture a 5MP JPEG still from the Unit CamS3-5MP (OV5640),
-- save it to storage, and return the file path.
-- --------------------------------------------------------------

local arg_schema = require("arg_schema")
local board_manager = require("board_manager")
local camera = require("camera")
local image = require("image")
local storage = require("storage")

-- Defaults
local DEFAULT_FILENAME   = "camera_snap.jpg"
local DEFAULT_DIR        = ""
local DEFAULT_TIMEOUT_MS = 5000
local DEFAULT_SKIP_FRAMES = 3
local DEFAULT_WIDTH      = 2592
local DEFAULT_HEIGHT     = 1944

-- Parse args
local function raw_arg(name, default)
    if type(args) == "table" and args[name] ~= nil then
        return args[name]
    end
    return default
end

local ARG_SCHEMA = {
    timeout_ms  = arg_schema.int({ default = DEFAULT_TIMEOUT_MS, min = 0 }),
    skip_frames = arg_schema.int({ default = DEFAULT_SKIP_FRAMES, min = 0 }),
    width       = arg_schema.int({ default = DEFAULT_WIDTH, min = 1 }),
    height      = arg_schema.int({ default = DEFAULT_HEIGHT, min = 1 }),
}

local ctx = arg_schema.parse(args, ARG_SCHEMA)
ctx.filename = raw_arg("filename", DEFAULT_FILENAME)
ctx.dir      = raw_arg("dir", DEFAULT_DIR)

-- Path validation
local function has_jpeg_suffix(path)
    local lower = string.lower(path)
    return string.sub(lower, -4) == ".jpg" or string.sub(lower, -5) == ".jpeg"
end

local function reject_path_part(name, value)
    if type(value) ~= "string" then
        error(name .. " must be a string")
    end
    if string.find(value, "%.%.", 1, false) then
        error(name .. " must not contain '..'")
    end
end

local function validate_filename(filename)
    reject_path_part("filename", filename)
    if filename == "" then
        error("filename must not be empty")
    end
    if string.find(filename, "/", 1, true) or string.find(filename, "\\", 1, true) then
        error("filename must not contain path separators")
    end
    if not has_jpeg_suffix(filename) then
        error("filename must end with .jpg or .jpeg")
    end
end

local function validate_dir(dir)
    reject_path_part("dir", dir)
    if string.find(dir, "/", 1, true) or string.find(dir, "\\", 1, true) then
        error("dir must be a single directory name under the storage root")
    end
end

local function build_save_path()
    validate_filename(ctx.filename)
    validate_dir(ctx.dir)

    local root = storage.get_root_dir()
    if ctx.dir == "" then
        return storage.join_path(root, ctx.filename)
    end

    local dir_path = storage.join_path(root, ctx.dir)
    if not storage.exists(dir_path) then
        storage.mkdir(dir_path)
    end
    return storage.join_path(dir_path, ctx.filename)
end

-- Cleanup
local camera_opened = false

local function cleanup()
    if camera_opened then
        local ok, err = pcall(camera.close)
        if not ok then
            print("[camera_snap] WARN: camera.close failed: " .. tostring(err))
        end
        camera_opened = false
    end
end

-- Run
local function run()
    -- 1. Get camera device path from board manager
    local camera_paths, path_err = board_manager.get_camera_paths()
    if not camera_paths then
        error("get_camera_paths failed: " .. tostring(path_err))
    end

    local save_path = build_save_path()

    -- 2. Open camera requesting 5MP JPEG with nearest-size snapping
    local opened, open_err = pcall(camera.open, camera_paths.dev_path, {
        format  = { "JPEG" },
        width   = ctx.width,
        height  = ctx.height,
        nearest = true,
    })
    if not opened then
        error("camera.open failed: " .. tostring(open_err))
    end
    camera_opened = true

    -- 3. Report actual stream info
    local stream = camera.info()
    print(string.format(
        "[camera_snap] camera stream: %dx%d format=%s",
        stream.width, stream.height, tostring(stream.pixel_format)
    ))

    -- 4. Flush stale buffers
    camera.flush()

    -- 5. Skip warm-up frames for better auto-exposure
    for i = 1, ctx.skip_frames do
        local warmup_frame <close> = camera.get_frame(ctx.timeout_ms)
        local wi = warmup_frame:info()
        print(string.format(
            "[camera_snap] skipped warm-up frame %d/%d: %dx%d format=%s",
            i, ctx.skip_frames, wi.width, wi.height, tostring(wi.pixel_format)
        ))
    end

    -- 6. Capture the actual photo
    local frame <close> = camera.get_frame(ctx.timeout_ms)
    local frame_info = frame:info()

    -- 7. Save to storage
    image.save_file(save_path, frame)

    local saved_info, stat_err = storage.stat(save_path)
    if not saved_info then
        error("storage.stat failed after save: " .. tostring(stat_err))
    end

    print(string.format(
        "[camera_snap] saved: path=%s bytes=%d frame=%dx%d format=%s",
        save_path, saved_info.size,
        frame_info.width, frame_info.height,
        tostring(frame_info.pixel_format)
    ))

    return {
        success = true,
        path    = save_path,
        width   = frame_info.width,
        height  = frame_info.height,
        bytes   = saved_info.size,
        format  = tostring(frame_info.pixel_format),
    }
end

-- Execute
local ok, result = xpcall(run, debug.traceback)
cleanup()

if not ok then
    print("[camera_snap] ERROR: " .. tostring(result))
    error(result)
end

print(string.format(
    "[camera_snap] done! %s (%dx%d, %d bytes)",
    result.path, result.width, result.height, result.bytes
))

return result
