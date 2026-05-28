local board_manager = require("board_manager")
local camera = require("camera")
local image = require("image")
local storage = require("storage")

local TAG = "[camera_snap]"
local FRAME_TIMEOUT_MS = 5000

local camera_started = false

local function cleanup()
    if camera_started then
        pcall(camera.close)
        camera_started = false
    end
end

-- Get camera device path
local camera_paths, path_err = board_manager.get_camera_paths()
if not camera_paths then
    print(TAG .. " ERROR: get_camera_paths failed: " .. tostring(path_err))
    return { success = false, error = "Camera not available: " .. tostring(path_err) }
end

print(TAG .. " Opening camera at: " .. camera_paths.dev_path)

-- Open camera with JPEG format, prefer high resolution
local ok, err = pcall(camera.open, camera_paths.dev_path, {
    format = { "JPEG", "MJPG", "RGBP", "YUYV" },
    width = 1920,
    height = 1080,
    nearest = true,
})

if not ok then
    print(TAG .. " ERROR: camera.open failed: " .. tostring(err))
    return { success = false, error = "Failed to open camera: " .. tostring(err) }
end

camera_started = true

local stream = camera.info()
print(string.format("%s Camera opened: %dx%d format=%s",
    TAG, stream.width, stream.height, tostring(stream.pixel_format)))

-- Capture one frame
local frame <close> = camera.get_frame(FRAME_TIMEOUT_MS)
if not frame then
    print(TAG .. " ERROR: Failed to capture frame")
    cleanup()
    return { success = false, error = "Failed to capture frame" }
end

local info = frame:info()
print(string.format("%s Captured frame: %dx%d %s bytes=%d",
    TAG, info.width, info.height, tostring(info.pixel_format), info.bytes))

-- Generate filename with timestamp
local timestamp = os.time()
local filename = string.format("snap_%d.jpg", timestamp)
local filepath = storage.join_path("/fatfs", filename)

-- Convert to JPEG if needed, otherwise save directly
local save_ok, save_err
if info.pixel_format == "JPEG" or info.pixel_format == "MJPG" then
    -- Already JPEG, save directly
    local file = io.open(filepath, "wb")
    if not file then
        print(TAG .. " ERROR: Failed to open file for writing: " .. filepath)
        cleanup()
        return { success = false, error = "Failed to create file" }
    end
    
    local data = frame:data()
    file:write(data)
    file:close()
    save_ok = true
else
    -- Convert to JPEG first
    local jpeg_frame <close> = image.convert(frame, image.JPEG)
    if not jpeg_frame then
        print(TAG .. " ERROR: Failed to convert to JPEG")
        cleanup()
        return { success = false, error = "Failed to convert to JPEG" }
    end
    
    save_ok, save_err = pcall(image.save_file, filepath, jpeg_frame)
end

if not save_ok then
    print(TAG .. " ERROR: Failed to save image: " .. tostring(save_err))
    cleanup()
    return { success = false, error = "Failed to save image: " .. tostring(save_err) }
end

print(TAG .. " Image saved to: " .. filepath)

-- Cleanup
cleanup()

-- Return success with file path
return {
    success = true,
    filepath = filepath,
    filename = filename,
    width = info.width,
    height = info.height,
    size = info.bytes
}
