describe("Data Viewer per-player settings", function()
  it("should have default font size", function()
    local storage = { players = { [1] = { data_viewer_settings = { font_size = 12 } } } }
    assert.equals(storage.players[1].data_viewer_settings.font_size, 12)
  end)
end)
