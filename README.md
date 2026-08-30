# Omatabs

Sticky notes that live as tabs on the edge of the Omarchy desktop.

- `+` starts a new note.
- Tabs are title-sized along the edge. Hover expands the note into a card. If the card would run off the screen, the body scrolls. Click to edit.
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
