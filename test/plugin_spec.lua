local assert = require("luassert")

describe("gravel.nvim", function()
  it("can be required", function()
    local gravel = require("gravel")
    assert.truthy(gravel)
  end)

  it("exposes configuration", function()
    local gravel = require("gravel")
    assert.truthy(gravel.config)
  end)
end)
