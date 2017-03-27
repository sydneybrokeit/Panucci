# Panucci Arcana

## Keybinds

**Open Terminal**: Win + Enter

**Close Window**: Shift + Win + Q

**Move Focused Window**: Shift + Win + Arrow Key

## Commands

Run these commands in a terminal!

Most commands involving files in /home/partimag will require root.

**Switch to root (admin)**: `sudo su`

**Leave root user**: `exit`

**Run *command* as root**: `sudo command`

**Change Directory**: `cd directory`

**Copy files**: `cp source target`  This will copy the file or directory source to the target location.

**Move files**: `mv source target`  This is also useful to rename files.

**Delete files**: `rm file`

**Delete populated directory**: `rm -fr directory`

## Seymour

**Begin creating image (as root)**: `createbaseimage`

**Recreate image image tree (as root)**: `createimagetree`  This should almost never be needed.

**Verify drive geometry change**: `diff path/to/folder/sda-pt.sf path/to/folder2/sda-pt.sf`  This should return the difference between lines.
