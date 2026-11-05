require 'cairo'

-- System rings configuration table
-- Scaled for 1080p display (matching reference photo proportions)
-- 4 Vertically Aligned Rings:
-- Ring 1: Orange (CPU)
-- Ring 2: Coral/Pink (RAM)
-- Ring 3: Cyan (BAT)
-- Ring 4: Yellow (DSK)
local function get_battery_arg()
    local f0 = io.open("/sys/class/power_supply/BAT0/status", "r")
    if f0 then f0:close() return "BAT0" end
    local f1 = io.open("/sys/class/power_supply/BAT1/status", "r")
    if f1 then f1:close() return "BAT1" end
    return ""
end

local bat_arg = get_battery_arg()

system_rings = {
    {
        name = 'cpu', arg = 'cpu0', max = 100,
        x = 95, y = 95, radius = 45, thickness = 10,
        start_angle = 0, end_angle = 360,
        bg_color = 0xFFFFFF, bg_alpha = 0.15,
        fg_color = 0xFF9E3B, fg_alpha = 1.0,
        label = "CPU"
    },
    {
        name = 'memperc', arg = '', max = 100,
        x = 95, y = 265, radius = 45, thickness = 10,
        start_angle = 0, end_angle = 360,
        bg_color = 0xFFFFFF, bg_alpha = 0.15,
        fg_color = 0xF06292, fg_alpha = 1.0,
        label = "RAM"
    },
    {
        name = 'battery_percent', arg = bat_arg, max = 100,
        x = 95, y = 440, radius = 45, thickness = 10,
        start_angle = 0, end_angle = 360,
        bg_color = 0xFFFFFF, bg_alpha = 0.15,
        fg_color = 0x29B6F6, fg_alpha = 1.0,
        label = "BAT"
    },
    {
        name = 'fs_used_perc', arg = '/', max = 100,
        x = 95, y = 615, radius = 45, thickness = 10,
        start_angle = 0, end_angle = 360,
        bg_color = 0xFFFFFF, bg_alpha = 0.15,
        fg_color = 0xFFD54F, fg_alpha = 1.0,
        label = "DSK"
    }
}

-- Network History Buffers for Live Cairo Graph
local MAX_NET_SAMPLES = 42
local net_history_down = {}
local net_history_up = {}

for i = 1, MAX_NET_SAMPLES do
    net_history_down[i] = 0
    net_history_up[i] = 0
end

-- Helper to safely evaluate conky variables and strip ALL newlines/trailing spaces
function conky_val(expr)
    local s = conky_parse(expr)
    if s == nil then return "" end
    local res = string.gsub(s, "^%s*(.-)%s*$", "%1")
    return res
end

function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255.,
           ((colour / 0x100) % 0x100) / 255.,
           (colour % 0x100) / 255.,
           alpha
end

function draw_rounded_rect(cr, x, y, w, h, r)
    cairo_new_sub_path(cr)
    cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)
    cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)
    cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)
    cairo_arc(cr, x + r, y + r, r, math.pi, 3*math.pi/2)
    cairo_close_path(cr)
end

function truncate_str(str, max_len)
    if not str then return "" end
    if #str > max_len then
        return string.sub(str, 1, max_len - 3) .. "..."
    end
    return str
end

