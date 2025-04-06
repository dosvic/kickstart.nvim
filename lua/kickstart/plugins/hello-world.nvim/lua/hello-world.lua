local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('HelloWorld', function()
    vim.print 'Hello World!'
  end, {})
end

return M
