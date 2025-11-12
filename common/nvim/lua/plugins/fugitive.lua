return {
    'tpope/vim-fugitive',
    enable = true,
    config = function()
        vim.keymap.set("n", "<leader>gs", vim.cmd.Git);
    end
}

