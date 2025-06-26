# smarten.nvim

A smarter next/previous.

Still in early development, issues are very welcome, for bug or ideas.

## Setup

Make sure to call `require("smarten").setup(opts)`.

E.g. with Lazy:

```lua
{
  "liamvdvyver/smarten.nvim",
  opts = {
    smart_unimpaired = true,

    -- Maps dynamically set by smarten
    keys = {
      next = "n",
      prev = "N",
    }
  },
  config = function(_, opts)
    local smarten = require("smarten")
    smarten.setup(opts)

    -- Or manually set maps
    -- WARNING: some keys such as n/N must be set dynamically. See config for more info.
    vim.keymap.set("n", "<C-n>", smarten.next, { desc = "[n]ext item" })
    vim.keymap.set("n", "<C-p>", smarten.prev, { desc = "[p]previous item" })
  end
}
```

## Config

* `smart_unimpaired`: whether to infer corresponding normal mode maps from any unimpaired style maps (default: `true`)
* `keys`: a table with entries `next` and `prev`. Each is a string or list of strings with keys to dynamically map. When mapping `smarten.next()`/`.prev()` to keys which are themselves used to traverse a list, they can trigger recursive behaviour. This is avoided by letting smarten remap the keys dynamically.

## Usage

To go to the next/previous item from the current list, use `require("smarten").next()`/`require("smarten").prev()`, or the keys specified in `keys`.

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
