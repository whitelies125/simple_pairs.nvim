local M = {}
-- 兼容不同 Lua 版本：Lua 5.1 使用全局 `unpack`，Lua 5.2+ 使用 `table.unpack`
local unpack = table.unpack or unpack
local pairs_config = {}
local right_pairs_set = {}

local function when_input_pair_left(pair_left)
    local pair_right = pairs_config[pair_left]
    if pair_right then
        return pair_left .. pair_right .. "<Left>"
    end
    return pair_left
end

-- char_right: normal mode 当前光标所在的字符, insert mode 中当前光标右侧的首个字符
-- char_left: normal mode 当前光标所在字符的左侧首个字符, insert mode 中当前光标左侧的首个字符
local function get_char_left_right()
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
    if col == 0 then
        -- 防止在行首获取行首之前的字符
        return nil, char_right
    end
    local char_left = vim.api.nvim_buf_get_text(0, row-1, col-1, row-1, col, {})[1]
    return char_left, char_right
end

local function when_input_pair_right(pair_right)
    local _, char_right = get_char_left_right()
    if char_right == pair_right then
        return "<Right>"
    end
    return pair_right
end

local function when_input_pair_ambiguous(pair_ambiguous)
    -- 先尝试作为 pair_right 处理
    local ret = when_input_pair_right(pair_ambiguous)
    if ret == "<Right>" then return ret end

    -- 再作为 pair_left 处理
    return when_input_pair_left(pair_ambiguous)
end

function M.when_input_enter()
    local char_left, char_right = get_char_left_right()
    if char_left == nil then return "<CR>" end
    if char_right == pairs_config[char_left] then
        return "<CR><ESC>O"
    else
        return "<CR>"
    end
end

function M.when_input_backspace()
    local char_left, char_right = get_char_left_right()
    if char_left == nil then return "<BS>" end
    if char_right == pairs_config[char_left] then
        return "<BS><Del>"
    else
        return "<BS>"
    end
end

function M.move_pair_right()
    local _, char_right = get_char_left_right()
    if right_pairs_set[char_right] then
        vim.cmd("normal! xep")
        return
    end
end

function M.move_pair_left()
    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local char_right = line:sub(col+1, col+1)
    if right_pairs_set[char_right] then
        if col == #line - 1 then
            vim.cmd("normal! xhp")
        else
            vim.cmd("normal! xhhp")
        end
        return
    end
end

local function get_current_visual_range()
    local _, v_row, v_col = unpack(vim.fn.getpos("v"))
    local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    -- nvim_win_get_cursor 的列是 0-based，这里转成 1-based 以便和 getpos("v") 的列坐标一致。
    cur_col = cur_col + 1

    local start_row, start_col, end_row, end_col
    if (v_row < cur_row) or (v_row == cur_row and v_col <= cur_col) then
        start_row, start_col = v_row, v_col
        end_row, end_col = cur_row, cur_col
    else
        start_row, start_col = cur_row, cur_col
        end_row, end_col = v_row, v_col
    end
    return start_row, start_col, end_row, end_col
end

local function exit_visual_mode()
    vim.api.nvim_input("<Esc>")
end

local function when_input_pair_in_visual(pair_left)
    local pair_right = pairs_config[pair_left]
    if not pair_right then
        return
    end
    local visual_mode = vim.fn.visualmode()
    if visual_mode ~= "v" then
        vim.notify("simple_pairs.nvim: only characterwise visual mode is supported.", vim.log.levels.WARN)
        exit_visual_mode()
        return
    end
    local start_row, start_col, end_row, end_col = get_current_visual_range()
    if start_row ~= end_row then
        vim.notify("simple_pairs.nvim: not support multiple lines.", vim.log.levels.WARN)
        exit_visual_mode()
        return
    end
    local line = vim.api.nvim_get_current_line()
    local str = line:sub(start_col, end_col)
    if #str == 1 then
        --[[
        主要为了解决 visual mode 仅选中一个字符，且该字符的 pair_left == pair_right 的场景
        为了更符合直觉，该场景按形如 |word| 场景处理，而非删除该字符
        --]]
        line = line:sub(1, start_col-1) .. pair_left .. line:sub(start_col, end_col) .. pair_right .. line:sub(end_col+1)
        goto set_line
    end
    if str:sub(1,1) == pair_left and str:sub(-1) == pair_right then
        -- '|' '|' 之间表示选中的字符串选中
        -- 形如 |"word"|, 选中字符串串内头尾为 pair_left 和 pair_right
        line = line:sub(1, start_col-1) .. line:sub(start_col+1, end_col-1) .. line:sub(end_col+1)
        goto set_line
    end

    str = line:sub(start_col-1, end_col+1)
    if str:sub(1,1) == pair_left and str:sub(-1) == pair_right then
        -- 形如 "|word|", 选中字符串串外头尾为 pair_left 和 pair_right
        line = line:sub(1, start_col-2) .. line:sub(start_col, end_col) .. line:sub(end_col+2)
        goto set_line
    end
    -- 形如 |word|
    line = line:sub(1, start_col-1) .. pair_left .. line:sub(start_col, end_col) .. pair_right .. line:sub(end_col+1)

    ::set_line::
    vim.api.nvim_set_current_line(line)
    exit_visual_mode()
end

function M.setup(opts)
    opts = opts or {}
    -- config
    local default_pairs_config = {
        ['{'] = '}',
        ['('] = ')',
        ['['] = ']',
        ['\''] = '\'',
        ['"'] = '"',
    }
    pairs_config = opts.pairs_config or default_pairs_config
    right_pairs_set = {}
    for _, v in pairs(pairs_config) do
        right_pairs_set[v] = true
    end
    local visual_model_trigger_key = opts.visual_model_trigger_key
    -- keymap
    local keymap_opts = { noremap = true, silent = true }
    local keymap_expr_opts = { noremap = true, silent = true, expr = true}
    for k,v in pairs(pairs_config) do
        --[[
        expr 为 true，表示映射的是一个表达式，将会使用使用求解该表达的值作为映射结果
        例如，此处 when_input_pair_ambiguous(k) 函数的返回值为一个字符串
        若 expr 为 flase，则仅仅调用此处的匿名函数
        若 expr 为 true，则是将返回的字符串作为最终的映射 {rhs}
        --]]
        if k == v then
            vim.keymap.set('i', k, function() return when_input_pair_ambiguous(k) end, keymap_expr_opts)
        else
            vim.keymap.set('i', k, function() return when_input_pair_left(k) end, keymap_expr_opts)
            vim.keymap.set('i', v, function() return when_input_pair_right(v) end, keymap_expr_opts)
        end

        if visual_model_trigger_key then
            if k == v then
                vim.keymap.set('v', visual_model_trigger_key .. k, function() when_input_pair_in_visual(k) end, keymap_opts)
            else
                vim.keymap.set('v', visual_model_trigger_key .. k, function() when_input_pair_in_visual(k) end, keymap_opts)
                vim.keymap.set('v', visual_model_trigger_key .. v, function() when_input_pair_in_visual(k) end, keymap_opts)
            end
        end
    end
end

return M
