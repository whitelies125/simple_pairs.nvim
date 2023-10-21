# simple_comment.nvim

用于自动补全成对括号、删除成对括号、跳出右括号、成对括号内回车缩进的 neovim 插件。

a simple autopairs plugin for neovim

# usage

`|` 表示光标

`|` means cursor

### 补全成对括号 complete pair_right

```
-- before
if|
-- after input (
if()|

-- before
|
-- after input ([{'"
([{'"|"'}])
```

### 删除成对括号 delete pair_right

```
-- before
if(|)
-- after input <BS>(backspace)
if|

-- before
([{'"|"'}])
-- after input <BS> 6 times
|
```

### 跳出右括号 jump out pair_right

```
-- before
if(|)
-- after input )
if()|

-- before
([{'"|"'}])
-- after input "'}])
([{'""'}])|
```

### 成对括号内回车缩进 insert new line after input <CR> in pair

```
-- before
if(|)
-- after input <CR>(enter) which actually mapping to <CR><ESC>O
if(
	|
)
```

### insert 模式下成对括号移动 fast move pair_right in insert mode

```
-- before
|word
-- input "
"|"word"
-- input <C-E>
"word|"
-- input <C-Y>
"wor|"d
```

### visual 模式下选中本文加括号 bracket or unbracket selected string in visual mode

```
-- before
word
-- select string "word" and then input <Space>"
"word"
-- select string "word" or word, and then input <Space>" again
word
```

# install

lazy.nvim :

```
{
    "whitelies125/simple_pairs.nvim",
    -- pairs config
    opts = {
        pairs_config = {
            ['{'] = '}',
            ['('] = ')',
            ['['] = ']',
            ['\''] = '\'',
            ['"'] = '"',
        },
        -- 用于 visual_model 下对选中字符串添加 pair 的 {lhs} 的前缀按键
        -- 若不设置，或设为 nil，false 则表示不使用该功能
        visual_model_trigger_key = "<Space>"
    },
    config = function(_, opts)
        local sp = require("simple_pairs")
        sp.setup(opts)

        -- keymap
        local keymap_opts = { noremap = true, silent = true }
        local keymap_expr_opts = { noremap = true, silent = true, expr = true}
        vim.keymap.set('i', '<CR>', function() return sp.when_input_enter() end, keymap_expr_opts)
        vim.keymap.set('i', '<BS>', function() return sp.when_input_backspace() end, keymap_expr_opts)
        vim.keymap.set('i', '<C-E>', sp.move_pair_right, keymap_opts)
        vim.keymap.set('i', '<C-Y>', sp.move_pair_left, keymap_opts)
    end,
}
```

# reference

https://github.com/m4xshen/autoclose.nvim, very tidy and helpful for me.
