local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope_config = require("telescope.config").values
local actions = require("telescope.actions")
local entry_display = require("telescope.pickers.entry_display")
local utils = require("telescope.utils")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local Job = require("plenary.job")
local previewers = require("telescope.previewers")

local _p = function(str)
  require("notify")(str)
end

local kitty_get_tabs = function(opts)
  local stdout, ret = Job
      :new({
        command = "kitty",
        args = { "@", "ls" },
      })
      :sync()

  -- TODO: check `ret` and error out if kitty failed
  local tabs = {}
  local data = vim.json.decode(table.concat(stdout))
  for _, oswindow in pairs(data) do
    -- vim.pretty_print(oswindow)
    for _, tab in pairs(oswindow.tabs) do
      -- assume for now that each tab has only one window ("pane")
      local window = tab.windows[1]

      if oswindow.is_focused then
        table.insert(tabs, {
          tab_id = tab.id,
          title = tab.title,
          is_focused = tab.is_focused,
          cwd = tab.cwd,
          window_id = window.id,
          oswindow_id = oswindow.id,
        })
      end
    end
  end
  return tabs
end

local kitty_focus_tab = function(tab)
  Job
      :new({
        command = "kitty",
        args = { "@", "focus-tab", "--match", "id:" .. tab.tab_id },
      })
      :sync()
end

local kitty_get_text = function(tab)
  Job
      :new({
        command = "kitty",
        args = { "@", "get-text", "--match", "id:" .. tab.window_id },
      })
      :sync()
end

local window_preview = previewers.new({
  preview_fn = function(_, entry, status)
    local preview_win = status.preview_win
    local bufnr = vim.api.nvim_win_get_buf(preview_win)
    local text = kitty_get_text(entry.value)
    -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)

    -- if not pcall(vim.api.nvim_win_set_cursor, preview_win, { entry.value.lnum, 0 }) then
    --   return
    -- end

    -- p_utils.highlighter(bufnr, filetype.detect(entry.value.path))
    -- vim.api.nvim_buf_add_highlight(bufnr, 0, "Visual", entry.value.lnum, 0, -1)
  end,
})
previewers.new({
  preview_fn = function(self, entry, status) end,
})

local kitty = function(opts)
  local kitty_tabs = kitty_get_tabs()
  pickers.new(opts, {
    prompt_title = "kitty tabs",
    finder = finders.new_table({
      results = kitty_tabs,
      entry_maker = function(tab)
        return {
          value = tab,
          display = tab.title,
          ordinal = tab.title,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.pretty_print(selection.value)
        kitty_focus_tab(selection.value)
      end)

      return true
      -- kitty_focus_tab(selection)
    end,
    previewer=window_preview,
  }):find()
end
kitty()

return telescope.register_extension({
  exports = {
    kitty = kitty,
  },
})
