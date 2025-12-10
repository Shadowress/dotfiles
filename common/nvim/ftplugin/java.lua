local jdtls = require("jdtls")

local jdtls_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"

local os_name
if vim.fn.has("macunix") == 1 then
    os_name = "config_mac"
elseif vim.fn.has("win32") == 1 then
    os_name = "config_win"
else
    os_name = "config_linux"
end

local launcher_jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
local config_dir = jdtls_path .. "/" .. os_name
local workspace_dir = vim.fn.expand("~/.cache/jdtls-workspace/") .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")

local config = {
    cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=INFO",
        "-Xms1g",
        "--add-modules=ALL-SYSTEM",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",

        "-jar", launcher_jar,
        "-configuration", config_dir,
        "-data", workspace_dir,
    },

    root_dir = require("jdtls.setup").find_root({
        ".git", "mvnw", "gradlew", "pom.xml", "build.gradle"
    }),

    settings = {
        java = {
            signatureHelp = { enabled = true },
            completion = { favoriteStaticMembers = { "java.*" } },
            -- You can add more jdtls-specific settings here
        }
    },

    -- Capabilities for completion, if using nvim-cmp
    capabilities = require("cmp_nvim_lsp").default_capabilities(),
}

jdtls.start_or_attach(config)

