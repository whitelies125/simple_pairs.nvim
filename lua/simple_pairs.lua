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

local function move_pair_right()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    -- ""word word2
    local line = vim.api.nvim_get_current_line()
    local char_left = line:sub(col, col)
    local char_right = line:sub(col+1, col+1)
    if pairs_config[char_left] ~= char_right then
        return
    end

    local word = vim.fn.expand('<cword>')
    local target_pos = col + word:len()
    -- "word word2
    line = line:sub(1, col) .. line:sub(col+2)
    -- "word" word2
    line = line:sub(1, target_pos) .. char_right .. line:sub(target_pos + 1)
    --[[
    这里，此时直接使用 vim.api.nvim_set_current_line() 或其它修改该行文本的函数 or 操作会报错
    这里猜测是因为 textlock 所致，因此使用 schedule() 避免 textlock，成功！
    至于什么情况下会有 textlock，vim 和 neovim 中关于 textlock 的说明都很少，所以暂时没深究
    --]]
    vim.schedule(function() vim.api.nvim_set_current_line(line) end)
    --[[
    nvim_win_set_cursor({window}, {pos})
    Sets the (1,0)-indexed cursor position in the window.
    Parameters:
    {window} Window handle, or 0 for current window
    {pos} (row, col) tuple representing the new position
    --]]
    vim.api.nvim_win_set_cursor(0, {row, target_pos})
end

function when_input_pair_in_visual(pair_left)
    local pair_right = pairs_config[pair_left]
    if not pair_right then
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

    local line = vim.api.nvim_get_current_line()
    local str = line:sub(start_col, end_col)
    if str:sub(1,1) == pair_left and str:sub(-1) == pair_right then
        -- '|' '|' 之间表示选中的字符串选中
        -- 形如 |"word"|, 选中字符串串内头尾为 pair_left 和 pair_right
        line = line:sub(1, start_col-1) .. line:sub(start_col+1, end_col-1) .. line:sub(end_col+1)
        vim.api.nvim_set_current_line(line)
        return
    end

    local str = line:sub(start_col-1, end_col+1)
    if str:sub(1,1) == pair_left and str:sub(-1) == pair_right then
        -- 形如 "|word|", 选中字符串串外头尾为 pair_left 和 pair_right
        line = line:sub(1, start_col-2) .. line:sub(start_col, end_col) .. line:sub(end_col+2)
        vim.api.nvim_set_current_line(line)
        return
    end
    -- 形如 |word|
    line = line:sub(1, start_col-1) .. pair_left .. line:sub(start_col, end_col) .. pair_right .. line:sub(end_col+1)
    vim.api.nvim_set_current_line(line)
end

function M.setup(opts)
    local keymap_opts = { noremap = true, silent = true }
    local keymap_expr_opts = { noremap = true, silent = true, expr = true}
    for k,v in pairs(pairs_config) do
        --[[
        expr 为 true，表示映射的是一个表达式，将会使用使用求解该表达的值作为映射结果
        例如，此处 auto_complete_pairs(k) 函数的返回值为一个字符串
        若 expr 为 flase，则仅仅调用此处的匿名函数
        若 expr 为 true，则是将返回的字符串作为最终的映射 {rhs}
        --]]
        if k == v then
            vim.keymap.set('i', k, function() return when_input_pair_ambiguous(k) end, keymap_expr_opts)
        else
            vim.keymap.set('i', k, function() return when_input_pair_left(k) end, keymap_expr_opts)
            vim.keymap.set('i', v, function() return when_input_pair_right(v) end, keymap_expr_opts)
        end
        if k == v then
            vim.keymap.set('v', "<Space>" .. k, ":lua when_input_pair_in_visual(\"\\".. k .."\")<CR>", keymap_opts)
        else
            vim.keymap.set('v', "<Space>" .. k, ":lua when_input_pair_in_visual(\"".. k .."\")<CR>", keymap_opts)
        end
    end
    vim.keymap.set('i', '<CR>', function() return when_input_enter() end, keymap_expr_opts)
    vim.keymap.set('i', '<BS>', function() return when_input_backspace() end, keymap_expr_opts)
    vim.keymap.set('i', '<C-E>', function() move_pair_right() end, keymap_opts)
end

return M
