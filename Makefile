install:
	cp pdf_hook.lua ~/.config/mpv/scripts/
	cp pdf_hook-worker.lua ~/.config/mpv/scripts/pdf_hook-worker-1.lua
	cp pdf_hook-worker.lua ~/.config/mpv/scripts/pdf_hook-worker-2.lua

test:
	mpv history-of-ball-bearings.pdf
