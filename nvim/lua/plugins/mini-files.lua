return {
  "echasnovski/mini.files",
  version = false,

  keys = {
    {
      "<leader>e",
      function()
        require("mini.files").open(vim.api.nvim_buf_get_name(0), true)
      end,
      desc = "Open mini.files (Directory of Current File)",
    },
  },

  config = function()
    local MiniFiles = require("mini.files")

    local git_status = {}
    local git_root = nil

    local function update_git_status()
      git_status = {}
      git_root = nil

      local current_file = vim.api.nvim_buf_get_name(0)

      if current_file == "" then
        current_file = vim.fn.getcwd()
      end

      if vim.fn.isdirectory(current_file) == 0 then
        current_file = vim.fs.dirname(current_file)
      end

      git_root = vim.fs.root(current_file, ".git")

      if not git_root then
        return
      end

      local output = vim.fn.systemlist({
        "git",
        "-C",
        git_root,
        "status",
        "--porcelain=v1",
      })

      if vim.v.shell_error ~= 0 then
        git_root = nil
        return
      end

      for _, line in ipairs(output) do
        if #line >= 4 then
          local status = line:sub(1, 2)
          local path = line:sub(4)

          local new_path = path:match(" -> (.+)$")

          if new_path then
            path = new_path
          end

          local absolute_path = vim.fs.joinpath(git_root, path)

          git_status[vim.fs.normalize(absolute_path)] = status
        end
      end
    end

    local function get_git_status(path)
      if not git_root then
        return nil
      end

      path = vim.fs.normalize(path)

      if git_status[path] then
        return git_status[path]
      end

      local prefix = path .. "/"

      for git_path, status in pairs(git_status) do
        if vim.startswith(git_path, prefix) then
          return status
        end
      end

      return nil
    end

    vim.api.nvim_set_hl(0, "MiniFilesGitModified", {
      link = "DiagnosticWarn",
    })

    vim.api.nvim_set_hl(0, "MiniFilesGitAdded", {
      link = "DiagnosticInfo",
    })

    vim.api.nvim_set_hl(0, "MiniFilesGitDeleted", {
      link = "DiagnosticError",
    })

    vim.api.nvim_set_hl(0, "MiniFilesGitUntracked", {
      link = "DiagnosticOk",
    })

    vim.api.nvim_set_hl(0, "MiniFilesGitRenamed", {
      link = "DiagnosticHint",
    })

    local function get_git_highlight(status)
      if status == "??" then
        return "MiniFilesGitUntracked"
      elseif status:find("A") then
        return "MiniFilesGitAdded"
      elseif status:find("M") then
        return "MiniFilesGitModified"
      elseif status:find("D") then
        return "MiniFilesGitDeleted"
      elseif status:find("R") then
        return "MiniFilesGitRenamed"
      end

      return nil
    end

    local function git_highlight(fs_entry)
      local default_hl = MiniFiles.default_highlight(fs_entry)
      local status = get_git_status(fs_entry.path)

      if not status then
        return default_hl
      end

      return get_git_highlight(status) or default_hl
    end

    MiniFiles.setup({
      content = {
        filter = nil,
        prefix = MiniFiles.default_prefix,
        highlight = git_highlight,
        sort = nil,
      },

      mappings = {
        close = "q",

        go_in_plus = "l",
        go_out_plus = "h",
        --go_in = "l",
        --go_out = "h",

        mark_goto = "m",
        mark_set = "M",

        reveal_cwd = "@",

        synchronize = "=",
        reset = "<BS>",

        show_help = "g?",
        trim_left = "H",
        trim_right = "L",
      },

      options = {
        permanent_delete = true,
        use_as_default_explorer = false,
      },

      windows = {
        max_number = math.huge,
        preview = true,
        width_focus = 50,
        width_nofocus = 15,
        width_preview = 25,
      },
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesExplorerOpen",
      callback = function()
        update_git_status()

        MiniFiles.refresh({
          content = {
            prefix = MiniFiles.default_prefix,
            highlight = git_highlight,
          },
        })
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = {
        "MiniFilesActionCreate",
        "MiniFilesActionDelete",
        "MiniFilesActionRename",
        "MiniFilesActionCopy",
        "MiniFilesActionMove",
      },
      callback = function()
        vim.defer_fn(function()
          update_git_status()

          MiniFiles.refresh({
            content = {
              prefix = MiniFiles.default_prefix,
              highlight = git_highlight,
            },
          })
        end, 100)
      end,
    })
  end,
}
