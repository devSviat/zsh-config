# zsh-config

**zsh** setup with [Oh My Zsh](https://ohmyz.sh/), [Oh My Posh](https://ohmyposh.dev/), and the [`themes/devSviat.omp.json`](themes/devSviat.omp.json) theme. Repo: [devSviat/zsh-config](https://github.com/devSviat/zsh-config).

## Quick start

You need **zsh**, [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh), [Oh My Posh](https://ohmyposh.dev/docs/installation), and the `zsh-syntax-highlighting` plugin (see below).

```bash
git clone https://github.com/devSviat/zsh-config.git ~/.config/zsh-config
ln -sf ~/.config/zsh-config/.zshrc ~/.zshrc
exec zsh
```

If the clone is not under **`~/.config/zsh-config`** (or you use a different **`XDG_CONFIG_HOME`**), set **`ZSH_CONFIG_REPO`** in `~/.zshrc` before the Oh My Posh block, or change the default in [`.zshrc`](.zshrc).

Install the syntax-highlighting plugin if missing:

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
  "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
```

**Optional:** [exa](https://the.exa.website/) (the `l` alias), [nvm](https://github.com/nvm-sh/nvm) — comment out the related blocks in `.zshrc` if you do not use them.
