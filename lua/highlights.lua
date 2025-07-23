---@class highlights
---@field setup_highlight_groups fun(self): nil
---@field highlight_jumpable_chars fun(self, opts: fFtT_highlights.opts, bufnr: number, row: number, line: string, from: number, to: number, reverse: boolean, show_all_jumpable: boolean, show_secondary_chars: boolean, seen?: table<string, integer>): table<string, integer> | nil
---@field set_on_key_highlights fun(self, opts: fFtT_highlights.opts, motion: string): nil
---@field set_in_motion_highlights fun(self, opts: fFtT_highlights.opts, utils: utils, bufnr: number, char: string, reverse: boolean): nil
---@field set_match_highlights fun(self, opts: fFtT_highlights.opts, utils: utils, bufnr: number, row: number, line: string, from: number, to: number, reverse: boolean, char: string, count_offset?: integer): integer | nil, integer
---@field get_match_highlight_number_virt_text fun(self, opts: fFtT_highlights.opts, match_count: integer): any, string | nil
---@field set_backdrop_highlight fun(self, opts: fFtT_highlights.opts, bufnr: number, line: string, row: number, from: number, to: number): nil
---@field highlight_jumpable_chars_on_line fun(self, opts: fFtT_highlights.opts): nil
---@field setup_highlight_reset_trigger fun(self, opts: fFtT_highlights.opts, utils: utils, callback: fun(): nil): nil
---@field set_highlights_in_custom_pos fun(self, opts: fFtT_highlights.opts, position_data: table<integer, position_data>): nil
---@field update_fFtT_hl_lines_info fun(self, extmark_id: integer, bufnr: integer): nil
---@field update_unique_hl_lines_info fun(self, extmark_id: integer, bufnr: integer): nil
---@field fFtT_ns number
---@field fFtT_hl_extmarks table<integer, any>
---@field unique_highlight_ns number
---@field unique_hl_extmarks table<integer, any>
---@field backdrop_highlight string
---@field match_highlight string
---@field jump_num_highlight string
---@field jump_num_highlight_single_digit string
---@field unique_highlight string
---@field unique_highlight_secondary string
---@field fTfT_highlight_ns number
---@field clear_fFtT_hl fun(self): nil
---@field clear_unique_char_hl fun(self): nil
local highlight_utils = {
	backdrop_highlight = "fFtTBackDropHighlight",
	match_highlight = "fFtTMatchHighlight",
	jump_num_highlight = "fFtTJumpNumHighlight",
	jump_num_highlight_single_digit = "fFtTJumpNumHighlightSingleDigit",
	unique_highlight = "fFtTUniqueHighlight",
	unique_highlight_secondary = "fFtTUniqueHighlightSecondary",
	fFtT_hl_extmarks = {},
	unique_hl_extmarks = {},
}

function highlight_utils:setup_highlight_groups()
	self.fFtT_ns = vim.api.nvim_create_namespace("highlightFfTtMotion")
	vim.api.nvim_set_hl(0, self.match_highlight, { link = "IncSearch" })
	vim.api.nvim_set_hl(0, self.backdrop_highlight, { link = "Comment" })
	vim.api.nvim_set_hl(0, self.jump_num_highlight, { fg = "#000000", bg = "#ffffff", bold = true })
	vim.api.nvim_set_hl(0, self.jump_num_highlight_single_digit, { link = "IncSearch" })

	self.unique_highlight_ns = vim.api.nvim_create_namespace("highlightfFtTUniqueChars")
	vim.api.nvim_set_hl(0, self.unique_highlight, { fg = "#bbff99", bold = true })
	vim.api.nvim_set_hl(0, self.unique_highlight_secondary, { fg = "#7799ff", bold = true })
end

