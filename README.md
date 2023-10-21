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
    config = function(_, opts)
        require("simple_pairs").setup()
    end,
}
```

# reference

https://github.com/m4xshen/autoclose.nvim, very tidy and helpful for me.
