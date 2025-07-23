---@class fFtT_highlights.opts
---@field f string f key. default: "f"
---@field F string F key. default: "F"
---@field t string t key. default: "t"
---@field T string T key. default: "T"
---@field next string next key. default: ";"
---@field prev string previous key. default: ","
---@field reset_key string highlight/jump reset key. default: "<Esc>"
---@field on_reset function | nil callback to run when reset_key is pressed. default: nil
---@field smart_motions boolean whether to use f/F/t/T to go to next/previous characters. default: false
---@field case_sensitivity "default" | "smart_case" | "ignore_case" case sensitivity. default: "default"
---@field max_highlighted_lines_around_cursor integer max number of lines to consider above/below cursor for highlighting. default: 300
---@field match_highlight match_highlight
---@field multi_line multi_line
---@field backdrop backdrop
---@field jumpable_chars jumpable_chars
---@field disabled_filetypes table<string> disable the plugin for these filetypes: default: {}
---@field disabled_buftypes table<string> disable the plugin for these buftypes: default: {"nofile"}

---@class match_highlight matching chars highlight configuration
---@field enable boolean enable/disable matching chars highlight. default: true
---@field style "full" | "minimal" match highlighting style. default: "minimal"
---@field persist_matches integer number of matches to keep highlighted that the cursor passed over. default: 0
---@field highlight_radius integer consider at most this many characters for highlighting. default: 500
---@field show_jump_numbers boolean show the number of jumps required to get to each matching character. default: false
---@field priority integer match highlight priority. default: 1200

---@class multi_line multi-line search configuration
---@field enable boolean enable/disable multi-line search. default: false
---@field max_lines integer (Forced window locality) max lines to consider above/below cursor if multi-line search is enabled. default: 300

---@class backdrop backdrop/background-dimming configuration
---@field style backdrop_style backdrop style.
---@field border_extend integer extend backdrop border horizontally by this many characters. default: "0"
---@field priority integer backdrop highlight priority. default: 800

---@class backdrop_style
---@field on_key_press "full" | "current_line" | "none" backdrop behavior upon keypress. default: "full"
---@field show_in_motion "full" | "upto_next_line" | "current_line" | "none" backdrop behavior while in motion. default: "upto_next_line""

---@class jumpable_chars instantly jumpable characters configuration
---@field show_instantly_jumpable "on_key_press" | "always" | "never" when to show instantly jumpable characters (options below have no effect when this is disabled). default: "always"
---@field show_secondary_jumpable "on_key_press" | "always" | "never" when to show secondary jumpable characters. default: "never"
---@field show_all_jumpable_in_words "on_key_press" | "always" | "never" when to show all jumpable characters. default: "never"
---@field show_multiline_jumpable "on_key_press" | "always" | "never" when to show multi-line (if enabled) jumpable characters. default: "never"
---@field min_gap integer minimum gap between two jumpable characters. default: 1
---@field priority integer jumpable chars highlight priority. default: 1100
---@field priority_secondary integer secondary jumpable chars highlight priority. default: 1000

---@class last_state
---@field motion string
---@field char string
---@field in_motion boolean

---@class fFtT_highlights
---@field private fFtT_motion fun(self): nil
---@field public fFtT_expr_motion fun(self): nil
---@field public next_prev_motion fun(self): nil
---@field public setup fun(self, opts?: fFtT_highlights.opts): nil
---@field public last_state last_state | nil
---@field private set_keymaps fun(self): nil
---@field private opts fFtT_highlights.opts
---@field private setup_done boolean
---@field private current_motion string | nil
---@field private current_expr_motion string | nil
---@field private saved_char string | nil
---@field private saved_expr_char string | nil
---@field private highlights highlights
---@field private utils utils
---@field private smart_motion fun(self): nil
---@field private validate_opts fun(self, opts: fFtT_highlights.opts): nil
---@field private jump_and_highlight fun(self, bufnr: integer, motion: string, char: string, reverse: boolean): nil
---@field private motion_escape_sequence fun(self): nil -- Removes highlights and cancels motion
local fFtT_hl = {
	last_state = {
		in_motion = false,
		motion = "",
		char = "",
	},
	setup_done = false,
}

