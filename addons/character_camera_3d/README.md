# CharacterCamera3D Node for Godot 4.x

## Description
Third Person Character Camera for free orbit around a CharacterBody3D. It handles the following and keeps the character in screen. \
**IMPORTANT**: You need to have input mappings for manual camera control in Project Settings \
look_left, look_right, look_up, look_down \
https://docs.godotengine.org/en/stable/tutorials/inputs/input_examples.html


## Following over slopes
![gif1](images/y-following.gif "Y Following")
## Snapping to new plattforms
![gif2](images/plattform_snap.gif "Platform Snap")
## Normal collision behavior with a SpringArm3D
![gif2](images/collision_check.gif "SpringarmCollision")

## Setup
1. Download the addon via the AssetLib or just download and paste the addon folder into your project
2. Enable the Plugin in your Project Settings

## Usage
Just add the CharacterCamera3D Node as a child node of your Character and drag its Y-Posititon above the characters head. (Or where you want your camera focus to be)

> :warning: **The character must be of type CharacterBody3D.**