function draw_system_ring(cr, ring, value)
    local angle_0 = (ring.start_angle or 0) * math.pi/180 - math.pi/2
    local angle_f = (ring.end_angle or 360) * math.pi/180 - math.pi/2
    local angle_v = angle_0 + (angle_f - angle_0) * (value / ring.max)

    cairo_set_line_width(cr, ring.thickness)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)

    -- Background track ring
    cairo_arc(cr, ring.x, ring.y, ring.radius, angle_0, angle_f)
    cairo_set_source_rgba(cr, rgb_to_r_g_b(ring.bg_color, ring.bg_alpha))
    cairo_stroke(cr)

    -- Active progress arc
    if value > 0 then
        cairo_arc(cr, ring.x, ring.y, ring.radius, angle_0, angle_v)
        cairo_set_source_rgba(cr, rgb_to_r_g_b(ring.fg_color, ring.fg_alpha))
        cairo_stroke(cr)
    end

    -- Ring center label with exact mathematical centering
    if ring.label and ring.label ~= "" then
        cairo_select_font_face(cr, "Rubik", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 15)
        local ext = cairo_text_extents_t:create()
        cairo_text_extents(cr, ring.label, ext)
        cairo_set_source_rgba(cr, rgb_to_r_g_b(ring.fg_color, 0.95))
        cairo_move_to(cr, ring.x - (ext.width / 2 + ext.x_bearing), ring.y - (ext.height / 2 + ext.y_bearing))
        cairo_show_text(cr, ring.label)
        cairo_stroke(cr)
    end
end

function draw_text(cr, text, x, y, font_face, font_size, col_hex, alpha, is_bold)
    local r, g, b = rgb_to_r_g_b(col_hex, alpha or 1.0)
    local weight = is_bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL
    cairo_select_font_face(cr, font_face, CAIRO_FONT_SLANT_NORMAL, weight)
    cairo_set_font_size(cr, font_size)
    cairo_set_source_rgba(cr, r, g, b, alpha or 1.0)
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
    cairo_stroke(cr)
end

