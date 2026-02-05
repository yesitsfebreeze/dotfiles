os.execute('cd ~/.config/dotfiles && just update &')

local cfg = {
	DEFAULT_SHELL = { 'zsh', '-l' },
	DEFAULT_CWD = '/Users/feb/dev',
	DEFAULT_TERMINAL = '/bin/zsh',
	THEME = 'Gruvbox dark, hard (base16)',
	FONT = 'Departure Mono',
	FONT_SIZE = 18,
	LINE_HEIGHT = 1.01,
	BACKGROUND_TINT = "#14181c",
	OPACITY = 0.825,
	BLUR = 150,
	SPLIT_PANE_SIZE = 0.5,
}

local wezterm = require('wezterm')
local act = wezterm.action
local mux = wezterm.mux
local config = wezterm.config_builder and wezterm.config_builder() or {}
local xdg_dir = wezterm.home_dir .. '/.config/wezterm'
local schemes = wezterm.get_builtin_color_schemes()

local scheme = schemes[cfg.THEME]

config.term = "xterm-256color"
config.window_close_confirmation = 'NeverPrompt'
config.default_prog = cfg.DEFAULT_SHELL
config.default_cwd = cfg.DEFAULT_CWD
config.color_scheme = cfg.THEME
config.font_dirs = { 'fonts' }

config.default_cursor_style = "BlinkingBlock"
config.animation_fps = 1 -- lower FPS for hard blink
config.cursor_blink_rate = 800 -- ms, adjust as needed
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

config.font = wezterm.font(
	cfg.FONT,
	{ stretch = 'UltraCondensed', weight = 'Regular' }
)

config.colors = {
	foreground = "#c0ccdb",
	background = "#131719",

	cursor_bg = "#ffffff",
	cursor_fg = "#131719",
	cursor_border = "#ffffff",

	selection_fg = "#ffffff",
	selection_bg = "#43b5b3",

	scrollbar_thumb = "#3f4c53",
	split = "#293236",

	tab_bar = {
		background = "transparent",
		active_tab = {
			bg_color = "transparent",
			fg_color = "#c0ccdb",
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = "transparent",
			fg_color = "#6b828d",
		},
		inactive_tab_hover = {
			bg_color = "transparent",
			fg_color = "#c0ccdb",
		},
		new_tab = {
			bg_color = "transparent",
			fg_color = "#c0ccdb",
		},
		new_tab_hover = {
			bg_color = "transparent",
			fg_color = "#ffffff",
		},
	},

	ansi = {
		"#1e2427", -- black
		"#ba0e2e", -- red
		"#5298c4", -- green (note: your theme uses this for green)
		"#d4856a", -- yellow
		"#43b5b3", -- blue (theme uses teal here)
		"#d4856a", -- magenta
		"#43b5b3", -- cyan
		"#d0d9e4", -- white
	},
	brights = {
		"#3f4c53", -- bright black
		"#f03e5f", -- bright red
		"#9ec5de", -- bright green
		"#ebc6b9", -- bright yellow
		"#8ad4d2", -- bright blue
		"#ebc6b9", -- bright magenta
		"#8ad4d2", -- bright cyan
		"#ffffff", -- bright white
	},

	compose_cursor = "#ffffff",
}

config.font_size = cfg.FONT_SIZE
config.line_height = cfg.LINE_HEIGHT
config.scrollback_lines = 3500
config.tab_bar_at_bottom = true
config.window_decorations = 'RESIZE'
config.tab_max_width = 32
config.use_fancy_tab_bar = false
config.window_background_opacity = cfg.OPACITY
config.macos_window_background_blur = cfg.BLUR
config.audible_bell = 'Disabled'
config.visual_bell = {
	fade_in_function = 'EaseIn',
	fade_in_duration_ms = 25,
	fade_out_function = 'EaseOut',
	fade_out_duration_ms = 50,
}
config.window_frame = {
	font = wezterm.font { family = cfg.FONT, weight = 'Bold' },
	font_size = cfg.FONT_SIZE,
}

config.colors.visual_bell = scheme.background

config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.background = {
	{
		width = '100%',
		height = '100%',
		opacity = cfg.OPACITY,
		source = {
			Color=config.colors.background
		}
	},
}

local function get_main_pane_info(tab)
	local main = nil
	local top_x, top_y = math.huge, math.huge

	for _, p in ipairs(tab:panes_with_info()) do
		if p.left < top_x or (p.left == top_x and p.top < top_y) then
			main = p
			top_x = p.left
			top_y = p.top
		end
	end

	return main
end

local function get_right_pane_info(tab)
	local right = nil
	local max_x = 0

	for _, p in ipairs(tab:panes_with_info()) do
		if p.left > max_x then
			right = p
			max_x = p.left
		end
	end

	return right
end

local function toggle_right_pane(window, pane)
	local tab = window:active_tab()
	local panes = tab:panes()

	local main = get_main_pane_info(tab)
	local right = get_right_pane_info(tab)
	
	if not right then
		main.pane:split { direction = 'Right', size = cfg.SPLIT_PANE_SIZE }
	else
		local main = get_main_pane_info(tab)

	if main.is_zoomed then
		window:perform_action(wezterm.action.SetPaneZoomState(false), main.pane)
		window:perform_action(wezterm.action.ActivatePaneByIndex(right.index), right.pane)
	else
		window:perform_action(wezterm.action.ActivatePaneByIndex(main.index), main.pane)
		window:perform_action(wezterm.action.SetPaneZoomState(true), main.pane)
	end
	end
end

config.keys = config.keys or {}

-- your existing binding(s)
table.insert(config.keys, { key = "Tab", mods = "CTRL", action = wezterm.action_callback(toggle_right_pane) })

local ESC = string.char(27)
local CTRL_SLASH = string.char(28)
table.insert(config.keys, { key = "F12", mods = "SHIFT", action = wezterm.action.SendString(ESC .. ESC .. CTRL_SLASH) })

config.native_macos_fullscreen_mode = false
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  wezterm.time.call_after(0.05, function()
    window:gui_window():perform_action(act.ToggleFullScreen, pane)
  end)
end)

return config
