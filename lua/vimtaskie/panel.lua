-- lua/vimtaskie/panel.lua
local M = {}

-- Stores the floating window handles for the task panels
local task_panels = {}
local selected_index = 1

-- Helper to calculate panel dimensions based on current window size
local function calculate_dimensions()
	local total_cols = vim.o.columns
	local total_lines = vim.o.lines - vim.o.cmdheight
	local panel_width = math.floor(total_cols * 0.2)
	local panel_height = math.floor(total_lines / 5) -- 5 panels maximum
	return panel_width, panel_height, total_cols, total_lines
end

-- Create (or update) panels for up to 5 tasks
function M.create_task_panels(tasks)
	-- First, close any existing panels
	for _, win in ipairs(task_panels) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	task_panels = {}

	local panel_width, panel_height, total_cols, _ = calculate_dimensions()

	-- Limit tasks to the first 5 items
	for i = 1, math.min(5, #tasks) do
		local task = tasks[i]
		-- Create a scratch buffer for this task panel
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(buf, "wrap", true)
		-- Open a floating window for this task
		local win = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			width = panel_width,
			height = panel_height,
			col = total_cols - panel_width,
			row = (i - 1) * panel_height,
			style = "minimal",
			border = "rounded",
		})

		-- Prepare task text (you can add word wrapping manually if needed)
		local text = string.format("[%d] %s (%s)", task.id, task.title, task.status)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n"))

		-- Map keys for task interaction within the panel
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<CR>",
			string.format("<cmd>lua require('vimtaskie.panel').open_comments(%d)<CR>", task.id),
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"c",
			string.format("<cmd>lua require('vimtaskie.panel').add_comment(%d)<CR>", task.id),
			{ noremap = true, silent = true }
		)

		-- For navigation, map up/down keys to global functions
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<Up>",
			"<cmd>lua require('vimtaskie.panel').move_selection(-1)<CR>",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<Down>",
			"<cmd>lua require('vimtaskie.panel').move_selection(1)<CR>",
			{ noremap = true, silent = true }
		)

		table.insert(task_panels, win)
	end

	-- Highlight the currently selected panel
	M.highlight_panel(selected_index)
end

-- Update the highlight to show the selected task panel
function M.highlight_panel(index)
	selected_index = index
	for i, win in ipairs(task_panels) do
		if vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			-- Clear previous highlights (using an anonymous namespace)
			vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
			if i == index then
				-- For demonstration, using the "Visual" highlight group
				vim.api.nvim_buf_add_highlight(buf, -1, "Visual", 0, 0, -1)
			end
		end
	end
end

-- Change the selected panel using delta (-1 for up, +1 for down)
function M.move_selection(delta)
	local new_index = selected_index + delta
	if new_index < 1 then
		new_index = 1
	elseif new_index > #task_panels then
		new_index = #task_panels
	end
	M.highlight_panel(new_index)
	-- Optionally, set focus to the new panel:
	if vim.api.nvim_win_is_valid(task_panels[new_index]) then
		vim.api.nvim_set_current_win(task_panels[new_index])
	end
end

-- Dummy functions for opening comments and adding comments.
-- Replace these with your actual implementations.
function M.open_comments(task_id)
	vim.notify("Opening comments for task " .. task_id)
	local width = math.floor(vim.o.columns * 0.5)
	local height = math.floor(vim.o.lines * 0.5)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	})
	vim.api.nvim_buf_set_keymap(buf, "n", "ZZ", "", {
		noremap = true,
		silent = true,
		callback = function()
			require("vimtaskie").save_comment(task_id, buf)
		end,
		desc = "Save comment",
	})
	vim.notify("Enter your comment. Press ZZ in normal mode to save.")
end

function M.add_comment(task_id)
	vim.notify("Adding comment for task " .. task_id)
	-- Open a comment editor floating window.
end

-- Refresh panels automatically; call this after any task update.
function M.refresh_panels()
	local tasks = require("vimtaskie.core").get_tasks()
	M.create_task_panels(tasks)
end

-- Autocommand to update panel sizes when the terminal is resized
vim.cmd([[
  augroup TaskPanelResize
    autocmd!
    autocmd VimResized * lua require('vimtaskie.panel').refresh_panels()
  augroup END
]])

-- Command to focus on the current panel, and one to switch back to code
vim.api.nvim_create_user_command("FocusPanel", function()
	if #task_panels > 0 and vim.api.nvim_win_is_valid(task_panels[selected_index]) then
		vim.api.nvim_set_current_win(task_panels[selected_index])
	end
end, {})

vim.api.nvim_create_user_command("FocusCode", function()
	-- Simply focus the previously used code window
	vim.cmd("wincmd p")
end, {})

-- Optionally, you could also set global mappings to swap focus:
vim.api.nvim_set_keymap("n", "<leader>tp", "<cmd>FocusPanel<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>tc", "<cmd>FocusCode<CR>", { noremap = true, silent = true })

return M