---@type fFtT_highlights.opts
local default_opts = {
	f = "f",
	F = "F",
	t = "t",
	T = "T",
	next = ";",
	prev = ",",
	reset_key = "<Esc>",
	smart_motions = false,
	case_sensitivity = "default",
	max_highlighted_lines_around_cursor = 300,
	match_highlight = {
		enable = true,
		highlight_radius = 500,
		style = "minimal",
		persist_matches = 0,
		show_jump_numbers = false,
		priority = 1200,
	},
	multi_line = {
		enable = false,
		max_lines = 300,
	},
	backdrop = {
		style = {
			on_key_press = "full",
			show_in_motion = "upto_next_line",
		},
		border_extend = 0,
		priority = 800,
	},
	jumpable_chars = {
		show_instantly_jumpable = "never",
		show_secondary_jumpable = "never",
		show_all_jumpable_in_words = "never",
		show_multiline_jumpable = "never",
		min_gap = 1,
		priority = 1100,
		priority_secondary = 1000,
	},
	disabled_filetypes = {},
	disabled_buftypes = { "nofile" },
}

---@param opts? fFtT_highlights.opts
function fFtT_hl:setup(opts)
	opts = opts or {}
	opts = vim.tbl_deep_extend("force", default_opts, opts)
	if not opts.multi_line.enable then
		opts.multi_line.max_lines = 0
	end
	self:validate_opts(opts)
	self.opts = opts

	if not self.setup_done then
		self.highlights = require("highlights")
		self.utils = require("utils")
		_G.fFtT_hl = fFtT_hl

		self.highlights:setup_highlight_groups()
		self.highlights:setup_highlight_reset_trigger(opts, self.utils, function()
			if not self.last_state.in_motion then
				self.utils:reset_cursor_history()
			end
			self.last_state.in_motion = false
		end)
		self:set_keymaps()
		self.setup_done = true
	end

	local fFtT_hl_clear_group = vim.api.nvim_create_augroup("fFtTHLClearGroup", { clear = true })

	vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
		group = fFtT_hl_clear_group,
		callback = function()
			if self.utils:disabled_file_or_buftype(self.opts) then
				return
			end
			self.last_state.in_motion = false
			self.highlights:clear_fFtT_hl()
			self.highlights:clear_unique_char_hl()
			self.highlights.redraw()
		end,
	})

	if opts.jumpable_chars.show_instantly_jumpable == "always" then
		vim.api.nvim_create_autocmd({ "CursorMoved" }, {
			group = fFtT_hl_clear_group,
			callback = function()
				if self.utils:disabled_file_or_buftype(self.opts) then
					return
				end
				self.highlights:clear_unique_char_hl()
				self.highlights:highlight_jumpable_chars_on_line(opts)
			end,
		})
	end
end

