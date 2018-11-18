local utils = require 'mp.utils'
local msg = require 'mp.msg'

local function exec(args)
    local ret = utils.subprocess({args = args, cancellable=false})
    return ret.status, ret.stdout, ret, ret.killed_by_us
end

mp.register_script_message("generate-pdf-page", function(url, density, quality)
    local input  = string.gsub(url, "pdf://", "")
    local output =  "/tmp/mpv-pdf/" .. string.gsub(input, "/", "|")..".jpg"
    exec({"mkdir", "-p", "/tmp/mpv-pdf/"}) --TODO make tmp directory configurable

    --convert pdf page to jpg
    stat,out,ret,killed = exec({"convert",
        "-density", density, --PPI
        "-quality", quality, -- jpg compression quality
        input, output})

    mp.commandv("script-message", "pdf-page-generator-return", tostring(killed or stat ~= 0), url, output )
end)

mp.commandv("script-message", "pdf-page-generator-broadcast", mp.get_script_name())