---@param opts fFtT_highlights.opts
---@param utils utils
---@param callback fun(): nil
function highlight_utils:setup_highlight_reset_trigger(opts, utils, callback)
	vim.on_key(function(_, _)
		if utils:disabled_file_or_buftype(opts) then
			return
		end

		self:clear_fFtT_hl()
		self:clear_unique_char_hl()
		if opts.jumpable_chars.show_instantly_jumpable == "always" then
			self:highlight_jumpable_chars_on_line(opts)
		end
		callback()
	end, vim.api.nvim_create_namespace("highlightFfTtMotionKeyWatcher"))
end

---@param opts fFtT_highlights.opts
function highlight_utils:highlight_jumpable_chars_on_line(opts)
	self:clear_unique_char_hl()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
	if not line then
		return
	end

	--stylua: ignore start
	local reverse_seen = self:highlight_jumpable_chars(opts, bufnr, cursor_row, line, math.max(0, cursor_col - 1 - opts.match_highlight.highlight_radius + 1), cursor_col - 1 , true, opts.jumpable_chars.show_all_jumpable_in_words == "always", opts.jumpable_chars.show_secondary_jumpable == "always")
	local forward_seen = self:highlight_jumpable_chars(opts, bufnr, cursor_row, line, cursor_col + 1, math.min(vim.fn.strchars(line) - 1, cursor_col + 1 + opts.match_highlight.highlight_radius - 1), false, opts.jumpable_chars.show_all_jumpable_in_words == "always", opts.jumpable_chars.show_secondary_jumpable == "always")
	--stlua: ignore end

	if not opts.multi_line.enable or opts.jumpable_chars.show_multiline_jumpable ~= "always" then
		return
	end

	local top_line = math.max(vim.fn.line("w0") - 1, cursor_row - 1 - opts.multi_line.max_lines + 1)
	for cur_row = cursor_row - 1, top_line, -1 do
		line = vim.api.nvim_buf_get_lines(bufnr, cur_row, cur_row + 1, false)[1]
		if not line then
			break
		end
		reverse_seen = self:highlight_jumpable_chars(opts, bufnr, cur_row, line, 0, vim.fn.strchars(line) - 1, true, opts.jumpable_chars.show_all_jumpable_in_words == "always", opts.jumpable_chars.show_secondary_jumpable == "always", reverse_seen)
	end

	local bottom_line  = math.min(vim.fn.line("w$") - 1, cursor_row + 1 + opts.multi_line.max_lines - 1)
	for cur_row = cursor_row + 1, bottom_line do
		line = vim.api.nvim_buf_get_lines(bufnr, cur_row, cur_row + 1, false)[1]
		if not line then
			break
		end
		forward_seen = self:highlight_jumpable_chars(opts, bufnr, cur_row, line, 0, vim.fn.strchars(line) - 1, false, opts.jumpable_chars.show_all_jumpable_in_words == "always", opts.jumpable_chars.show_secondary_jumpable == "always", forward_seen)
	end
end

