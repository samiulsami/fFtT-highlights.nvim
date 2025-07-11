---@class utils
---@field get_char fun(self): string | nil
---@field char_is_equal fun(self, opts: fFtT_highlights.opts, string_char: string, typed_char: string): boolean
---@field is_reverse fun(self, opts: fFtT_highlights.opts, motion: string, last_motion?: string): boolean
---@field jump_to_next_char fun(self, opts: fFtT_highlights.opts, motion: string, char: string, reverse: boolean, extra_flags?: string): integer | nil, integer | nil
---@field disabled_file_or_buftype fun(self, opts: fFtT_highlights.opts): boolean
---@field charmap table<string, string>
local utils = {
	charmap = { --HACK:
		["<space>"] = " ",
		["<lt>"] = "<",
	},
}

---@return string | nil
function utils:get_char()
	local ok, key = pcall(vim.fn.getcharstr)
	if not ok then
		return nil
	end

	local char = vim.fn.keytrans(key)
	return self.charmap[char:lower()] or char
end

---@param opts fFtT_highlights.opts
---@param string_char string
---@param typed_char string
---@return boolean
function utils:char_is_equal(opts, string_char, typed_char)
	if opts.case_sensitivity == "default" then
		return string_char == typed_char
	end

	if opts.case_sensitivity == "smart_case" then
		if typed_char == typed_char:lower() then
			return typed_char:lower() == string_char:lower()
		end
		return string_char == typed_char
	end

	return string_char:lower() == typed_char:lower()
end

---@param opts fFtT_highlights.opts
---@param motion string
---@param last_motion? string
---NOTE: Does not consider smart motions
function utils:is_reverse(opts, motion, last_motion)
	if motion == opts.f or motion == opts.t then
		return false
	end
	if motion == opts.F or motion == opts.T then
		return true
	end

	if not last_motion then
		return motion == opts.prev
	end
	local reverse = (last_motion == opts.F or last_motion == opts.T)
	if motion == opts.prev then
		reverse = not reverse
	end
	return reverse
end

---@param opts fFtT_highlights.opts
---@param motion string
---@param char string
---@param reverse boolean
---@param extra_flags? string
---@return integer | nil, integer | nil
-- NOTE: stolen from:
--https://github.com/echasnovski/mini.jump/blob/main/lua/mini/jump.lua#L422
function utils:jump_to_next_char(opts, motion, char, reverse, extra_flags)
	char = vim.fn.escape(char, [[\]])

	local flags = reverse and "Wb" or "W"
	if extra_flags then
		flags = flags .. extra_flags
	end
	if not flags:find("n") then
		flags = flags .. "s"
	end

	local pattern

	if motion == opts.t or motion == opts.T then
		if reverse then
			pattern = char .. [[\@<=\_.]]
		else
			pattern = [[\_.\ze]] .. char
		end
	else
		local is_visual = vim.tbl_contains({ "v", "V", "\22" }, vim.fn.mode())
		local is_exclusive = vim.o.selection == "exclusive"
		if not reverse and is_visual and is_exclusive then
			pattern = char .. [[\zs\_.]]
		else
			pattern = char
		end
	end

	local ignore_case = opts.case_sensitivity == "ignore_case"
		or (opts.case_sensitivity == "smart_case" and char == char:lower())
	local prefix = ignore_case and [[\V\c]] or [[\V\C]]
	pattern = prefix .. pattern

	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line_limit = math.min(vim.fn.line("w$"), row + 1 + opts.multi_line.max_lines - 1)
	if reverse then
		line_limit = math.max(vim.fn.line("w0"), row - 1 - opts.multi_line.max_lines + 1)
	end

	row, col = unpack(vim.fn.searchpos(pattern, flags, line_limit, 300))
	return row, col
end

---@param opts fFtT_highlights.opts
---@return boolean
function utils:disabled_file_or_buftype(opts)
	if vim.tbl_contains(opts.disabled_filetypes, vim.bo.filetype) then
		return true
	end
	return vim.tbl_contains(opts.disabled_buftypes, vim.bo.buftype)
end

return utils
