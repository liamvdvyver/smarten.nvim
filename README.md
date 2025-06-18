# smarten.nvim

A smarter next/previous.

Still in early development, issues are very welcome, for bug or ideas.

## Installation

Make sure to call `require("smarten").setup(opts)`.

E.g. with Lazy:

```lua
{
  "liamvdvyver/smarten.nvim",
  opts = {
    -- Only one setting for now, see usage for more detail
    -- Defaults to true
    smart_unimpaired = true
  },
  config = function(_, opts)
    local smarten = require("smarten")
    smarten.setup(opts)

    -- Set some keymaps
    vim.keymap.set("n", "<C-n>", smarten.next, { desc = "[n]ext item" })
    vim.keymap.set("n", "<C-p>", smarten.prev, { desc = "[p]previous item" })
  end
}
```

## Usage

To go to the next/previous item from the current list, use `require("smarten").next()`/`require("smarten").prev()`.

Currently, list detection and next/previous commands work the following way:

* At startup, it is search: (`n`/`N`)
* On search keys (`/`, `?`, `*`, `#`, `n`, `N`) search is selected. Note: the
plugin detects these keys within remaps as well, which has led to a few bugs in development. If you find the search list being re-selected unexpectedly, please open an issue!
* On opening/entry into a quickfix window, the quickfix list is selected. To
select a particular quickfix list, just make sure it is the most recently opened.
* Unimpaired-style mappings (e.g. `]q`) are supported in two ways:
    * Detect any `[`/`]` followed by an alphabetic character, and set
    next/previous dynamically. Similar, will detect `[` or `]` inside of a normal remap.
    * Only support those built in to vim. Set `smart_unimpaired` to `false` to
    use this behaviour instead.

## TODO

[x] Switch to search on search keys/next/previous
[x] Switch to quickfix list on generation/open/entry
[x] Switch to other list when unimpaired-style mapping is used
[] Add support for custom user-defined lists
[] Add quirks to issues (I'm on a plane right now and don't have internet)

## Quirks

The plugin is still quite new, here are know issues/shortcomings:

* There is no easy way I know of to hook into Ex commands such as `cnext` to update the active list.
* It would be better to switch to a search on (`/`/`?`) only if the user hits `<CR>` after to initiate the search.
* Currently to detect if if a buffer is a quickfix list, the plugin checks if the `filetype` option equals `"qf"`. Since the filetype option for a location list is also set to `"qf"` it doesn't work well with the location list, and will usually set the active list to the quickfix list. This doesn't apply to unimpaired style mappings `[L` or `]L`, which work fine.
* If you want to remap `<C-n>` or `<C-p>` like the example, it will interfere with hardtime.nvim.
* If you try to remap `n` or `N` (the original idea), then when a search is performed, ":normal n" is recursive. I'm not yet aware of another way to go to the next search result that isn't janky.
