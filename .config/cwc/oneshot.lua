-- script which better run once on startup

local cwc = cwc

-- autostart app
-- cwc.spawn_with_shell('dunst -conf "$HOME/.config/dunstrc" --startup_notification')
cwc.spawn_with_shell('swaync')
cwc.spawn_with_shell('lxqt-policykit-agent')
cwc.spawn_with_shell("swaybg --output '*' --color '#222222'")
cwc.spawn_with_shell("waybar")
-- cwc.spawn_with_shell("waybar")
-- cwc.spawn_with_shell("playerctld daemon")




local idle_cmd = "cwctl screen --filter '*' set dpms false"
local resume_cmd = "cwctl screen --filter='*' set dpms true"
local swayidle_cmd = string.format('swayidle -w timeout 3600 "%s" resume "%s"', idle_cmd, resume_cmd)
cwc.spawn_with_shell(swayidle_cmd)

-- for app that use tray better to wait for the bar to load
cwc.timer.new(2, function()
	cwc.spawn_with_shell('udisksctl mount -b /dev/nvme0n1p2')
	cwc.spawn_with_shell('xsettingsd')
	cwc.spawn_with_shell('xfsettingsd')
	cwc.spawn_with_shell('/usr/lib/xdg-desktop-portal-wlr')
	cwc.spawn { "aria2tray", "--hide-window" }

end, { one_shot = true })

-- env var
cwc.setenv("HYPRCURSOR_THEME", "Bibata-Modern-Classic")

-- xdg-desktop-portal-wlr
cwc.spawn_with_shell(
	"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

-- load builtin cwc C plugin
local plugins_folder = cwc.is_nested() and "./build/plugins" or cwc.get_datadir() .. "/plugins"
cwc.plugin.load(plugins_folder .. "/cwcle.so")
cwc.plugin.load(plugins_folder .. "/flayout.so")
cwc.plugin.load(plugins_folder .. "/dwl-ipc.so")
