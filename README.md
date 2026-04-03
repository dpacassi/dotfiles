# `~/.dotfiles`

My personal dotfiles managed with [chezmoi](https://chezmoi.io/).

This repository contains the source state for a small set of shell, Git and local helper-script customizations.
I edit the files in the chezmoi source directory, apply them back to my home folder for testing, and version everything with Git.

---

## Contents

- [About](#about)
  - [What is this repo?](#what-is-this-repo)
  - [Why chezmoi?](#why-chezmoi)
- [My setup](#my-setup)
  - [Managed files](#managed-files)
  - [Repo structure](#repo-structure)
- [Installation](#installation)
  - [Install chezmoi](#install-chezmoi)
  - [Apply these dotfiles](#apply-these-dotfiles)
  - [Update on an existing machine](#update-on-an-existing-machine)
- [Workflow](#workflow)
  - [My IDE workflow](#my-ide-workflow)
  - [Useful commands](#useful-commands)
- [Managing files the chezmoi way](#managing-files-the-chezmoi-way)
  - [Add a file](#add-a-file)
  - [Edit a managed file](#edit-a-managed-file)
  - [Apply changes](#apply-changes)
  - [Check what changed](#check-what-changed)
- [Git workflow](#git-workflow)

---

## About

### What is this repo?

This is my personal dotfiles repository.

It contains the source files for selected configuration and utility files that live in my home directory, such as my global Git ignore file and local helper scripts.

The files are managed with chezmoi instead of keeping a Git repository directly in `~`.

### Why chezmoi?

I use chezmoi so I can:

- keep my dotfiles versioned in Git
- apply them consistently to my home directory
- manage new machines more easily
- keep the source state separate from the rendered files in `~`

This also lets me use a normal Git working tree for my dotfiles while still testing the real files in my actual home folder.

---

## My setup

### Managed files

This repo uses `.chezmoiroot`, so the actual chezmoi source state lives in `home/`.

At the moment, the managed files are:

- `home/dot_gitignore_global`  
  My global Git ignore file, used via Git’s `core.excludesfile` setting.

- `home/bin/`  
  Personal helper scripts that are applied to `~/bin`.

Files such as `README.md` and `LICENSE` live in the repository root for documentation and GitHub display, but are not applied to my home directory.

### Repo structure

A simplified repo structure looks like this:

```text
.
├── .chezmoiroot
├── LICENSE
├── README.md
└── home/
    ├── bin/
    └── dot_gitignore_global
```

`.chezmoiroot` tells chezmoi to use `home/` as the source root.

---

## Installation

### Install chezmoi

Install chezmoi using the official installer:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### Apply these dotfiles

To initialize and apply this repository on a new machine:

```sh
chezmoi init --apply dpacassi
```

If you want to initialize from the full Git URL instead:

```sh
chezmoi init --apply git@github.com:dpacassi/dotfiles.git
```

### Update on an existing machine

To pull the latest changes from the remote repository and apply them:

```sh
chezmoi update
```

---

## Workflow

### My IDE workflow

I edit the files directly in the chezmoi source directory, not in `~`.

So in my IDE, I open the chezmoi repository as the project root:

```sh
chezmoi cd
pwd
```

Inside that repo, the actual managed files live under `home/` because of `.chezmoiroot`.

That gives me a normal Git working tree inside the IDE, which means I can use:

- changed-files view
- Git diff
- Git status
- normal commits

After editing files in my IDE, I apply them back to my actual home directory for testing.

### Useful commands

Check what would change in `~` before applying:

```sh
chezmoi status
chezmoi diff
```

Apply the current source state to the real files in my home directory:

```sh
chezmoi apply
```

Verbose dry-run before applying:

```sh
chezmoi -n -v apply
```

Open the source directory:

```sh
chezmoi cd
```

---

## Managing files the chezmoi way

This is the more native chezmoi workflow, where chezmoi maps between files in `~` and their corresponding source files in this repo.

### Add a file

Add an existing file or directory from the home directory into chezmoi:

```sh
chezmoi add ~/.gitignore_global
chezmoi add ~/bin
```

Because this repo uses `.chezmoiroot`, chezmoi will place the resulting source files under `home/`.

### Edit a managed file

Edit a managed file through chezmoi:

```sh
chezmoi edit ~/.gitignore_global
```

This opens the source file corresponding to `~/.gitignore_global` inside `home/`.

Edit and immediately apply afterwards:

```sh
chezmoi edit --apply ~/.gitignore_global
```

### Apply changes

Apply the source state back to the home directory:

```sh
chezmoi apply
```

### Check what changed

Show a summary of what would change if you ran `chezmoi apply`:

```sh
chezmoi status
```

Show the actual diff of what would be written to the home directory:

```sh
chezmoi diff
```

---

## Git workflow

Once I have tested my changes locally, I commit and push them from inside the chezmoi source repo:

```sh
chezmoi cd
git status
git diff
git add .
git commit -m "..."
git push
```

Because I edit the files in the chezmoi source directory, I get a standard Git workflow in my IDE and in the terminal.

---

<p align="center">
  <i>Maintained by <a href="https://github.com/dpacassi">David Pacassi Torrico</a>.</i><br />
  <i>Personal dotfiles managed with <a href="https://chezmoi.io/">chezmoi</a>.</i><br />
  <sup>There's no place like ~.</sup>
</p>

<!-- Easter egg -->
<!--
                /~~~~~~~~~~~~~~~~~~~~\
               /   There's no place   \
              /         like ~         \
             /__________________________\
             |                          |
             |  []  []  []  []  [] []   |
             |                          |
             |      ~/.dotfiles         |
             |         [____]           |
             |         |   o|           |
             |_________|____|___________|

   dpacassi@localhost:~ $ chezmoi apply
-->
