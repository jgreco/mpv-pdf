-- pdf_hook.lua
--
-- BETA: view PDFs in mpv by using ImageMagick to convert PDF pages to images
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

local utils = require 'mp.utils'
local msg = require 'mp.msg'

local opts = {
    --TODO use pandoc to support more file formats?
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

mp.add_hook("on_load", 10, function ()
    local url = mp.get_property("stream-open-filename", "")
    msg.debug("stream-open-filename: "..url)

    if (url:find("pdf://") == 1) then
        local convert = "convert" --TODO find ImageMagick's `convert` if not in PATH
        local input  = string.gsub(url, "pdf://", "")
        local output =  "/tmp/mpv-pdf/" .. string.gsub(input, "/", "|")..".jpg"
        exec({"mkdir", "-p", "/tmp/mpv-pdf/"}) --TODO make tmp directory configurable
        
        --convert pdf page to png
        stat,out = exec({convert,
            --TODO move these options to config, and pick sensible defaults
            "-density", "150", --PPI
            "-quality", "50", -- jpg compression quality
            input, output})

        mp.set_property("stream-open-filename", output) --swap in png
        return
    end


    if (findl(url, opts.supported_extensions) == false) then
        msg.debug("did not find a supported file")
        return
    end

    -- get pagecount
    local pdfinfo = "pdfinfo" -- TODO find `pdfinfo` if not in PATH
    local stat,out = exec({pdfinfo, url})
    local num_pages = string.match(out, "Pages:%s*(%d*)")

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
