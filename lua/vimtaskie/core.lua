-- lua/vimtaskie/core.lua
-- Description: Core functions for task management

local luasql = require("luasql.sqlite3")
local M = {}

local env = luasql.sqlite3()
local db_path = vim.fn.stdpath("data") .. "/vimtaskie.db"
local conn = nil

-- Initialize the database connection, create tables if they don't exist

function M.init_db()
	conn = env:connect(db_path)
	if not conn then
		vim.notify("Failed to connect to SQLite DB", vim.log.levels.ERROR)
		return
	end
	local create_tasks_table = [[
    CREATE TABLE IF NOT EXISTS tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      title TEXT,
      description TEXT,
      priority INTEGER,
      status TEXT,
      related_task_id INTEGER
    );
  ]]
	local create_comments_table = [[
    CREATE TABLE IF NOT EXISTS comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER,
      comment TEXT,
      timestamp TEXT,
      FOREIGN KEY (task_id) REFERENCES tasks(id)
    );
  ]]
	local rc, err = conn:execute(create_tasks_table)
	if not rc then
		vim.notify("Failed to create tasks table: " .. err, vim.log.levels.ERROR)
	else
		vim.notify("Tasks table created successfully", vim.log.levels.INFO)
	end

	conn:execute(create_comments_table)
end

-- get all tasks from the database

function M.get_tasks()
	local tasks = {}
	local cursor = conn:execute("SELECT * FROM tasks ORDER BY id DESC")
	if cursor then
		local row = cursor:fetch({}, "a")
		while row do
			table.insert(tasks, row)
		end
		cursor:close()
	end
	return tasks
end

-- get status colors
-- @param status string
-- @return colors[status] string or "white"
function M.get_status_color(status)
	local colors = {
		["not_started"] = "grey",
		["in_progress"] = "blue",
		["done"] = "green",
		["blocked"] = "red",
	}
	return colors[status] or "white"
end

-- add task to the database
function M.add_task()
	local title = vim.fn.input("Task Title: ")
	local description = vim.fn.input("Task Description: ")
	local priority = vim.fn.input("Task Priority (1-5): ")
	local status = "not_started"
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")

	if title == "" then
		vim.notify("Task title cannot be empty", vim.log.levels.WARN)
		return
	end

	local query = string.format(
		"INSERT INTO tasks (timestamp, title, description, priority, status) VALUES ('%s', '%s', '%s', %d, '%s')",
		timestamp,
		title,
		description,
		priority,
		status
	)
	local res, err = conn:execute(query)
	if not res then
		vim.notify("Failed to add task: " .. err, vim.log.levels.ERROR)
	else
		vim.notify("Task added successfully", vim.log.levels.INFO)
	end
end

-- open a status panel for the task
function M.open_task_panel()
	local total_cols = vim.o.columns
	local total_lines = vim.o.lines - vim.o.cmdheight
	local panel_width = math .. floor(total_cols * 0.2)

	local buf = vim.api.nvim_create_buf(false, true)
	if not buf then
		vim.notify("Failed to create buffer", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = panel_width,
		height = total_lines,
		col = total_cols - panel_width,
		row = 0,
		style = "minimal",
		border = "rounded",
	})

	local tasks = M.get_tasks()
	local lines = {}
	for _, task in ipairs(tasks) do
		table.insert(lines, string.format("%s [%s] %s", task.timestamp, task.status, task.title))
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

-- change the status of a task
-- @param task_id integer
-- @param new_status string
function M.change_task_status(task_id, new_status)
	local query = string.format("UPDATE tasks SET status = '%s' WHERE id = %d", new_status, task_id)
	local res, err = conn:execute(query)
	if not res then
		vim.notify("Failed to update task status: " .. err, vim.log.levels.ERROR)
	else
		vim.notify("Task status updated successfully", vim.log.levels.INFO)
	end
end

-- open a comment editor for a task
-- @param task_id integer
function M.open_comment_editor(task_id)
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
			M.save_comment(task_id, buf)
		end,
		desc = "Save comment",
	})
	vim.notify("Enter your comment. Press ZZ in normal mode to save.")
end

-- save the comment to the database
-- @param task_id integer
-- @param buf integer
function M.save_comment(task_id, buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local comment_text = table.concat(lines, "\n")
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local query = string.format(
		"INSERT INTO comments (task_id, comment, timestamp) VALUES (%d, '%s', '%s')",
		task_id,
		comment_text,
		timestamp
	)
	local res, err = conn:execute(query)
	if not res then
		vim.notify("Failed to save comment: " .. err, vim.log.levels.ERROR)
	else
		vim.notify("Comment saved successfully", vim.log.levels.INFO)
	end
	vim.api.nvim_buf_delete(buf, { force = true })
end

-- Register neovim commands
function M.register_commands()
	vim.api.nvim_create_user_command("TaskieAddTask", function()
		M.add_task()
	end, {})
	vim.api.nvim_create_user_command("TaskieOpenPanel", function()
		M.open_task_panel()
	end, {})
	vim.api.nvim_create_user_command("TaskieChangeStatus", function(opts)
		local args = vim.split(opts.args, "%s+")
		if #args < 2 then
			vim.notify("Usage: TaskieChangeStatus <task_id> <new_status>", vim.log.levels.WARN)
			return
		end
		local task_id = tonumber(args[1])
		local new_status = args[2]
		if not task_id or not new_status then
			vim.notify("Invalid task ID or status", vim.log.levels.WARN)
			return
		end
		M.change_task_status(task_id, new_status)
	end, { nargs = "+" })
	vim.api.nvim_create_user_command("TaskieAddComment", function(opts)
		local task_id = opts.args
		if not task_id or task_id == "" then
			vim.notify("Usage: TaskieAddComment <task_id>", vim.log.levels.WARN)
			return
		end
		M.open_comment_editor(task_id)
	end, { nargs = 1 })
end

return M
