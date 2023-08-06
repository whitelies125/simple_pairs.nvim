local M = {}

local pairs_config = {
    ['{'] = '}',
    ['('] = ')',
    ['['] = ']',
    ['\''] = '\'',
    ['"'] = '"',
}

local function when_input_pair_left(pair_left)
    local pair_right = pairs_config[pair_left]
    if pair_right then
        return pair_left .. pair_right .. "<Left>"
    end
    return pair_left
end

local function when_input_pair_right(pair_right)
    --[[
    nvim_win_get_cursor()
    获得当前光标位置
    返回值：(row, col)
    Note:
        row 是从 1 开始计数的，即认为第一行的行号为 1
        col 是以 0 开始计数的
    --]]
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    --[[
    vim.api.nvim_buf_get_text({buffer}, {start_row}, {start_col}, {end_row}, {end_col}, {opts})
    Parameters:
        {buffer} Buffer handle, or 0 for current buffer
        {start_row} First line index，闭区间
        {start_col} Starting column (byte offset) on first line，闭区间
        {end_row} Last line index, inclusive，闭区间
        {end_col} Ending column (byte offset) on last line, exclusive，开区间
        {opts} Optional parameters. Currently unused.
    Return:
        Array of lines, or empty array for unloaded buffer.
    Note:
        该 api 填入参数的行、列都是从 0 开始计数
        所以对该 api 来说，即认为第一行的行号为 0
    --]]
    local char_right = vim.api.nvim_buf_get_text(0, row-1, col, row-1, col+1, {})[1]
    if char_right == pair_right then
        return "<Right>"
    end
    return pair_right
end

local function when_input_pair_ambiguous(pair_ambiguous)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local char_right = vim.api.nvim_buf_get_text(0, row-1, col, row-1, col+1, {})[1]
    if char_right == pair_ambiguous then
        return "<Right>"
    end

    return when_input_pair_left(pair_ambiguous)
end

local function when_input_enter()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local char_left = vim.api.nvim_buf_get_text(0, row-1, col-1, row-1, col, {})[1]
    local char_right = vim.api.nvim_buf_get_text(0, row-1, col, row-1, col+1, {})[1]
    if pairs_config[char_left] and char_right == pairs_config[char_left] then
        return "<CR><ESC>O"
    else
        return "<CR>"
    end
end

local function when_input_backspace()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local char_left = vim.api.nvim_buf_get_text(0, row-1, col-1, row-1, col, {})[1]
    local char_right = vim.api.nvim_buf_get_text(0, row-1, col, row-1, col+1, {})[1]
    if pairs_config[char_left] and char_right == pairs_config[char_left] then
        return "<BS><Del>"
    else
        return "<BS>"
    end
end

function when_input_pair_in_visual(pair_left)
    if not pairs_config[pair_left] then
        return
    end
    local _, start_row, start_col, _ = unpack(vim.fn.getpos("'<"))
    local _, end_row, end_col, _ = unpack(vim.fn.getpos("'>"))
    if start_row ~= end_row then
        print("simple_paris.nvim : not support multiple lines.")
        return
    end
    if end_col == vim.v.maxcol then
        --[[
        col("$")
        返回光标行的行尾 (返回光标行的字节数加 1)
        --]]
        end_col = vim.fn.col("$") - 1
    end

    local str = vim.api.nvim_buf_get_text(0, start_row-1, start_col-1, end_row-1, end_col, {})[1]
    if str:sub(1,1) == pair_left and str:sub(-1) == pairs_config[pair_left] then
        vim.api.nvim_buf_set_text(0, end_row-1, end_col-1, end_row-1, end_col, {})
        vim.api.nvim_buf_set_text(0, start_row-1, start_col-1, start_row-1, start_col, {})
    else
        vim.api.nvim_buf_set_text(0, end_row-1, end_col, end_row-1, end_col, {pairs_config[pair_left]})
        vim.api.nvim_buf_set_text(0, start_row-1, start_col-1, start_row-1, start_col-1, {pair_left})
    end
end

function M.setup(opts)
    local keymap_opts = { noremap = true, silent = true, expr = true}
    for k,v in pairs(pairs_config) do
        --[[
        expr 为 true，表示映射的是一个表达式，将会使用使用求解该表达的值作为映射结果
        例如，此处 auto_complete_pairs(k) 函数的返回值为一个字符串
        若 expr 为 flase，则仅仅调用此处的匿名函数
        若 expr 为 true，则是将返回的字符串作为最终的映射 {rhs}
        --]]
        if k == v then
            vim.keymap.set('i', k, function() return when_input_pair_ambiguous(k) end, keymap_opts)
        else
            vim.keymap.set('i', k, function() return when_input_pair_left(k) end, keymap_opts)
            vim.keymap.set('i', v, function() return when_input_pair_right(v) end, keymap_opts)
        end
        if k == "'" or k == '"' then
            vim.keymap.set('v', k, ":lua when_input_pair_in_visual(\"\\".. k .."\")<CR>", { noremap = true, silent = true })
        else
            vim.keymap.set('v', k, ":lua when_input_pair_in_visual(\"".. k .."\")<CR>", { noremap = true, silent = true })
        end
    end
    vim.keymap.set('i', '<CR>', function() return when_input_enter() end, keymap_opts)
    vim.keymap.set('i', '<BS>', function() return when_input_backspace() end, keymap_opts)
end

return M