---@param opts fFtT_highlights.opts
function fFtT_hl:validate_opts(opts)
	local errors = {}
	--stylua: ignore start
	if opts.on_reset and type(opts.on_reset) ~= "function" then
		errors[#errors + 1] = "opts.on_reset must be a function!"
	end

	if not opts.match_highlight or type(opts.match_highlight) ~= "table" then
		errors[#errors + 1] = "opts.match_highlight must be a valid table!"
	else
		if opts.match_highlight.highlight_radius < 0 then
			errors[#errors + 1] = "opts.match_highlight.highlight_radius must be >= 0"
		end
		if opts.match_highlight.style ~= "minimal" and opts.match_highlight.style ~= "full" then
			errors[#errors + 1] = "opts.match_highlight.style must be one of 'full' or 'minimal'"
		end
		if opts.match_highlight.persist_matches < 0 then
			errors[#errors + 1] = "opts.match_highlight.persist_matches must be >= 0"
		end
	end
	if opts.max_highlighted_lines_around_cursor < 0 then
		errors[#errors + 1] = "opts.max_highlighted_lines_around_cursor must be >= 0"
	end
	if opts.case_sensitivity ~= "default" and opts.case_sensitivity ~= "smart_case" and opts.case_sensitivity ~= "ignore_case" then
		errors[#errors + 1] = "opts.case_sensitivity must be one of 'default', 'smart_case' or 'ignore_case'"
	end

	if not opts.jumpable_chars or type(opts.jumpable_chars) ~= "table" then
		errors[#errors + 1] = "opts.jumpable_chars must be a valid table!"
	else
		if opts.jumpable_chars.show_instantly_jumpable ~= "always" and opts.jumpable_chars.show_instantly_jumpable ~= "never" and opts.jumpable_chars.show_instantly_jumpable ~= "on_key_press" then
			errors[#errors + 1] = "opts.jumpable_chars.show_instantly_jumpable must be one of 'always', 'never' or 'on_key_press'"
		end
		if opts.jumpable_chars.show_secondary_jumpable ~= "always" and opts.jumpable_chars.show_secondary_jumpable ~= "never" and opts.jumpable_chars.show_secondary_jumpable ~= "on_key_press" then
			errors[#errors + 1] = "opts.jumpable_chars.show_secondary_jumpable must be one of 'always', 'never' or 'on_key_press'"
		end
		if opts.jumpable_chars.show_all_jumpable_in_words ~= "always" and opts.jumpable_chars.show_all_jumpable_in_words ~= "never" and opts.jumpable_chars.show_all_jumpable_in_words ~= "on_key_press" then
			errors[#errors + 1] = "opts.jumpable_chars.show_all_jumpable_in_words must be one of 'always', 'never' or 'on_key_press'"
		end
		if opts.jumpable_chars.show_multiline_jumpable ~= "always" and opts.jumpable_chars.show_multiline_jumpable ~= "never" and opts.jumpable_chars.show_multiline_jumpable ~= "on_key_press" then
			errors[#errors + 1] = "opts.jumpable_chars.show_multiline_jumpable must be one of 'always', 'never' or 'on_key_press'"
		end
		if opts.jumpable_chars.min_gap < 0 then
			errors[#errors + 1] = "opts.jumpable_chars.min_gap must be >= 0"
		end
	end

	if not opts.backdrop or type(opts.backdrop) ~= "table" then
		errors[#errors + 1] = "opts.backdrop must be a valid table!"
	else
		if opts.backdrop.border_extend < 0 then
			errors[#errors + 1] = "opts.backdrop.border_extend must be >= 0"
		end
		if not opts.backdrop.style or type(opts.backdrop.style) ~= "table" then
			errors[#errors + 1] = "opts.backdrop.style must be a valid table!"
		else
			if opts.backdrop.style.on_key_press ~= "full" and opts.backdrop.style.on_key_press ~= "current_line" and opts.backdrop.style.on_key_press ~= "none" then
				errors[#errors + 1] = "opts.backdrop.style.on_key_press must be one of 'current_line', 'full', or 'none'"
			end
			if opts.backdrop.style.show_in_motion ~= "full" and opts.backdrop.style.show_in_motion ~= "upto_next_line" and opts.backdrop.style.show_in_motion ~= "current_line" and opts.backdrop.style.show_in_motion ~= "none" then
				errors[#errors + 1] = "opts.backdrop.style.show_in_motion must be one of 'current_line', 'upto_next_line', 'full', or 'none'"
			end
		end
	end

	if not opts.multi_line or type(opts.multi_line) ~= "table" then
		errors[#errors + 1] = "opts.multi_line must be a valid table!"
	else
		if opts.multi_line.max_lines < 0 then
			errors[#errors + 1] = "opts.multi_line.max_lines must be >= 0"
		end
	end
	--stylua: ignore end
	if #errors > 0 then
		error("fFtT_highlights: invalid opts:\n" .. table.concat(errors, ",\n"))
	end
end

function fFtT_hl:set_keymaps()
	local opts = self.opts
	local utils = self.utils
	for _, motion in ipairs({ opts.f, opts.F, opts.t, opts.T }) do
		for _, mode in ipairs({ "n", "x" }) do
			vim.keymap.set(mode, motion, function()
				if utils:disabled_file_or_buftype(opts) then
					return motion
				end
				self.current_motion = motion
				if opts.smart_motions and self.last_state and self.last_state.in_motion then
					return "<Cmd>lua fFtT_hl:smart_motion()<CR>"
				end
				self.highlights:set_on_key_highlights(opts, motion)
				local input = utils:get_char()
				if not input or input == opts.reset_key then
					self:motion_escape_sequence()
					return opts.reset_key
				end
				self.saved_char = input
				local row, col = utils:jump_to_next_char(
					opts,
					self.current_motion,
					self.saved_char,
					utils:is_reverse(opts, self.current_motion),
					"n"
				)
				if row == 0 and col == 0 then
					self:motion_escape_sequence()
					return opts.reset_key
				end
				return "<Cmd>lua fFtT_hl:fFtT_motion()<CR>"
			end, { expr = true })
		end

		vim.keymap.set("o", motion, function()
			if utils:disabled_file_or_buftype(opts) then
				return motion
			end
			self.current_motion = motion
			self.highlights:set_on_key_highlights(opts, motion)
			local input = utils:get_char()
			if not input or input == opts.reset_key then
				self:motion_escape_sequence()
				return opts.reset_key
			end
			self.saved_char = input
			local row, col = utils:jump_to_next_char(
				opts,
				self.current_motion,
				self.saved_char,
				utils:is_reverse(opts, self.current_motion),
				"n"
			)
			if row == 0 and col == 0 then
				self:motion_escape_sequence()
				return opts.reset_key
			end
			self.current_expr_motion = self.current_motion
			self.saved_expr_char = self.saved_char
			return "v<Cmd>lua fFtT_hl:fFtT_expr_motion()<CR>"
		end, { expr = true })
	end

	for _, motion in ipairs({ opts.next, opts.prev }) do
		if motion ~= "" then
			for _, mode in ipairs({ "n", "x" }) do
				vim.keymap.set(mode, motion, function()
					if utils:disabled_file_or_buftype(opts) then
						return motion
					end
					self.current_motion = motion
					return "<Cmd>lua fFtT_hl:next_prev_motion()<CR>"
				end, { expr = true })
			end
			vim.keymap.set("o", motion, function()
				if utils:disabled_file_or_buftype(opts) then
					return motion
				end
				self.current_motion = motion
				return "v<Cmd>lua fFtT_hl:next_prev_motion()<CR>"
			end, { expr = true })
		end
	end
end

function fFtT_hl:motion_escape_sequence()
	self.last_state.in_motion = false
	self.highlights:clear_fFtT_hl()
	self.highlights:clear_unique_char_hl()
	if self.opts.jumpable_chars.show_instantly_jumpable == "always" then
		self.highlights:highlight_jumpable_chars_on_line(self.opts)
	end
	if self.opts.on_reset then
		self.opts.on_reset()
	end
	self.highlights.redraw()
end

function fFtT_hl:fFtT_expr_motion()
	self.current_motion = self.current_expr_motion
	self.saved_char = self.saved_expr_char
	local reverse = self.utils:is_reverse(self.opts, self.current_motion)
	local row, col = fFtT_hl.utils:jump_to_next_char(self.opts, self.current_motion, self.saved_char, reverse, "n")
	if row == 0 and col == 0 then
		self:motion_escape_sequence()
		vim.schedule(function() --HACK: "fixes" dot repeated deletion of invalid characters
			vim.cmd("undo!")
		end)
		return
	end
	self:fFtT_motion()
end

function fFtT_hl:fFtT_motion()
	local opts = self.opts
	local motion = self.current_motion
	local highlights = self.highlights
	local char = self.saved_char
	if not char or not highlights or not opts or not motion then
		return
	end

	local reverse = self.utils:is_reverse(opts, motion)
	if char == opts.reset_key then
		self:motion_escape_sequence()
		return
	end

	self.last_state = {
		in_motion = true,
		motion = motion,
		char = char,
	}

	self:jump_and_highlight(vim.api.nvim_get_current_buf(), motion, char, reverse)
end

function fFtT_hl:smart_motion()
	local opts = self.opts
	local motion = self.current_motion
	local last_motion = self.last_state.motion
	local reverse = false
	if last_motion == opts.F or last_motion == opts.T then
		reverse = true
	end
	if motion == opts.F or motion == opts.T then
		reverse = not reverse
	end

	self:jump_and_highlight(vim.api.nvim_get_current_buf(), last_motion, self.last_state.char, reverse)

	self.last_state = {
		char = self.last_state.char,
		motion = last_motion,
		in_motion = true,
	}
end

function fFtT_hl:next_prev_motion()
	local opts = self.opts or {}
	local motion = self.current_motion
	if not self.last_state or not motion then
		return
	end
	local last_motion = self.last_state.motion
	local reverse = self.utils:is_reverse(opts, motion, last_motion)

	self:jump_and_highlight(vim.api.nvim_get_current_buf(), last_motion, self.last_state.char, reverse)
	self.last_state.in_motion = true
end

---@param bufnr integer
---@param motion string
---@param char string
---@param reverse boolean
function fFtT_hl:jump_and_highlight(bufnr, motion, char, reverse)
	local opts = self.opts
	local utils = self.utils
	local highlights = self.highlights
	---@type integer | nil
	local count1 = math.min(3000, vim.v.count1)

	for _ = 1, count1 do
		local new_row, new_col = utils:jump_to_next_char(opts, motion, char, reverse)
		if new_row == 0 and new_col == 0 then
			break
		end
		if new_row and new_col and opts.match_highlight.persist_matches > 0 then
			utils:store_cursor_position(bufnr, new_row - 1, new_col - 1, opts.match_highlight.persist_matches or 0)
		end
	end

	highlights:set_in_motion_highlights(opts, utils, bufnr, char, reverse)
	if opts.match_highlight.persist_matches > 0 then
		highlights:set_highlights_in_custom_pos(opts, utils:get_cursor_position_history())
	end
end

return fFtT_hl
