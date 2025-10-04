return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
  opts = {
    behaviour = {
      auto_suggestions = true,
      enable_cursor_planning_mode = true,
      auto_suggestions_respect_ignore = true,
      enable_claude_text_editor_tool_mode = false,
      use_cwd_as_project_root = true,
    },

    -- add any opts here
    -- for example
    -- provider = "openai",
    openai = {
      endpoint = "https://api.openai.com/v1",
      model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
      timeout = 30000, -- timeout in milliseconds
      temperature = 0, -- adjust if needed
      max_tokens = 4096,
      -- reasoning_effort = "high" -- only supported for reasoning models (o1, etc.)
    },

    provider = "openrouter_sonnet",
    auto_suggestions_provider = "openrouter_sonnet",

    vendors = {
      openrouter_gemini_25_pro = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = "google/gemini-2.5-pro-preview-03-25",
      },

      openrouter_open_ai_4o = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = "openai/gpt-4o",
      },
      openrouter_open_ai_4o_mini = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = "openai/gpt-4o-mini",
      },
      openrouter_sonnet = {
        __inherited_from = 'openai',
        endpoint = 'https://openrouter.ai/api/v1',
        api_key_name = 'OPENROUTER_API_KEY',
        model = "anthropic/claude-3.7-sonnet",
      },

      aimarketplace = {
        __inherited_from = 'openai',
        endpoint = os.getenv('AI_MARKETPLACE_URL'),
        api_key_name = 'AI_MARKETPLACE_API_KEY',
        model = 'openai_gpt4o_128k',
      },
      ai_marketplace_deepseek = {
        __inherited_from = 'openai',
        endpoint = os.getenv('AI_MARKETPLACE_URL'),
        api_key_name = 'AI_MARKETPLACE_API_KEY',
        model = 'deepseek_r1',
      },
      ai_marketplace_claude = {
        __inherited_from = 'openai',
        endpoint = os.getenv('AI_MARKETPLACE_URL'),
        api_key_name = 'AI_MARKETPLACE_API_KEY',
        model = 'anthropic_claude_3_opus_v1_0',
      },
    },

    -- provider = "ollama",
    ollama = {
      model = "deepseek-coder-v2",
      -- model = "deepseek-r1:32b",
    },

  },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  build = "make",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    "echasnovski/mini.pick", -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua", -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua", -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      'MeanderingProgrammer/render-markdown.nvim',
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },
}
