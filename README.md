# RH!NOIFY

A Windows desktop customization manager for Spotify, using the Spicetify CLI.

## Version 0.3.0

- Electron desktop app with a black/red interface
- Spotify and Spicetify detection
- Backup, apply, restore, and CLI update actions
- Live theme catalog sourced from `spicetify/spicetify-themes`
- Search, installed/available filters, theme installation, and apply
- Theme ZIP extraction checks required files and blocks archive path traversal
- Extension manager: install a local `.js` file, view installed extensions, enable/disable, and apply
- Custom app manager: install a folder containing `index.js` and `manifest.json`, enable/disable, and apply
- Uses Spicetify CLI-reported extension/custom-app paths, with standard Windows fallback paths
- GitHub Actions workflow builds and publishes a Windows installer

## Requirements

- Windows 10/11
- Node.js 20+ for development
- Spotify desktop app
- Spicetify CLI installed and configured

## Run

```powershell
npm install
npm start
```

## Build

```powershell
npm run dist
```

Output: `dist/RHINOIFY-Setup.exe`.

## Publish installer

1. Create a public GitHub repository named `RHINOIFY`.
2. Upload this project.
3. Set your GitHub username in `install.ps1`.
4. Push the project and create a release tag:

```powershell
git tag v0.3.0
git push origin v0.2.0
```

GitHub Actions builds and attaches the Windows installer to the release.

After the release exists, users can run:

```powershell
iwr -useb https://raw.githubusercontent.com/YOUR_USERNAME/RHINOIFY/main/install.ps1 | iex
```

Replace `YOUR_USERNAME` with the actual repository owner.

## Notes

RH!NOIFY is a third-party front end around Spicetify CLI, not an independent Spotify patching engine. Community themes can break after Spotify updates. Review community theme, extension, and custom-app source code before installing. Extensions and custom apps execute code inside Spotify. RH!NOIFY copies local extension `.js` files and custom-app folders; it does not currently host a remote extension marketplace. This source package has not yet been built or tested on Windows.
