# 🪨 gravel.nvim

**The coarse, non-shiny alternative to Obsidian.**

## What is this?

Obsidian is beautiful, sharp, volcanic glass. It is prized by geologists and productivity gurus alike.

**This is Gravel.**

It is small, loose, and arguably much less valuable. But if you pile enough of it together, you can build a driveway. `gravel.nvim` brings the "loose rocks" approach to note-taking in Neovim. It supports WikiLinks, daily notes, multiple piles, tags, and a physics-based graph view, but without the electron bloat or the shiny finish.

> "I don't need a monolith. I just need a pile of rocks." — *Happy User*

## ✨ Features

*   **Multiple Piles:** Manage independent collections of notes (Work, Personal, etc.) and switch between them instantly.
*   **Physics-Based Graph:** Visualizes your notes as nodes. Interactive! Jump with `h/j/k/l` and open with `<Enter>`.
*   **Tag Management:** Centralized `#tag` browser with usage counts. Avoids duplicates.
*   **Link Toss:** Follow `[[wikilinks]]` or open `[[http://...]]` URLs in your browser.
*   **Daily Pebbles:** Quickly open today's daily note.

## 📦 Installation

Use your favorite package manager. If you use `lazy.nvim`:

```lua
{
    "tDalile/gravel.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
    config = function()
        require("gravel").setup({
            -- Define your piles here
            piles = {
                { name = "Default", path = "~/gravel_pit" },
                { name = "Work", path = "~/work_notes" },
            },
            daily_format = "%Y-%m-%d",
        })
    end
}
```

## 🚀 Usage

### Navigation & Management
*   `:GravelPiles` - Switch between your defined piles (persisted across sessions).
*   `:GravelToday` - Open today's daily note.
*   `:GravelDig` - Search for a note (Telescope).
*   `:GravelToss` - Follow the link under cursor (`[[WikiLink]]` opens note, `[[http://...]]` opens browser).

### Tags (`#hashtags`)
*   `:GravelTags` - Browse all tags in the current pile, sorted by frequency. Selecting one opens a list of notes containing it.
*   `:GravelTagInsert` - Insert an existing tag at cursor position (autocompletion helper).

### Visual Graph
*   `:GravelPile` - Open the interactive graph view.
    *   `h/j/k/l`: Navigate between nodes.
    *   `<Enter>`: Open selected note.
    *   `q`: Close graph.

## 🗺️ Roadmap
* [ ] Add more rocks.
* [ ] Make the rocks smoother.
* [ ] I like my piles neat and tidy (Templats).
* [ ] Counting pebbles (Love stats).
* [ ] Some pebbles might need pictures?! (assets).
* [x] Eventually build a driveway (Graph View).

## 🤝 Contributing

Found a bug? It's probably just some dirt mixed in with the stones. Feel free to open a PR or an Issue.

---

*Made with ❤️ and Lua.*
