-- pdf_hook.lua
--
-- view PDFs in mpv by using ImageMagick to convert PDF pages to images
--
-- Dependancies:
--  * Linux / Unix / OSX  (windows support should be possible, but I can't test it.)
--  * ImageMagick (`convert` must be in the PATH)
--  * pdfinfo
--
-- Notes: jpegs are generated for each page and are placed in /tmp/mpv-pdf/.
--        If your OS doesn't periodically clean /tmp/, this could get large...
--
--        Use of an mpv-image-viewer is recommended for panning/zooming.
--
-- Is this userscript a weird joke?  To be honest I'm not really sure anymore.

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local opts = {
    --TODO use pandoc to support more file formats?
    density=150,
    quality=50,
    supported_extensions=[[
    ["pdf"]
    ]]
}
(require 'mp.options').read_options(opts)
opts.supported_extensions = utils.parse_json(opts.supported_extensions)

local function exec(args)
    local ret = utils.subprocess({args = args})
    return ret.status, ret.stdout, ret, ret.killed_by_us
end

local function findl(str, patterns)
    for i,p in pairs(patterns) do
        if str:find("%."..p.."$") then
            return true
        end
    end
    return false
end

generators = {}
mp.register_script_message("pdf-page-generator-broadcast", function(generator_name)
    for _, g in ipairs(generators) do
        if generator_name == g then return end
    end
    generators[#generators + 1] = generator_name
end)

mp.register_script_message("pdf-page-generator-return", function(failed, from, to)
    if failed == "true" then
        msg.error("generator was killed..: "..from .. " to: " .. to)
        outstanding_tasks[from] = nil
        return
    end
    completed_tasks[from] = to;
    outstanding_tasks[from] = nil

    if mp.get_property("playlist/"..mp.get_property("playlist-pos").."/filename") == from then
        -- append new jpg to playlist, reorder it, then delete the current playlist entry
        mp.commandv("loadfile", to, "append")
        mp.commandv("playlist-move", mp.get_property("playlist-count")-1, mp.get_property("playlist-pos")+1)
        mp.commandv("playlist-remove", mp.get_property("playlist-pos"))
    end
end)

placeholder=nil
next_generator=1
outstanding_tasks={}
completed_tasks={}
local function request_page(url)
    if completed_tasks[url] then return completed_tasks[url] end
    if outstanding_tasks[url] then return placeholder end


    mp.commandv("script-message-to", generators[next_generator], "generate-pdf-page", url, tostring(opts.density), tostring(opts.quality))
    outstanding_tasks[url] = generators[next_generator]

    next_generator = next_generator + 1
    if next_generator > #generators then next_generator = 1 end
    return placeholder
end

local function prefetch_pages()
    local urls = {}

    for i=mp.get_property("playlist-pos"), mp.get_property("playlist-count")-1,1 do
        url = mp.get_property("playlist/"..i.."/filename")
        if url:find("pdf://") == 1 then
            urls[#urls+1] = url
        end
    end

    for i=1,math.min(#generators,#urls),1 do
        request_page(urls[i])
    end
end

mp.add_hook("on_load", 10, function ()
    local url = mp.get_property("stream-open-filename", "")
    msg.debug("stream-open-filename: "..url)

    if (url:find("pdf://") == 1) then
        mp.set_property("stream-open-filename", request_page(url)) --swap in jpg (or placeholder)
        prefetch_pages()
        return
    end


    if (findl(url, opts.supported_extensions) == false) then
        msg.debug("did not find a supported file")
        return
    end

    -- get pagecount
    local pdfinfo = "pdfinfo"
    local stat,out = exec({pdfinfo, url})
    local num_pages = string.match(out, "Pages:%s+(%d+)")
    local page_size_x = string.match(out, "Page size:%s+(%d+.*%d*) x %d+.*%d*%s+pts") / 72 * opts.density
    local page_size_y = string.match(out, "Page size:%s+%d+.*%d* x (%d+.*%d*)%s+pts") / 72 * opts.density
    local size_str = tostring(page_size_x).."x"..tostring(page_size_y)

    placeholder="/tmp/mpv-pdf/placeholder-"..size_str..".jpg"
    exec({"convert",
        "-size", size_str,
        "canvas:white",
        placeholder})

    --build pdf:// playlist
    local playlist = {"#EXTM3U"}
    for i=0,num_pages-1,1 do
        table.insert(playlist, "#EXTINF:0,Page "..i)  --TODO use 'real' page numbers e.g. 'ix', 'Cover', etc
        table.insert(playlist, "pdf://"..url.."["..i.."]")  --playlist entry has the page number on it, used by `convert`
    end

    --load playlist
    if #playlist > 0 then
        mp.set_property("stream-open-filename", "memory://" .. table.concat(playlist, "\n"))
    end

    return
end)
