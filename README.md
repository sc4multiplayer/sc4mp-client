# SC4MP Client
A launcher for the PC videogame [SimCity 4](https://en.wikipedia.org/wiki/SimCity_4) that facilitates multiplayer gameplay. Uses [python 3.8.10](https://www.python.org/downloads/release/python-3810/), [pyinstaller](https://pyinstaller.org/) and [Inno Setup](https://jrsoftware.org/isinfo.php) script. Built to work with the [SC4MP Server](https://github.com/sc4multiplayer/sc4mp-server).

# Installation
Download and run the installer from the [latest release](https://github.com/sc4multiplayer/sc4mp-client/releases/latest).

## Linux
The launcher runs natively with Python; only SimCity 4 itself runs through Wine.

1. Install Python 3 with Tk (e.g. `python-tk`/`tk` from your package manager) and Pillow (`pip install pillow`, optional, for loading backgrounds).
2. Install SimCity 4 into a Wine prefix (GOG, or Steam via Proton/Wine).
3. Download the source ZIP, extract it, open a terminal in the extracted folder and run `python sc4mpclient.py`.
4. Configure the wrapper: copy `linux/simcity4-wine.conf.example` to `~/.config/sc4mp/simcity4-wine.conf` and set `SC4_EXE` (and `WINEPREFIX` if it isn't `~/.wine`). Set `USE_GAMESCOPE=1` to run the game inside gamescope. For the Steam copy of SC4, set `LAUNCH_MODE=steam` instead (plain Wine fails with Steam's "Application load error 5:0000065434"); Steam must be running, and gamescope goes in the game's Steam launch options.
5. In the launcher, open *Launcher > Settings > SC4...* and set *Custom installation path* to the full path of `linux/simcity4-wine.sh`.

The wrapper converts the launcher's `-UserDir:` path to a Windows path with `winepath` and starts the game with `wine`.

Since v0.9 the launcher loads the SC4MP DLL (`sc4mp.dll`) into the game for the in-game chat and save status. The DLL connects to the launcher on the port in the `SC4MP_BRIDGE_PORT` environment variable, which the wrapper passes on to Wine. With `LAUNCH_MODE=steam` Steam starts the game itself, so the variable can't reach it; the launcher then uses its legacy game monitor (the status window) automatically.

# Usage
Follow the instructions included in the `Readme.html` file.

# Compiling
To compile the source code, run the `setup.py` script. Then run the `setup.iss` script in the [Inno Setup Compiler](https://jrsoftware.org/isdl.php) to build the installer.