---@param opts fFtT_highlights.opts
---@param motion string
function highlight_utils:set_on_key_highlights(opts, motion)
	if vim.fn.reg_executing() ~= "" then
		return
	end

	self:clear_fFtT_hl()
	self:clear_unique_char_hl()

	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
	if not line then
		return
	end
	local line_len = vim.fn.strchars(line)
	local line_offset = math.min(opts.max_highlighted_lines_around_cursor, opts.multi_line.max_lines)

	local col_from, col_to, reverse, last_row, inc
	if motion == opts.f or motion == opts.t then
		col_from, col_to =
			cursor_col + 1, math.min(line_len - 1, cursor_col + 1 + opts.match_highlight.highlight_radius - 1)
		last_row = math.min(cursor_row + 1 + line_offset - 1, vim.fn.line("w$") - 1)
		reverse = false
		inc = 1
	elseif motion == opts.F or motion == opts.T then
		col_from, col_to = math.max(0, cursor_col - 1 - opts.match_highlight.highlight_radius + 1), cursor_col - 1
		last_row = math.max(cursor_row - 1 - line_offset + 1, vim.fn.line("w0") - 1)
		reverse = true
		inc = -1
	end

	--stylua: ignore
	---@type table<string, integer> | nil
	local seen = self:highlight_jumpable_chars(opts, bufnr, cursor_row, line, col_from, col_to, reverse, opts.jumpable_chars.show_all_jumpable_in_words ~= "never", opts.jumpable_chars.show_secondary_jumpable ~= "never")

	---iterate from after the cursor line to the top/bottom line of the window
	---handle the cursor line separately below
	for cur_row = cursor_row + inc, last_row, inc do
		line = vim.api.nvim_buf_get_lines(bufnr, cur_row, cur_row + 1, false)[1]
		if not line then
			break
		end
		line_len = vim.fn.strchars(line)
		local l, r = 0, line_len - 1

		if opts.jumpable_chars.show_multiline_jumpable ~= "never" and vim.fn.reg_executing() == "" then
			--stylua: ignore
			seen = self:highlight_jumpable_chars(opts, bufnr, cur_row, line, l, r, reverse, opts.jumpable_chars.show_all_jumpable_in_words ~= "never", opts.jumpable_chars.show_secondary_jumpable ~= "never", seen)
		end

		if opts.backdrop.style.on_key_press == "full" then
			self:set_backdrop_highlight(opts, bufnr, line, cur_row, l, r)
		end
	end

	---cursor line
	if opts.backdrop.style.on_key_press ~= "none" then
		line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
		self:set_backdrop_highlight(opts, bufnr, line, cursor_row, col_from, col_to)
	end

	self.redraw()
end

