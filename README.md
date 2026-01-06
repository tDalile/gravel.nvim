# 🪨 gravel.nvim

**The coarse, non-shiny alternative to Obsidian.**

## What is this?

Obsidian is beautiful, sharp, volcanic glass. It is prized by geologists and productivity gurus alike.

**This is Gravel.**

It is small, loose, and arguably much less valuable. But if you pile enough of it together, you can build a driveway. `gravel.nvim` brings the "loose rocks" approach to note-taking in Neovim. It supports WikiLinks, daily notes, and standard Zettelkasten features, but without the electron bloat or the shiny finish.

> "I don't need a monolith. I just need a pile of rocks." — *Happy User*

## ✨ Features (The Piles)

* **Loose Coupling:** Just like gravel, your notes sit next to each other without being glued down.
* **Rough Edges:** No GUI, no fancy graphs (yet), just raw text manipulation.
* **Daily Pebbles:** A command to quickly open today's daily note.
* **Link Toss:** Quickly follow `[[wikilinks]]` to jump between stones.

## 📦 Installation

Use your favorite package manager. If you use `lazy.nvim`:

```lua
{
    "tDalile/gravel.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        require("gravel").setup({
            path = "~/gravel_pit", -- Where you keep your rocks
            daily_format = "%Y-%m-%d",
        })
    end
}

```

## 🚀 Usage

* `:GravelToss` - Create or follow a link under the cursor.
* `:GravelDig` - Search for a note (uses Telescope if available, otherwise it just guesses).
* `:GravelToday` - Open today's daily note.

## 🗺️ Roadmap

* [ ] Add more rocks.
* [ ] Make the rocks smoother.
* [ ] Eventually build a driveway (Graph View).

## 🤝 Contributing

Found a bug? It's probably just some dirt mixed in with the stones. Feel free to open a PR or an Issue.

---

*Made with ❤️ and Lua.*
