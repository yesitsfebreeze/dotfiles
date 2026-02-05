--@~/.config/palette.lua

local BACKGROUND = '#131719'
local FOREGROUND = '#c0ccdb'

local CURSOR = '#ffffff'

local RED = '#e84966'
local ORANGE = '#d4856a'
local YELLOW = '#f7b83d'
local GREEN = '#a6ca42'
local CYAN = '#43b5b3'
local BLUE = '#5298c4'
local PURPLE = '#a875d7'

return {
  background = '#131719',
  foreground = '#c0ccdb',
  cursor = '#ffffff',
  selection = CYAN,
  line_highlight = '#1a1f22',
  
  comment = '#4e5c66',
  string = '#84c4ce',
  number = '#529ca8',
  constant = ORANGE,
  keyword = ORANGE,
  storage = '#5298c4',
  function_name = CYAN,
  class_name = ORANGE,
  tag = '#5298c4',
  attribute = ORANGE,
  variable = '#ffffff',
  
  red = RED,
  orange = YELLOW,
  yellow = ORANGE,
  green = GREEN,
  cyan = CYAN,
  blue = BLUE,
  purple = PURPLE,
  magenta = ORANGE,
  
  error = RED,
  warning = ORANGE,
  info = PURPLE,
  
  sidebar_bg = '#1e2427',
  activity_bar = '#171c1f',
  status_bar = '#5298c4',
  tab_inactive = '#1c2225',
  panel_bg = '#293236',
  
  gutter_modified = YELLOW,
  gutter_added = GREEN,
  gutter_deleted = RED,
  
  ansi_black = '#1e2427',
  ansi_red = RED,
  ansi_green = BLUE,
  ansi_yellow = ORANGE,
  ansi_blue = CYAN,
  ansi_magenta = ORANGE,
  ansi_cyan = CYAN,
  ansi_white = FOREGROUND,
  
  ansi_bright_black = '#3f4c53',
  ansi_bright_red = '#f03e5f',
  ansi_bright_green = '#9ec5de',
  ansi_bright_yellow = '#ebc6b9',
  ansi_bright_blue = '#8ad4d2',
  ansi_bright_magenta = '#ebc6b9',
  ansi_bright_cyan = '#8ad4d2',
  ansi_bright_white = '#ffffff',

  modes = {
    i = WHITE,
    n = GREEN,
    v = BLUE,
    V = CYAN,
    ['\22'] = CYAN, -- visual block (Ctrl-V)
    c = YELLOW,
    R = RED,
    s = ORANGE,
    S = ORANGE,
    ['\19'] = ORANGE, -- select block (Ctrl-S)
  },
}
