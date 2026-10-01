return {
	"olimorris/onedarkpro.nvim",
	priority = 1000, -- Ensure it loads first
	enable = true,
	config = function() vim.cmd("colorscheme onedark") end
}