---@param opts fFtT_highlights.opts
---@param utils utils
---@param bufnr integer
---@param char string
---@param reverse boolean
---FIXME: refactor this function for readability
function highlight_utils:set_in_motion_highlights(opts, utils, bufnr, char, reverse)
	if vim.fn.reg_executing() ~= "" then
		return
	end

	self:clear_fFtT_hl()
	self:clear_unique_char_hl()
	if opts.jumpable_chars.show_instantly_jumpable == "always" then
		self:highlight_jumpable_chars_on_line(opts)
	end

	local cursor_row, col = unpack(vim.api.nvim_win_get_cursor(0))
	cursor_row = cursor_row - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
	if not line then
		return
	end
	local line_len = vim.fn.strchars(line)
	local line_offset = math.min(opts.max_highlighted_lines_around_cursor, opts.multi_line.max_lines)

	local col_from, col_to, last_row, inc
	if reverse then
		col_from, col_to = col, math.max(0, col - opts.match_highlight.highlight_radius + 1)
		last_row = math.max(cursor_row - 1 - line_offset + 1, vim.fn.line("w0") - 1)
		inc = -1
	else
		col_from, col_to = col, math.min(line_len - 1, col + opts.match_highlight.highlight_radius - 1)
		last_row = math.min(cursor_row + 1 + line_offset - 1, vim.fn.line("w$") - 1)
		inc = 1
	end

	---cursor line highlighting. cleared and re-highlighted if a match is not found
	local _, all_row_match_count =
		self:set_match_highlights(opts, utils, bufnr, cursor_row, line, col_from, col_to, reverse, char)
	if opts.backdrop.style.show_in_motion == "upto_next_line" then
		self:set_backdrop_highlight(opts, bufnr, line, cursor_row, col_from, col_to)
	end

	---iterate from after the cursor line to the top/bottom line of the window
	local other_row_match_count = 0
	local stop_highlighting_matches = false
	local another_row_has_backdrop_applied = false

	for cur_row = cursor_row + inc, last_row, inc do
		line = vim.api.nvim_buf_get_lines(bufnr, cur_row, cur_row + 1, false)[1]
		if not line then
			break
		end
		line_len = vim.fn.strchars(line)
		local l, r = 0, math.min(line_len - 1, opts.match_highlight.highlight_radius - 1)
		if reverse then
			l, r = line_len - 1, math.max(line_len - 1 - opts.match_highlight.highlight_radius + 1, 0)
		end

		if opts.backdrop.style.show_in_motion == "full" then
			self:set_backdrop_highlight(opts, bufnr, line, cur_row, l, r)
		end

		local first_matching_col = nil
		if not stop_highlighting_matches then
			for i = l, r, inc do
				if utils:char_is_equal(opts, line:sub(i + 1, i + 1), char) then
					local virt_text, virt_text_pos =
						self:get_match_highlight_number_virt_text(opts, all_row_match_count)
					if opts.match_highlight.enable then
						local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, self.fFtT_ns, cur_row, i, {
							virt_text = virt_text,
							virt_text_pos = virt_text_pos,
							end_col = i + 1,
							hl_group = self.match_highlight,
							priority = opts.match_highlight.priority,
						})
						self:update_fFtT_hl_lines_info(extmark_id, bufnr)
					end
					all_row_match_count = all_row_match_count + 1
					other_row_match_count = other_row_match_count + 1
					if first_matching_col == nil then
						first_matching_col = i
					end
					if opts.match_highlight.style ~= "full" then
						break
					end
				end
			end

			if opts.backdrop.style.show_in_motion == "upto_next_line" and not another_row_has_backdrop_applied then
				if first_matching_col ~= nil then
					another_row_has_backdrop_applied = true
					self:set_backdrop_highlight(opts, bufnr, line, cur_row, l, first_matching_col)
				elseif first_matching_col == nil then
					self:set_backdrop_highlight(opts, bufnr, line, cur_row, l, r)
				end
			end
		elseif opts.backdrop.style.show_in_motion ~= "full" then
			break
		end

		--- highlight only one matching character in another line; setting backdro accordingly
		if first_matching_col ~= nil and opts.match_highlight.style ~= "full" then
			stop_highlighting_matches = true
		end
	end

	if opts.backdrop.style.show_in_motion == "full" then
		line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
		local _, match_count =
			self:set_match_highlights(opts, utils, bufnr, cursor_row, line, col_from, col_to, reverse, char)
		if match_count > 1 then
			self:set_backdrop_highlight(opts, bufnr, line, cursor_row, col_from, col_to)
		end
		self.redraw()
		return
	end

	---@return integer | nil, integer | nil
	local get_char_boundaries_in_cursor_line = function()
		line = vim.api.nvim_buf_get_lines(bufnr, cursor_row, cursor_row + 1, false)[1]
		local char_pos_first, char_pos_last = nil, nil
		for i = col_from, col_to, inc do
			if utils:char_is_equal(opts, line:sub(i + 1, i + 1), char) then
				if char_pos_first == nil then
					char_pos_first = i
				end
				char_pos_last = i
			end
		end
		return char_pos_first, char_pos_last
	end

	if other_row_match_count > 0 then
		if opts.backdrop.style.show_in_motion == "current_line" then
			local char_pos_first, char_pos_last = get_char_boundaries_in_cursor_line()
			if char_pos_first ~= nil and char_pos_last ~= nil and char_pos_first ~= char_pos_last then
				self:set_backdrop_highlight(opts, bufnr, line, cursor_row, char_pos_first, char_pos_last)
			end
		end
		self.redraw()
		return
	end

	---No match found in other lines;
	---need to manually highlight the current line as it may be a special case depending on the user configuration
	self:clear_fFtT_hl()
	local char_pos_first, char_pos_last = get_char_boundaries_in_cursor_line()

	if char_pos_first == nil or char_pos_last == nil then
		self.redraw()
		return
	end

	--stylua: ignore
	local _, match_count = self:set_match_highlights(opts, utils, bufnr, cursor_row, line, char_pos_first, char_pos_last, reverse, char)
	if match_count <= 1 then
		self:clear_fFtT_hl()
	elseif
		opts.backdrop.style.show_in_motion == "current_line"
		or opts.backdrop.style.show_in_motion == "upto_next_line"
	then
		self:set_backdrop_highlight(opts, bufnr, line, cursor_row, char_pos_first, char_pos_last)
	elseif opts.backdrop.style.show_in_motion == "full" then
		self:set_backdrop_highlight(opts, bufnr, line, cursor_row, col_from, col_to)
	end

	self.redraw()
