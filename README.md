# smarten.nvim

A smarter n/N: use one set of keys to traverse many lists.

## Setup

Call `require("smarten").setup(opts)`. See config for supported options.

Simple (default) example with Lazy:

```lua
{
  "liamvdvyver/smarten.nvim",
  opts = {},
}
```

To change options/map keys:

```lua
{
  "liamvdvyver/smarten.nvim",
  opts = {
    smart_unimpaired = true,

    -- Default maps dynamically set by smarten
    keys = {
      next = {"n"},
      prev = {"N"},
    }
  },
  config = function(_, opts)
    local smarten = require("smarten")
    smarten.setup(opts)

    -- Or manually set maps
    vim.keymap.set("n", "<C-n>", smarten.next, { desc = "[n]ext item" })
    vim.keymap.set("n", "<C-p>", smarten.prev, { desc = "[p]previous item" })
  end
}
```

## Usage

Set maps through the `keys` option, or call `require("smarten").next()`/`require("smarten").prev()`

> [!WARNING]
> Some keys such as `n`/`N` (default) cannot be mapped to `require("smarten").next()`/`require("smarten").prev()` and must be mapped dynamically to avoid recursive behaviour.

To go to the next/previous item from the current list, use `require("smarten").next()`/`require("smarten").prev()`, or the keys specified in `keys`.

The current lists of items are supported:


|List|Invocation|
|----|----------|
|Search results|`/`, `?`, `*`, `#`, `n`, `N`|
|Quickfix list| `]q`, `[q`, Opening/navigating to `qf` buffer|
|Location list|`]l`, `[l`|
|Buffers|`]b`, `[b`|
|Tabs|Enter tab page|
|Tags|`]t`, `[t`|
|Diagnostics|`]d`, `[d`|


If the `smart_unimpaired` option is set, corresponding next/previous maps are inferred from the usage of any map starting with `]` or `[`.

## Config

The following options are supported:

|Key|Type|Behaviour|Default|
|---|-----|---------|-------|
|`smart_unimpaired`|`boolean`|Infer unimpairsed-style maps automatically.|`true`|
|`keys`|`{next: string[], prev: string[]}`|Keys to dynamically remap to traverse the current list.|`{next = {"n"}, prev = {"N"}}`|
