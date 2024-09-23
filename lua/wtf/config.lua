local search_engines = require("wtf.search_engines")

local M = {}

M.options = {}

function M.setup(opts)
  local default_opts = {
    additional_instructions = nil,
    chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/wtf/chats",
    context = true,
    language = "english",  -- Default language option
    provider = "openai",  -- New option for provider
    groq_api_key = nil,
    openai_api_key = nil,  -- New option for OpenAI API key
    anthropic_api_key = nil,  -- New option for Anthropic API key
    groq_model_id = "llama-3.1-70b-versatile",
    openai_model_id = "gpt-3.5-turbo",  -- Default model for OpenAI
    anthropic_model_id = "claude-v1",  -- Default model for Anthropic
    popup_type = "popup",
    search_engine = "google",
    hooks = {
      request_started = nil,
      request_finished = nil,
    },
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
  }

  -- Merge default_opts with opts
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  vim.validate({
    winhighlight = { opts.winhighlight, "string" },
    groq_api_key = { opts.groq_api_key, { "string", "nil" } },
    openai_api_key = { opts.openai_api_key, { "string", "nil" } },
    anthropic_api_key = { opts.anthropic_api_key, { "string", "nil" } },
    groq_model_id = { opts.groq_model_id, "string" },
    openai_model_id = { opts.openai_model_id, "string" },
    anthropic_model_id = { opts.anthropic_model_id, "string" },
    provider = { opts.provider, "string" },
    language = { opts.language, "string" },  -- Validate language option
    search_engine = {
      opts.search_engine,
      function(search_engine)
        local selected_engine = search_engines.sources[search_engine]

        if not selected_engine then
          return false
        else
          return true
        end
      end,
      "supported search engine",
    },
    context = { opts.context, "boolean" },
    additional_instructions = { opts.additional_instructions, { "string", "nil" } },
    popup_type = {
      opts.popup_type,
      function(popup_type)
        local popup_types = { "horizontal", "vertical", "popup" }

        for _, valid_type in ipairs(popup_types) do
          if popup_type == valid_type then
            return true
          end
        end
        return false
      end,
      "supported popup type",
    },
    request_started = {
      opts.hooks.request_started,
      { "function", "nil" },
    },
    request_finished = {
      opts.hooks.request_finished,
      { "function", "nil" },
    },
  })

  M.options = vim.tbl_extend("force", M.options, opts)
end

return M