end

---@param opts fFtT_highlights.opts
---@param utils utils
---@param bufnr integer
---@param row integer
---@param line string
---@param from integer
---@param to integer
---@param reverse boolean
---@param char string
---@param count_offset? integer
---@return integer | nil, integer
function highlight_utils:set_match_highlights(opts, utils, bufnr, row, line, from, to, reverse, char, count_offset)
	if not opts.match_highlight.enable then
		return nil, 0
	end

	local inc = reverse and -1 or 1
	local match_col, match_count = nil, count_offset or 0

	for i = from, to, inc do
		if utils:char_is_equal(opts, line:sub(i + 1, i + 1), char) then
			local virt_text, virt_text_pos = self:get_match_highlight_number_virt_text(opts, match_count)
			local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, self.fFtT_ns, row, i, {
				virt_text = virt_text,
				virt_text_pos = virt_text_pos,
				end_col = i + 1,
				hl_group = self.match_highlight,
				priority = opts.match_highlight.priority,
			})
			self:update_fFtT_hl_lines_info(extmark_id, bufnr)
			match_count = match_count + 1
			match_col = i
		end
	end
	return match_col, match_count
end

---@param opts fFtT_highlights.opts
---@param match_count integer
---@return any, string | nil
function highlight_utils:get_match_highlight_number_virt_text(opts, match_count)
	if not opts.match_highlight.enable or not opts.match_highlight.show_jump_numbers or match_count <= 0 then
		return nil, nil
	end
	local match_str = string.format("%d", match_count)
	local virt_text_pos = vim.fn.strcharlen(match_str) <= 1 and "overlay" or "inline"
	local virt_text = {
		{
			match_str,
			vim.fn.strcharlen(match_str) <= 1 and self.jump_num_highlight_single_digit or self.jump_num_highlight,
		},
	}
	return virt_text, virt_text_pos
end

---@param opts fFtT_highlights.opts
---@param bufnr integer
---@param line string
---@param row integer
---@param from integer
---@param to integer
function highlight_utils:set_backdrop_highlight(opts, bufnr, line, row, from, to)
	if from > to then
		from, to = to, from
	end

	if opts.backdrop.border_extend then
		from = math.max(0, from - opts.backdrop.border_extend)
		to = math.min(vim.fn.strchars(line) - 1, to + opts.backdrop.border_extend)
	end

	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, self.fFtT_ns, row, from, {
		end_col = to + 1,
		hl_group = self.backdrop_highlight,
		priority = opts.backdrop.priority,
	})
	self:update_fFtT_hl_lines_info(extmark_id, bufnr)
end

---@param opts fFtT_highlights.opts
---@param position_data table<integer, position_data>
function highlight_utils:set_highlights_in_custom_pos(opts, position_data)
	for _, curpos_data in ipairs(position_data) do
		local extmark_id =
			vim.api.nvim_buf_set_extmark(curpos_data.bufnr, self.fFtT_ns, curpos_data.row, curpos_data.col, {
				end_col = curpos_data.col + 1,
				hl_group = self.match_highlight,
				priority = opts.match_highlight.priority,
			})
		self:update_fFtT_hl_lines_info(extmark_id, curpos_data.bufnr)
	end
end

