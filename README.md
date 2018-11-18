# mpv-pdf
A script for the MPV media player that allows you to view PDFs by way of [ImageMagick](https://www.imagemagick.org/).  To improve load times and keep mpv responsive, pages are pre-rendered asynchronously and *by default*, only two pages ahead of the current page are pre-rendered.

## Dependancies
- MacOS, Linux, \*BSD, etc **(Windows is NOT currently supported, but PRs are welcome)**
- [ImageMagick](https://www.imagemagick.org/)
- [pdfinfo](https://linux.die.net/man/1/pdfinfo)
*(Install ImageMagick and `pdfinfo` using your package manager.   `convert`, provided by ImageMagick, should be in your $PATH.)*


## Installation
    make install
or
	cp pdf_hook.lua ~/.config/mpv/scripts/
	cp pdf_hook-worker.lua ~/.config/mpv/scripts/pdf_hook-worker-1.lua
	cp pdf_hook-worker.lua ~/.config/mpv/scripts/pdf_hook-worker-2.lua
    [...]

**NOTE:**

**For every additional copy of pdf\_hook-worker.lua you copy into ~/.config/mpv/scripts, *mpv-pdf* will render an additional page ahead of the current page.  E.g. 10 copies of pdf\_hook-worker.lua will have *mpv-pdf* render 10 pages ahead.**

## Recommended Configuration

It's highly recommended that *mpv-pdf* be used in conjunction with [mpv-image-viewer](https://github.com/occivink/mpv-image-viewer) or a similar userscript.   This will allow panning, zooming, etc of PDF pages (which are displayed through mpv as jpgs.)

## Technical Details
*mpv-pdf* displays a PDF page by first using ImageMagick's `convert` to render it as a jpg.

It accomplishes this by first reading the number of pages from the pdf using `pdfinfo`, then for each page it generates a playlist entry of the form `pdf://path/to/your.pdf[page]`.  These pdf page playlist entries are also handled by pdf\_hook.lua, which dispatches an asynchronous rendering task for each to one of the pdf\_hook-worker's.  To keep things responsive and to avoid rendering pages unnecessarily, an async rendering task is dispatched for the current page, and an additional rendering task is dispatched for each additional pdf\_hook-worker script you've installed.

Until an asynchronous task returns, a placeholder image is shown.  This code is [subject to future change](https://github.com/libass/libass) but currently the placeholder image is generated using ImageMagick as a blank white jpg with the pixel dimensions of the PDF, as computed from `pdfinfo`.

jpgs produced by *mpv-pdf* are located in `/tmp/mpv-pdf/`.  If your OS doesn't periodically clean `/tmp/`, this could get large...

## Plans for Future Enhancement
- [x] ~~Asynchronous generation of pages~~
- [ ] Use LibASS to generate the page placeholder
- [ ] Spawn asynchronous sub-scripts programmatically
- [ ] Use pandoc to support more file formats (e.g. docx)
- [ ] Support text search of the PDF
- [ ] Use text-to-speech to generate sound files for each page.
- [ ] Re-render PDF pages at different DPI's depending on the zoom setting.
