# Change Log

All notable changes to the "bnw" extension will be documented in this file.

Check [Keep a Changelog](http://keepachangelog.com/) for recommendations on how to structure this file.

## [0.0.1]

- Initial release

## [0.0.2]

- Use white smoke background
- Match button color whith foreground text color
- Apply theme to notifications
- Improve list highlighting

## [0.0.3]
- Improve indent highlight
- Use blue tone attributes in HTML
- White background on peekview

## [0.0.4]
- Improve gitlens blame visibility
- Properly view dart closing component comments

## [0.0.5]
- Improve github colpilot contrast
- Change colors to better fit name

## [0.0.8]
- Improve contrast and highlighting for Rust
- Remove duplicate token rules
- Add contrast to brackets

## [0.0.9]
- Rename extension to bnw-colors
- Fix display issue on github copilot tips

## [0.0.10]
- Highlight Terraform block types (resource, data, module, output...)
- Color Terraform heredocs and ${} interpolation
- Improve file tab display
- Make YAML anchors (&name), aliases (*name) and merge keys (<<) stand out
- Make INI and TOML section titles pop
- Keep INI/TOML section brackets themed by disabling bracket pair colorization there
- Make Dockerfile instructions (FROM, ARG, ENV, RUN...) pop in the storage-keyword blue

## [0.0.11]
- Fix sticky scroll lines turning black on hover

## [0.1.0]
- Raise text contrast so the theme reads on SDR screens, not just HDR ones: every
  foreground now clears WCAG AA (4.5:1) against its background
- Darken the faint end of the light editor palette (comments, punctuation, imports,
  constants, types, tags, strings) while keeping each colour's hue and saturation,
  so the grayscale look and the token hierarchy are unchanged
- Lighten the dark chrome text (sidebar, inactive tabs, descriptions, icons,
  notifications, errors); keep disabled text, unfocused-inactive tabs and
  gitignored files dim, but visible
- Fix GitLens blame text and Dart closing labels, which were near-invisible on the
  light editor background
- Re-space the bracket pair ramp so level 5 is readable and all six levels stay distinct
- Set editor line number, editor widget and keybinding label colours explicitly
  instead of inheriting dark-UI defaults onto light surfaces
- Soften the cursor to a weak green
- Move find matches to a weak blue-green on the existing #065a60 teal axis, so they
  read apart from the green selection by hue instead of competing with it on
  lightness; the current match carries a teal border and the overview ruler marks
  match the same teal