function draw_network_graph(cr, gx, gy, gw, gh)
    -- Background track
    cairo_rectangle(cr, gx, gy, gw, gh)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.04)
    cairo_fill(cr)

    -- Center guideline
    cairo_set_line_width(cr, 0.8)
    cairo_move_to(cr, gx, gy + gh/2)
    cairo_line_to(cr, gx + gw, gy + gh/2)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.1)
    cairo_stroke(cr)

    -- Graph subtle border
    cairo_rectangle(cr, gx, gy, gw, gh)
    cairo_set_source_rgba(cr, 0.16, 0.71, 0.96, 0.28)
    cairo_set_line_width(cr, 1)
    cairo_stroke(cr)

    -- Calculate scale max
    local max_val = 50.0
    for _, v in ipairs(net_history_down) do if v > max_val then max_val = v end end
    for _, v in ipairs(net_history_up) do if v > max_val then max_val = v end end

    local step = gw / (MAX_NET_SAMPLES - 1)

    -- Download filled area (Cyan #29B6F6)
    cairo_move_to(cr, gx, gy + gh)
    for i, v in ipairs(net_history_down) do
        local px = gx + (i - 1) * step
        local h_frac = math.min(v / max_val, 1.0)
        local py = gy + gh - (h_frac * (gh - 4)) - 1
        cairo_line_to(cr, px, py)
    end
    cairo_line_to(cr, gx + gw, gy + gh)
    cairo_close_path(cr)
    cairo_set_source_rgba(cr, 0.16, 0.71, 0.96, 0.20)
    cairo_fill(cr)

    -- Download line stroke
    for i, v in ipairs(net_history_down) do
        local px = gx + (i - 1) * step
        local h_frac = math.min(v / max_val, 1.0)
        local py = gy + gh - (h_frac * (gh - 4)) - 1
        if i == 1 then cairo_move_to(cr, px, py) else cairo_line_to(cr, px, py) end
    end
    cairo_set_line_width(cr, 1.5)
    cairo_set_source_rgba(cr, 0.16, 0.71, 0.96, 0.90)
    cairo_stroke(cr)

    -- Upload line stroke (Orange #FF9E3B)
    for i, v in ipairs(net_history_up) do
        local px = gx + (i - 1) * step
        local h_frac = math.min(v / max_val, 1.0)
        local py = gy + gh - (h_frac * (gh - 4)) - 1
        if i == 1 then cairo_move_to(cr, px, py) else cairo_line_to(cr, px, py) end
    end
    cairo_set_line_width(cr, 1.2)
    cairo_set_source_rgba(cr, 1.0, 0.62, 0.23, 0.85)
    cairo_stroke(cr)
end

function draw_spotify_logo(cr, x, y, size, is_active)
    local r = size / 2
    local cx = x + r
    local cy = y + r
    cairo_arc(cr, cx, cy, r, 0, 2*math.pi)
    if is_active then
        cairo_set_source_rgba(cr, 0.11, 0.73, 0.33, 1.0)
    else
        cairo_set_source_rgba(cr, 0.25, 0.26, 0.30, 0.9)
    end
    cairo_fill(cr)

    cairo_set_source_rgba(cr, 0.08, 0.09, 0.12, 0.95)
    cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
    local function draw_wave(radius, y_off, width, span)
        cairo_set_line_width(cr, width)
        local start_a = (180 + (90 - span)) * math.pi / 180
        local end_a = (360 - (90 - span)) * math.pi / 180
        cairo_arc(cr, cx, cy + y_off, radius, start_a, end_a)
        cairo_stroke(cr)
    end
    draw_wave(r * 0.72, r * 0.40, r * 0.14, 42)
    draw_wave(r * 0.54, r * 0.30, r * 0.13, 38)
    draw_wave(r * 0.36, r * 0.20, r * 0.12, 34)
end

function draw_spotify_player(cr, px, py, pw, ph)
    local ok, spot = pcall(dofile, "/tmp/spotify_state.lua")
    if not ok or not spot then
        spot = {
            running = false,
            status = "Offline",
            title = "No Track Playing",
            artist = "Spotify is offline",
            album = "",
            pos_str = "--:--",
            len_str = "--:--",
            progress = 0.0,
            has_cover = false
        }
    end

    -- 1. Card Container (Frosted glass)
    draw_rounded_rect(cr, px, py, pw, ph, 14)
    cairo_set_source_rgba(cr, 0.07, 0.08, 0.11, 0.75)
    cairo_fill_preserve(cr)

    -- Dynamic outline: Blue when playing, Gray when not playing
    local is_playing = (spot.status == "Playing")
    local b_col, b_alpha, b_width
    if is_playing then
        b_col = 0x29B6F6   -- Vibrant Cyan / Electric Blue
        b_alpha = 0.55
        b_width = 1.4
    else
        b_col = 0x666666   -- Clean subtle Gray
        b_alpha = 0.28
        b_width = 1.0
    end

    local br, bg, bb = rgb_to_r_g_b(b_col, b_alpha)
    cairo_set_source_rgba(cr, br, bg, bb, b_alpha)
    cairo_set_line_width(cr, b_width)
    cairo_stroke(cr)

    -- 2. Album Art / Spotify Logo
    local cx, cy = px + 14, py + 16
    local painted_cover = false
    if spot.has_cover then
        local img = cairo_image_surface_create_from_png("/tmp/spotify_cover.png")
        if img and cairo_surface_status(img) == 0 then
            cairo_set_source_surface(cr, img, cx, cy)
            cairo_paint(cr)
            cairo_surface_destroy(img)
            painted_cover = true
        end
    end
    if not painted_cover then
        draw_spotify_logo(cr, cx, cy, 72, spot.running)
    end

    -- 3. Header badge
    local hx = cx + 86
    local badge_col = is_playing and 0x29B6F6 or 0x8E8E93
    local dot_r, dot_g, dot_b = rgb_to_r_g_b(badge_col, 1.0)
    cairo_arc(cr, hx + 4, py + 25, 3.5, 0, 2*math.pi)
    cairo_set_source_rgba(cr, dot_r, dot_g, dot_b, 1.0)
    cairo_fill(cr)

    local badge_text = "SPOTIFY • " .. (is_playing and "NOW PLAYING" or string.upper(spot.status))
    draw_text(cr, badge_text, hx + 14, py + 29, "Rubik", 10.5, badge_col, 1.0, true)

    -- 4. Track Title
    local disp_title = truncate_str(spot.title, 28)
    draw_text(cr, disp_title, hx, py + 50, "Rubik", 15.5, 0xFFFFFF, 1.0, true)

    -- 5. Artist & Album
    local meta = spot.artist
    if spot.album and spot.album ~= "" then
        meta = meta .. " • " .. spot.album
    end
    local disp_meta = truncate_str(meta, 34)
    draw_text(cr, disp_meta, hx, py + 69, "Rubik", 12, 0x9E9E9E, 0.9, false)

    -- 6. Progress Bar
    local bx, by, bw, bh = hx, py + 81, 265, 4
    draw_rounded_rect(cr, bx, by, bw, bh, 2)
    cairo_set_source_rgba(cr, 1, 1, 1, 0.15)
    cairo_fill(cr)

    local p_val = spot.progress or 0.0
    if p_val > 0 then
        local fill_w = math.max(bw * p_val, 4)
        draw_rounded_rect(cr, bx, by, fill_w, bh, 2)
        local fill_col = is_playing and 0x29B6F6 or 0x777777
        local fr, fg, fb = rgb_to_r_g_b(fill_col, 0.95)
        cairo_set_source_rgba(cr, fr, fg, fb, 0.95)
        cairo_fill(cr)

        cairo_arc(cr, bx + fill_w, by + bh/2, 3.5, 0, 2*math.pi)
        cairo_set_source_rgba(cr, 1, 1, 1, 1.0)
        cairo_fill(cr)
    end

    -- 7. Time Stamps
    local time_str = spot.pos_str .. " / " .. spot.len_str
    draw_text(cr, time_str, bx + bw + 12, by + 5, "Rubik", 10.5, 0x8E8E93, 0.85, false)
end

function conky_system_rings()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- 1. Draw the 4 arc rings
    for _, ring in ipairs(system_rings) do
        local str_val = conky_val('${' .. ring.name .. ' ' .. ring.arg .. '}')
        local val = tonumber(str_val) or 0
        draw_system_ring(cr, ring, val)
    end

    -- 2. Digital Clock in Dot Matrix font (Orange #FF9E3B)
    local clock_time = conky_val('${time %H:%M}')
    draw_text(cr, clock_time, 190, 118, "Dot Matrix", 80, 0xFF9E3B, 1.0, true)

    -- 3. Vertical Day of the Week in Dot Matrix font (Cyan #29B6F6)
    local day_str = conky_val('${time %^a}')
    local d1 = string.sub(day_str, 1, 1)
    local d2 = string.sub(day_str, 2, 2)
    local d3 = string.sub(day_str, 3, 3)

    draw_text(cr, d1, 360, 230, "Dot Matrix", 42, 0x29B6F6, 1.0, true)
    draw_text(cr, d2, 360, 276, "Dot Matrix", 42, 0x29B6F6, 1.0, true)
    draw_text(cr, d3, 360, 322, "Dot Matrix", 42, 0x29B6F6, 1.0, true)

    -- 4. Weather Telemetry (Aligned with Ring 2)
    local w_temp = conky_val('${execi 120 ~/.config/conky/Astronaut/scripts/weather.sh -t}') .. "°C"
    local w_main = conky_val('${execi 120 ~/.config/conky/Astronaut/scripts/weather.sh -m}')
    local w_hum = "HUM: " .. conky_val('${execi 120 ~/.config/conky/Astronaut/scripts/weather.sh -h}') .. "%"
    local w_wind = "WIND: " .. conky_val('${execi 120 ~/.config/conky/Astronaut/scripts/weather.sh -ws}') .. " m/s"

    draw_text(cr, w_temp, 190, 228, "Dot Matrix", 36, 0xFF9E3B, 1.0, true)
    draw_text(cr, string.upper(w_main), 190, 258, "Rubik", 16, 0x29B6F6, 1.0, true)
    draw_text(cr, w_hum, 190, 284, "Rubik", 13, 0x8E8E93, 0.9, false)
    draw_text(cr, w_wind, 190, 306, "Rubik", 13, 0x8E8E93, 0.9, false)

    -- 5. Network Details & Live Graph (Aligned with Ring 3 / Battery)
    local function get_active_net_interface()
        local f = io.open("/proc/net/route", "r")
        if f then
            for line in f:lines() do
                local ifc, dest = line:match("^(%S+)%s+(%S+)")
                if ifc and dest == "00000000" then
                    f:close()
                    return ifc
                end
            end
            f:close()
        end
        return "wlp0s20f3"
    end

    local iface = get_active_net_interface()
    local essid = conky_val('${wireless_essid ' .. iface .. '}')
    local qual = conky_val('${wireless_link_qual_perc ' .. iface .. '}')
    local down = conky_val('${downspeed ' .. iface .. '}')
    local up = conky_val('${upspeed ' .. iface .. '}')
    local ip = conky_val('${addr ' .. iface .. '}')

    -- Numeric values for live graph
    local down_f = tonumber(conky_val('${downspeedf ' .. iface .. '}')) or 0
    local up_f = tonumber(conky_val('${upspeedf ' .. iface .. '}')) or 0

    table.insert(net_history_down, down_f)
    if #net_history_down > MAX_NET_SAMPLES then table.remove(net_history_down, 1) end
    table.insert(net_history_up, up_f)
    if #net_history_up > MAX_NET_SAMPLES then table.remove(net_history_up, 1) end

    -- Line 1: Network Title (SSID + Quality)
    local net_title = "WiFi: " .. (essid ~= "" and essid or "Connected")
    if qual ~= "" and qual ~= "unk" then
        net_title = net_title .. " (" .. qual .. "%)"
    end
    draw_text(cr, net_title, 190, 396, "Rubik", 14.5, 0xFF9E3B, 1.0, true)

    -- Line 2: Speeds with distinct colors
    local dl_text = "DL: " .. (down ~= "" and down or "0 B")
    local ul_text = "UL: " .. (up ~= "" and up or "0 B")
    draw_text(cr, dl_text, 190, 418, "Rubik", 12.5, 0x29B6F6, 1.0, true)
    draw_text(cr, ul_text, 310, 418, "Rubik", 12.5, 0xFF9E3B, 1.0, true)

    -- Line 3: Live Bandwidth Graph
    draw_network_graph(cr, 190, 428, 230, 34)

    -- Line 4: IP Address
    local ip_text = "IP: " .. (ip ~= "" and ip or "Disconnected")
    draw_text(cr, ip_text, 190, 480, "Rubik", 12, 0x8E8E93, 0.9, false)

    -- 6. System Uptime & Host (Aligned with Ring 4 / Disk)
    local uptime_str = conky_val('${uptime}')
    local nodename_str = conky_val('${nodename}')
    local kernel_str = conky_val('${kernel}')

    draw_text(cr, "UPTIME: " .. uptime_str, 190, 600, "Rubik", 14, 0xFFD54F, 1.0, true)
    draw_text(cr, "HOST: " .. nodename_str .. "   •   KERNEL: " .. kernel_str, 190, 624, "Rubik", 12.5, 0x8E8E93, 0.9, false)

    -- 7. Bottom System Status Line (Below Ring 4)
    local cpu_pct = conky_val('${cpu cpu0}') .. "%"
    local mem_pct = conky_val('${memperc}') .. "%"
    local bat_pct = conky_val('${battery_percent BAT0}') .. "%"
    local dsk_pct = conky_val('${fs_used_perc /}') .. "%"

    local sys_line = "Linux " .. kernel_str .. "   •   CPU: " .. cpu_pct .. "   •   RAM: " .. mem_pct .. "   •   BAT: " .. bat_pct .. "   •   DSK: " .. dsk_pct
    draw_text(cr, sys_line, 45, 718, "Rubik", 13, 0xC0C0C0, 0.9, false)

    -- 8. Spotify Music Player Card
    draw_spotify_player(cr, 45, 745, 530, 104)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
