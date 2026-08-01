-- Catppuccin Mocha, the same theme as WezTerm, Zellij and tmux.
--
-- Declared as a plugin spec rather than as a lazyvim.json extra on purpose:
-- mixing the two models makes :LazyExtras refuse to manage anything that was
-- imported by hand.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        blink_cmp = true,
        which_key = true,
        snacks = true,
      },
    },
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
