### Installation

#### LazyVim

Lazy.nvim will clone your repository, run the setup function, and your commands (e.g., :TodoPanel, :TodoStatus, :TodoComment) will be available.

```lua
-- In your lazy.nvim config file:
{
  "adam-baker/vimtaskie.nvim",
  config = function()
    require("vimtaskie.nvim").setup()
  end,
}
```
