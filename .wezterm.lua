local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.font = wezterm.font("JetBrains Mono")
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = true
config.color_scheme = "rose-pine"
-- config.color_scheme = "Sakura"
-- config.color_scheme = 'Sequoia Moonlight'
return config
