local config = require("wtf.config")

local M = {}

local callback_counter = 0

local status_index = 0
local progress_bar_dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function run_started_hook()
  local request_started = config.options.hooks and config.options.hooks.request_started
  if request_started ~= nil then
    request_started()
  end

  callback_counter = callback_counter + 1
end

local function run_finished_hook()
  callback_counter = callback_counter - 1
  if callback_counter <= 0 then
    local request_finished = config.options.hooks and config.options.hooks.request_finished
    if request_finished ~= nil then
      request_finished()
    end
  end
end

function M.get_status()
  if callback_counter > 0 then
    status_index = status_index + 1
    if status_index > #progress_bar_dots then
      status_index = 1
    end
    return progress_bar_dots[status_index]
  else
    return ""
  end
end

local function get_model_id()
  local provider = config.options.provider
  local model

  if provider == "groq" then
    model = config.options.groq_model_id
  elseif provider == "openai" then
    model = config.options.openai_model_id
  elseif provider == "anthropic" then
    model = config.options.anthropic_model_id
  else
    error("Invalid provider specified")
  end

  if model == nil then
    if vim.g.wtf_model_id_complained == nil then
      local message = "No model id specified. Please set the model id in the setup table. Defaulting to a provider-specific model for now."
      vim.fn.confirm(message, "&OK", 1, "Warning")
      vim.g.wtf_model_id_complained = 1
    end
    if provider == "groq" then
      return "llama-3.1-70b-versatile"
    elseif provider == "openai" then
      return "gpt-3.5-turbo"
    elseif provider == "anthropic" then
      return "claude-v1"
    end
  end

  return model
end

local function get_api_key()
  local provider = config.options.provider
  local api_key

  if provider == "groq" then
    api_key = config.options.groq_api_key or os.getenv("GROQ_API_KEY")
  elseif provider == "openai" then
    api_key = config.options.openai_api_key or os.getenv("OPENAI_API_KEY")
  elseif provider == "anthropic" then
    api_key = config.options.anthropic_api_key or os.getenv("ANTHROPIC_API_KEY")
  else
    error("Invalid provider specified")
  end

  if api_key == nil then
    if vim.g.wtf_api_key_complained == nil then
      local message = "No API key found for the selected provider. Please set the API key in the setup table or as an environment variable."
      vim.fn.confirm(message, "&OK", 1, "Warning")
      vim.g.wtf_api_key_complained = 1
    end
    return nil
  end

  return api_key
end

function M.request(messages, callback, callbackTable)
  local api_key = get_api_key()

  if api_key == nil then
    return nil
  end

  -- Check if curl is installed
  if vim.fn.executable("curl") == 0 then
    vim.fn.confirm("curl installation not found. Please install curl to use Wtf", "&OK", 1, "Warning")
    return nil
  end

  local curlRequest

  -- Create temp file
  local tempFilePath = vim.fn.tempname()
  local tempFile = io.open(tempFilePath, "w")
  if tempFile == nil then
    vim.notify("Error creating temp file", vim.log.levels.ERROR)
    return nil
  end

  -- Write dataJSON to temp file
  local dataJSON = vim.json.encode({
    model = get_model_id(),
    messages = messages,
  })
  tempFile:write(dataJSON)
  tempFile:close()

  -- Escape the name of the temp file for command line
  local tempFilePathEscaped = vim.fn.fnameescape(tempFilePath)

  -- Check if the user is on windows
  local isWindows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

  run_started_hook()

  local api_url
  if config.options.provider == "groq" then
    api_url = "https://api.groq.com/openai/v1/chat/completions"
  elseif config.options.provider == "openai" then
    api_url = "https://api.openai.com/v1/chat/completions"
  elseif config.options.provider == "anthropic" then
    api_url = "https://api.anthropic.com/v1/complete"
  else
    error("Invalid provider specified")
  end

  if isWindows ~= true then
    -- Linux
    curlRequest = string.format(
      'curl -s %s -H "Content-Type: application/json" -H "Authorization: Bearer %s" --data-binary "@%s"; rm %s > /dev/null 2>&1',
      api_url, api_key, tempFilePathEscaped, tempFilePathEscaped
    )
  else
    -- Windows
    curlRequest = string.format(
      'curl -s %s -H "Content-Type: application/json" -H "Authorization: Bearer %s" --data-binary "@%s" & del %s > nul 2>&1',
      api_url, api_key, tempFilePathEscaped, tempFilePathEscaped
    )
  end

  return vim.fn.jobstart(curlRequest, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      local response = table.concat(data, "\n")
      local success, responseTable = pcall(vim.json.decode, response)

      if success == false or responseTable == nil then
        if response == nil then
          response = "nil"
        end
        vim.notify("Bad or no response: ", vim.log.levels.ERROR)

        run_finished_hook()
        return nil
      end

      if responseTable.error ~= nil then
        vim.notify("API Error: " .. responseTable.error.message, vim.log.levels.ERROR)

        run_finished_hook()
        return nil
      end

      callback(responseTable, callbackTable)
      run_finished_hook()
    end,
    on_stderr = function(_, data, _)
      return data
    end,
    on_exit = function(_, data, _)
      return data
    end,
  })
end

return M
