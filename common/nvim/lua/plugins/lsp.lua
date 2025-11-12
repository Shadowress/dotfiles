return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},

	{
		"williamboman/mason-lspconfig.nvim",
        dependencies = {
            "neovim/nvim-lspconfig",
            "williamboman/mason.nvim",
        },
		config = function()
            local mason_lspconfig = require("mason-lspconfig")
            local lspconfig = require("lspconfig")

			mason_lspconfig.setup({
				ensure_installed = {
					-- Python
					"pyright",

					-- JavaScript/TypeScript
					"ts_ls",

					-- Java
					"jdtls",

					-- Lua
					"lua_ls",
				},
                automatic_installation = true,
			})

            local servers = mason_lspconfig.get_installed_servers()
            for _, server in ipairs(servers) do
                if server == "lua_ls" then
                    lspconfig.lua_ls.setup({
                        settings = {
                            Lua = { diagnostics = { globals = { "vim" } } },
                        },
                    })
                else
                    lspconfig[server].setup({})
                end
            end
		end
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					-- Python formatter
					"black",

					-- Python linter
					"flake8",

					-- JavaScript/TypeScript formatter
					"prettier",

					-- JavaScript/TypeScript linter
					"eslint_d",

					-- Java formatter
					"google-java-format",
				},
				auto_update = true,
				run_on_start = true,
			})
		end
	},


	{
		"VonHeikemen/lsp-zero.nvim",
		branch = "v3.x",
		dependencies = {
			"neovim/nvim-lspconfig",
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
            "WhoIsSethDaniel/mason-tool-installer.nvim",
			"hrsh7th/nvim-cmp",
			"hrsh7th/cmp-nvim-lsp",
			"L3MON4D3/LuaSnip",
		},
		enable = true,
		config = function()
			local lsp = require("lsp-zero")
			local cmp = require("cmp")

            cmp.setup({
                mappings = cmp.mapping.preset.insert({
                    ["<C-p>"] = cmp.mapping.select_prev_item(),
                    ["<C-n>"] = cmp.mapping.select_next_item(),
                    ["<C-y>"] = cmp.mapping.confirm({ select = true }),
                    ["<C-Space>"] = cmp.mapping.complete(),
                }),
				sources = {
					{ name = 'nvim_lsp' },
					{ name = 'buffer' },
					{ name = 'path' },
				},
			})

			lsp.on_attach(function(client, bufnr)
				local opts = { buffer = bufnr, remap = false }

				vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
				vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
				vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
				vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
				vim.keymap.set("n", "[d", function() vim.diagnostic.goto_next() end, opts)
				vim.keymap.set("n", "]d", function() vim.diagnostic.goto_prev() end, opts)
				vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
				vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
				vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
				vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
			end)

			lsp.setup()
		end
	},
}

