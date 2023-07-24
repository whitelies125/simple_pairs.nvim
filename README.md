# simple_comment.nvim

用于自动补全成对括号、删除成对括号、跳出右括号、成对括号内回车缩进的 neovim 插件。

# usage

### 补全成对括号

`|` 表示光标

```
-- before
if|
-- after input (
if()|

-- before
|
-- after input ([{'"<
([{'"<|>"'}])
```

### 删除成对括号

```
-- before
if(|)
-- after input <BS>(backspace)
if|

-- before
([{'"<|>"'}])
-- after input six <BS>
|
```

### 跳出右括号

```
-- before
if(|)
-- after input )
if()|

-- before
([{'"<|>"'}])
-- after input >"'}])
([{'"<>"'}])|
```

### 成对括号内回车缩进

```
-- before
if(|)
-- after input <CR>(enter) which actually mapping to <CR><ESC>O
if(
	|
)
```

# install

使用 lazy.nvim :

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