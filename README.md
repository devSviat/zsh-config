# zsh-config

**zsh** setup with [Oh My Zsh](https://ohmyz.sh/), [Oh My Posh](https://ohmyposh.dev/), and the [`themes/devSviat.omp.json`](themes/devSviat.omp.json) theme. Repo: [devSviat/zsh-config](https://github.com/devSviat/zsh-config).

Contents:

| File | Purpose |
| --- | --- |
| [`.zshrc`](.zshrc) | The shell config itself — symlinked to `~/.zshrc`. |
| [`themes/devSviat.omp.json`](themes/devSviat.omp.json) | Oh My Posh prompt theme. |
| [`omarchy.zsh`](omarchy.zsh) | **Optional, [Omarchy](https://omarchy.org) only** — restores Omarchy's bash-only shell setup under zsh. See [below](#omarchyzsh--the-omarchy-bridge). |

## Quick start

You need **zsh**, [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh), [Oh My Posh](https://ohmyposh.dev/docs/installation), and the `zsh-syntax-highlighting` plugin (see below).

```bash
git clone https://github.com/devSviat/zsh-config.git ~/.config/zsh-config
ln -sf ~/.config/zsh-config/.zshrc ~/.zshrc
exec zsh
```

On Omarchy, also link the bridge — without it, switching your login shell to zsh silently drops every Omarchy alias, function and tool integration:

```bash
ln -sf ~/.config/zsh-config/omarchy.zsh "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/omarchy.zsh"
```

If the clone is not under **`~/.config/zsh-config`** (or you use a different **`XDG_CONFIG_HOME`**), set **`ZSH_CONFIG_REPO`** in `~/.zshrc` before the Oh My Posh block, or change the default in [`.zshrc`](.zshrc).

Install the syntax-highlighting plugin if missing:

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
```

**Optional:** [exa](https://the.exa.website/) (the `l` alias), [nvm](https://github.com/nvm-sh/nvm) — comment out the related blocks in `.zshrc` if you do not use them.

---

## `omarchy.zsh` — the Omarchy bridge

### Why it is needed

[Omarchy](https://omarchy.org) ships its **entire interactive shell setup as bash**, in `/usr/share/omarchy/default/bash/`:

* **aliases** — `ls`→eza, `lt`, `cd`→zoxide, `ff`, `d`, `c`, `cx`, `cy`, `a`, `g`/`gcm`/`gcam`, `..`/`...`
* **functions** — `zd`, `n`, `open`, `sff`, `compress`, `ga`/`gd` (git worktrees), `tdl`/`tds`/`tsl` (tmux layouts), `hdl`/`hds`/`hsl` (herdr layouts), `rsw`/`lsw`/`dsw` (rsync watchers), `fip`/`dip`/`lip` (SSH forwards), `iso2sd`, `format-drive`, and an auto-reconnecting `ssh` wrapper
* **environment** — `EDITOR`, `BROWSER`, `BAT_THEME`, `MANROFFOPT`, `MANPAGER`
* **tool integration** — mise, zoxide, fzf key bindings, `try`
* **completion** — the `omarchy` dispatcher, including the `# omarchy:args=` value specs that ~175 commands declare
* **readline tuning** — case-insensitive completion, prefix history search on the arrow keys

`~/.bashrc` pulls all of that in via `source "$OMARCHY_PATH/default/bash/rc"`. **`.zshrc` in this repo does not**, and it cannot: the files use `shopt`, `complete`/`compgen`/`COMPREPLY`, `bind -f`, and bash-only array semantics.

So the moment you `chsh -s /usr/bin/zsh` on Omarchy, all of the above disappears with no warning. `omarchy.zsh` puts it back.

### Where it lives and how it loads

The file belongs in Oh My Zsh's custom directory, which Oh My Zsh sources automatically (it globs `$ZSH_CUSTOM/*.zsh` near the end of `oh-my-zsh.sh`):

```
~/.config/zsh-config/omarchy.zsh   ← the file in this repo
        ↓ symlink
~/.oh-my-zsh/custom/omarchy.zsh    ← sourced by oh-my-zsh.sh
```

That location matters. It runs **after** `.zshrc` has loaded Oh My Zsh and its plugins, so Omarchy's aliases and functions win over the ones the `git` plugin defines — the same precedence you get on bash. It also runs **before** the Oh My Posh block at the end of `.zshrc`, so the prompt still comes from this repo's theme.

Nothing in `.zshrc` references the bridge; linking the file is the only thing that switches it on.

### How it works

It does **not** copy Omarchy's config. It sources Omarchy's own files verbatim:

```zsh
emulate ksh -c "unsetopt aliases; source $file"
```

`emulate ksh -c` is *sticky*: functions defined inside it keep ksh semantics when they are called later. That is what makes upstream's bash idioms behave correctly — 0-indexed arrays (`${panes[0]}` in `tsl`), negative subscripts (`${columns[-1]}` in `hsl`), `printf -v` (`hdlm`), and globs that expand to nothing instead of raising zsh's `no matches found` (`hdlm`, `tdlm`).

Because the upstream files are read directly, **Omarchy system updates are picked up automatically** — there is nothing here to re-sync.

| Omarchy file | Handling |
| --- | --- |
| `envs`, `aliases`, `fns/*` | Sourced as shipped, under `emulate ksh` |
| `init` | Re-done for zsh — `mise activate zsh`, `zoxide init zsh`, `try`, fzf's `*.zsh` files |
| `shell` | Only `set +h` needs mirroring (`unsetopt hash_cmds`); Oh My Zsh already handles history |
| `inputrc` | Re-done as `zstyle`/`bindkey` (case-insensitive completion, arrow history search, Shift-Tab) |
| `completions` | Re-done as a zsh `compdef` completer, `# omarchy:args=` parsing included |

**starship is deliberately not started**, even though Omarchy's `init` starts it for bash: the prompt here is Oh My Posh, and running both would fight over `PROMPT`.

### Three zsh traps it works around

These are the reasons a naive `source` of Omarchy's bash files does not work. Do not "fix" them back:

1. **Aliases must be off while sourcing.** Oh My Zsh's `git` plugin defines `ga`, and zsh expands aliases while *parsing* — so the line `ga() {` in `fns/worktrees` is read as `git add() {`, a parse error that drops the rest of the file. Hence `unsetopt aliases` during sourcing; afterwards any alias shadowing a freshly defined Omarchy function is removed, because at the prompt an alias still beats a function.
2. **`${letters:i:1}` is not portable.** zsh reads `:i` as a history modifier and errors out; a variable offset must be written `${letters:$i:1}`.
3. **`argv` is `$@` in zsh.** `local argv=("$@")` does not create a normal array — the function's own `shift` loop empties it. Both this and (2) live in `_ssh_interactive`, which is therefore the one function re-written here; the rest of `fns/ssh-reconnect` is used as shipped.

### Cost

Sourcing Omarchy's files under emulation takes about the same as bash sourcing them directly (~1 ms). Interactive startup is dominated by Oh My Zsh's `compinit`, not by this file; measured on one machine, bash `49.6 ms` vs zsh `73.0 ms`.

### Disabling it

```bash
OMARCHY_ZSH_BRIDGE=0    # set before ~/.zshrc runs
```

On a machine without Omarchy the file is harmless: the Omarchy block is skipped when `/usr/share/omarchy/default/bash` is absent, and the remaining pieces (mise/zoxide/fzf init, completion styling, key bindings) are each guarded by a `command -v` check.