---@param extmark_id integer
---@param bufnr integer
function highlight_utils:update_unique_hl_lines_info(extmark_id, bufnr)
	self.unique_hl_extmarks[#self.unique_hl_extmarks + 1] = { bufnr, extmark_id }
end

---@param extmark_id integer
---@param bufnr integer
function highlight_utils:update_fFtT_hl_lines_info(extmark_id, bufnr)
	self.fFtT_hl_extmarks[#self.fFtT_hl_extmarks + 1] = { bufnr, extmark_id }
end

function highlight_utils:clear_fFtT_hl()
	for _, data in ipairs(self.fFtT_hl_extmarks) do
		pcall(vim.api.nvim_buf_del_extmark, data[1], self.fFtT_ns, data[2])
	end
	self.fFtT_hl_extmarks = {}
end

function highlight_utils:clear_unique_char_hl()
	for _, data in ipairs(self.unique_hl_extmarks) do
		pcall(vim.api.nvim_buf_del_extmark, data[1], self.unique_highlight_ns, data[2])
	end
	self.unique_hl_extmarks = {}
end

highlight_utils.redraw = function()
	vim.schedule(function()
		vim.cmd("redraw!")
	end)
end

---@param opts fFtT_highlights.opts
---@param bufnr integer
---@param row integer
---@param line string
---@param from integer
---@param to integer
---@param reverse boolean
---@param show_all_jumpable boolean
---@param show_secondary_chars boolean
---@param seen? table<string, integer>
---@return table<string, integer> | nil
--stylua: ignore
function highlight_utils:highlight_jumpable_chars(opts, bufnr, row, line, from, to, reverse, show_all_jumpable, show_secondary_chars, seen)
	if opts.jumpable_chars.show_instantly_jumpable == "never" then
		return nil
	end
	if from > to then
		return seen
	end

	local inc = 1
	if reverse then
		from, to = to, from
		inc = -1
	end

	local line_len = vim.fn.strchars(line)

	if not seen then
		seen = {}
	end
	local word_ended = true
	local word_ended_secondary = true
	local last_highlighted_index = reverse and 999999999 or -999999999
	local last_highlighted_secondary_index = reverse and 999999999 or -999999999

	local acceptable_distance = function(l, r)
		if l > r then
			l, r = r, l
		end
		return r - l - 1 >= opts.jumpable_chars.min_gap
	end

	for i = from, to, inc do
		local char = line:sub(i + 1, i + 1)
		if opts.case_sensitivity ~= "default" then
			char = char:lower()
		end

		local reset_flag = false
		if vim.fn.match(char, '[^A-Za-z0-9]') ~= -1 then
			reset_flag = true
		elseif i + inc >= 0 and i + inc < line_len then
			local char2 = line:sub(i + 1 + inc, i + 1 + inc)
			if (char == char:lower()) ~= (char2 == char2:lower()) then
				reset_flag = true
			end
		end

		word_ended = word_ended or reset_flag
		word_ended_secondary = word_ended_secondary or reset_flag

		local extmark_id = nil
		if not seen[char] then
			seen[char] = 1
			if i < line_len and (show_all_jumpable or (word_ended and acceptable_distance(i, last_highlighted_index))) then
				last_highlighted_index = i
				word_ended = false
				extmark_id = vim.api.nvim_buf_set_extmark(bufnr, self.unique_highlight_ns, row, i, {
					end_col = i + 1,
					hl_group = self.unique_highlight,
					priority = opts.jumpable_chars.priority,
				})
			end
		elseif show_secondary_chars and seen[char] == 1 then
			seen[char] = 2
			if i < line_len and (show_all_jumpable or (word_ended_secondary and acceptable_distance(i, last_highlighted_secondary_index))) then
				last_highlighted_secondary_index = i
				word_ended_secondary = false
				extmark_id = vim.api.nvim_buf_set_extmark(bufnr, self.unique_highlight_ns, row, i, {
					end_col = i + 1,
					hl_group = self.unique_highlight_secondary,
					priority = opts.jumpable_chars.priority_secondary,
				})
			end
		end

		if extmark_id then
			self:update_unique_hl_lines_info(extmark_id, bufnr)
		end

		word_ended = word_ended or reset_flag
		word_ended_secondary = word_ended_secondary or reset_flag
	end

	return seen
end

return highlight_utils
