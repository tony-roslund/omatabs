# Development

Develop from this checkout, then copy into the live plugin directory.
Omarchy recursively watches `~/.config/omarchy/plugins/` and reloads the
shell for every save.

```bash
rsync -a --delete --exclude .git --exclude tests ./ ~/.config/omarchy/plugins/tony.omatabs/
omarchy restart shell
```
