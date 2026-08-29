# Omatabs

Sticky notes that live as tabs on the edge of the Omarchy desktop.

- `+` starts a new note.
- Hover a tab to peek the rendered note. Click to edit the markdown.
- Enter saves. Shift+Enter starts a new line.
- Body text is markdown: `**bold**`, `*italic*`, `` `code` ``, lists, and links.

Notes are stored in `~/.local/state/omarchy/omatabs.json`.

## Install

```bash
omarchy plugin add https://github.com/tony-roslund/omatabs.git --enable
```

Or copy this folder to `~/.config/omarchy/plugins/tony.omatabs` and:

```bash
omarchy plugin enable tony.omatabs
omarchy restart shell
```

Switch edges:

```bash
omarchy-shell tony.omatabs edge left
omarchy-shell tony.omatabs edge right
```

New note from a keybind:

```lua
o.bind("SUPER + N", "New Omatabs note", [[omarchy-shell shell toggle tony.omatabs '{}']])
```

## Remove

```bash
omarchy plugin remove tony.omatabs
```

That disables the overlay and deletes the plugin checkout. Notes are left in `~/.local/state/omarchy/omatabs.json`; delete that file if you also want the saved tabs gone.

## License

MIT. No extra packages or privileged install steps.
