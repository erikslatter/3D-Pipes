GDPC                 
                                                                         \   res://.godot/exported/133200997/export-1d41d32d38c479d92e53a333e24b136e-pipe_segment_c.scn  P�      �      ږ��������5�՜    T   res://.godot/exported/133200997/export-7316f22d4e5e85c1b9ff65ef14bbb845-pipe_mat.res�      $
      �r�і|��'�ÈJ�5    T   res://.godot/exported/133200997/export-73d50b7f59085c9a9ce28353ee849bb1-World.scn        }      �ge�5��jJ��    \   res://.godot/exported/133200997/export-9fc0d38e18a3e78ec305be26f33cb2b5-pipe_segment_a.scn  @�            �)t����*e�    X   res://.godot/exported/133200997/export-cf14e99bcd5cad797259b72ffd500df4-debug_menu.scn  �O      &       �A��]���+d��d�    \   res://.godot/exported/133200997/export-fd6044a12b650e8a41d372e75221ce59-pipe_segment_b.scn  P�      �      O!�a$Փ�7��>m    ,   res://.godot/global_script_class_cache.cfg  0            ��Р�8���8~$}P�    \   res://.godot/imported/3D Pipes 1.apple-touch-icon.png-4a0f147693c24b66b33c48887caf1790.ctex �s      d      \+�:���K1��3�    P   res://.godot/imported/3D Pipes 1.icon.png-d422f9fd428c9d1cdb1a04fc2698c6a2.ctex �      �      �̛�*$q�*�́     L   res://.godot/imported/3D Pipes 1.png-194d804dc5353bafb295bf8760f4a8f2.ctex  ��      -      �%�$����<�׿�+    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex��      �      �̛�*$q�*�́        res://.godot/uid_cache.bin       q      �d�/��.�[īD�q@    ,   res://3D Pipes 1.apple-touch-icon.png.import�      �       ^z�/7��롕��>}        res://3D Pipes 1.icon.png.importП      �        ��(��Q���N�       res://3D Pipes 1.png.import ��      �       ��)�?|����&q���       res://PipeSpawner.gd@�      �      u�k=zE�K�-")��       res://World.tscn.remap  �     b       cI��'��O|+��@Ω    (   res://addons/debug_menu/debug_menu.gd           �O      ��!�z���@\��y�    0   res://addons/debug_menu/debug_menu.tscn.remap   �	     g       �!�'b�2/��d�K    $   res://addons/debug_menu/plugin.gd    p      �      �pp�i]��M5����       res://icon.svg  P     �      C��=U���^Qu��U3       res://icon.svg.import   p�      �       )5���n�������o�       res://pipe_mat.tres.remap    
     e       *��q�N������         res://pipe_segment_a.tscn.remap p
     k       �1��d���p�мEl        res://pipe_segment_b.tscn.remap �
     k       #�wZ!�K>�
��o
        res://pipe_segment_c.tscn.remap P     k       A����[��g��B�       res://project.binary�           �i}��,�����M+        extends Control

@export var fps: Label
@export var frame_time: Label
@export var frame_number: Label
@export var frame_history_total_avg: Label
@export var frame_history_total_min: Label
@export var frame_history_total_max: Label
@export var frame_history_total_last: Label
@export var frame_history_cpu_avg: Label
@export var frame_history_cpu_min: Label
@export var frame_history_cpu_max: Label
@export var frame_history_cpu_last: Label
@export var frame_history_gpu_avg: Label
@export var frame_history_gpu_min: Label
@export var frame_history_gpu_max: Label
@export var frame_history_gpu_last: Label
@export var fps_graph: Panel
@export var total_graph: Panel
@export var cpu_graph: Panel
@export var gpu_graph: Panel
@export var information: Label
@export var settings: Label

## The number of frames to keep in history for graph drawing and best/worst calculations.
## Currently, this also affects how FPS is measured.
const HISTORY_NUM_FRAMES = 150

const GRAPH_SIZE = Vector2(150, 25)
const GRAPH_MIN_FPS = 10
const GRAPH_MAX_FPS = 160
const GRAPH_MIN_FRAMETIME = 1.0 / GRAPH_MIN_FPS
const GRAPH_MAX_FRAMETIME = 1.0 / GRAPH_MAX_FPS

## Debug menu display style.
enum Style {
	HIDDEN,  ## Debug menu is hidden.
	VISIBLE_COMPACT,  ## Debug menu is visible, with only the FPS, FPS cap (if any) and time taken to render the last frame.
	VISIBLE_DETAILED,  ## Debug menu is visible with full information, including graphs.
	MAX,  ## Represents the size of the Style enum.
}

## The style to use when drawing the debug menu.
var style := Style.HIDDEN:
	set(value):
		style = value
		match style:
			Style.HIDDEN:
				visible = false
			Style.VISIBLE_COMPACT, Style.VISIBLE_DETAILED:
				visible = true
				frame_number.visible = style == Style.VISIBLE_DETAILED
				$VBoxContainer/FrameTimeHistory.visible = style == Style.VISIBLE_DETAILED
				$VBoxContainer/FPSGraph.visible = style == Style.VISIBLE_DETAILED
				$VBoxContainer/TotalGraph.visible = style == Style.VISIBLE_DETAILED
				$VBoxContainer/CPUGraph.visible = style == Style.VISIBLE_DETAILED
				$VBoxContainer/GPUGraph.visible = style == Style.VISIBLE_DETAILED
				information.visible = style == Style.VISIBLE_DETAILED
				settings.visible = style == Style.VISIBLE_DETAILED

# Value of `Time.get_ticks_usec()` on the previous frame.
var last_tick := 0

var thread := Thread.new()

## Returns the sum of all values of an array (use as a parameter to `Array.reduce()`).
var sum_func := func avg(accum: float, number: float) -> float: return accum + number

# History of the last `HISTORY_NUM_FRAMES` rendered frames.
var frame_history_total: Array[float] = []
var frame_history_cpu: Array[float] = []
var frame_history_gpu: Array[float] = []
var fps_history: Array[float] = []  # Only used for graphs.

var frametime_avg := GRAPH_MIN_FRAMETIME
var frametime_cpu_avg := GRAPH_MAX_FRAMETIME
var frametime_gpu_avg := GRAPH_MIN_FRAMETIME
var frames_per_second := float(GRAPH_MIN_FPS)
var frame_time_gradient := Gradient.new()

func _init() -> void:
	# This must be done here instead of `_ready()` to avoid having `visibility_changed` be emitted immediately.
	visible = false

	if not InputMap.has_action("cycle_debug_menu"):
		# Create default input action if no user-defined override exists.
		# We can't do it in the editor plugin's activation code as it doesn't seem to work there.
		InputMap.add_action("cycle_debug_menu")
		var event := InputEventKey.new()
		event.keycode = KEY_F3
		InputMap.action_add_event("cycle_debug_menu", event)


func _ready() -> void:
	fps_graph.draw.connect(_fps_graph_draw)
	total_graph.draw.connect(_total_graph_draw)
	cpu_graph.draw.connect(_cpu_graph_draw)
	gpu_graph.draw.connect(_gpu_graph_draw)

	fps_history.resize(HISTORY_NUM_FRAMES)
	frame_history_total.resize(HISTORY_NUM_FRAMES)
	frame_history_cpu.resize(HISTORY_NUM_FRAMES)
	frame_history_gpu.resize(HISTORY_NUM_FRAMES)

	# NOTE: Both FPS and frametimes are colored following FPS logic
	# (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
	# This makes the color gradient non-linear.
	# Colors are taken from <https://tailwindcolor.com/>.
	frame_time_gradient.set_color(0, Color8(239, 68, 68))   # red-500
	frame_time_gradient.set_color(1, Color8(56, 189, 248))  # light-blue-400
	frame_time_gradient.add_point(0.3333, Color8(250, 204, 21))  # yellow-400
	frame_time_gradient.add_point(0.6667, Color8(128, 226, 95))  # 50-50 mix of lime-400 and green-400

	get_viewport().size_changed.connect(update_settings_label)

	# Display loading text while information is being queried,
	# in case the user toggles the full debug menu just after starting the project.
	information.text = "Loading hardware information...\n\n "
	settings.text = "Loading project information..."
	thread.start(
		func():
			# Disable thread safety checks as they interfere with this add-on.
			# This only affects this particular thread, not other thread instances in the project.
			# See <https://github.com/godotengine/godot/pull/78000> for details.
			# Use a Callable so that this can be ignored on Godot 4.0 without causing a script error
			# (thread safety checks were added in Godot 4.1).
			if Engine.get_version_info()["hex"] >= 0x040100:
				Callable(Thread, "set_thread_safety_checks_enabled").call(false)

			# Enable required time measurements to display CPU/GPU frame time information.
			# These lines are time-consuming operations, so run them in a separate thread.
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
			update_information_label()
			update_settings_label()
	)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_debug_menu"):
		style = wrapi(style + 1, 0, Style.MAX) as Style


func _exit_tree() -> void:
	thread.wait_to_finish()


## Update hardware information label (this can change at runtime based on window
## size and graphics settings). This is only called when the window is resized.
## To update when graphics settings are changed, the function must be called manually
## using `DebugMenu.update_settings_label()`.
func update_settings_label() -> void:
	settings.text = ""
	if ProjectSettings.has_setting("application/config/version"):
		settings.text += "Project Version: %s\n" % ProjectSettings.get_setting("application/config/version")

	var rendering_method_string := ""
	match str(ProjectSettings.get_setting("rendering/renderer/rendering_method")):
		"forward_plus":
			rendering_method_string = "Forward+"
		"mobile":
			rendering_method_string = "Forward Mobile"
		"gl_compatibility":
			rendering_method_string = "Compatibility"
	settings.text += "Rendering Method: %s\n" % rendering_method_string

	var viewport := get_viewport()

	# The size of the viewport rendering, which determines which resolution 3D is rendered at.
	var viewport_render_size := Vector2i()

	if viewport.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		viewport_render_size = viewport.get_visible_rect().size
		settings.text += "Viewport: %d×%d, Window: %d×%d\n" % [viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y, viewport.size.x, viewport.size.y]
	else:
		# Window size matches viewport size.
		viewport_render_size = viewport.size
		settings.text += "Viewport: %d×%d\n" % [viewport.size.x, viewport.size.y]

	# Display 3D settings only if relevant.
	if viewport.get_camera_3d():
		var antialiasing_3d_string := ""
		if viewport.use_taa:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "TAA"
		if viewport.msaa_3d >= Viewport.MSAA_2X:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "%d× MSAA" % pow(2, viewport.msaa_3d)
		if viewport.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA:
			antialiasing_3d_string += (" + " if not antialiasing_3d_string.is_empty() else "") + "FXAA"

		settings.text += "3D scale (%s): %d%% = %d×%d" % [
				"Bilinear" if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR else "FSR 1.0",
				viewport.scaling_3d_scale * 100,
				viewport_render_size.x * viewport.scaling_3d_scale,
				viewport_render_size.y * viewport.scaling_3d_scale,
		]

		if not antialiasing_3d_string.is_empty():
			settings.text += "\n3D Antialiasing: %s" % antialiasing_3d_string
		
		var environment := viewport.get_camera_3d().get_world_3d().environment
		if environment:
			if environment.ssr_enabled:
				settings.text += "\nSSR: %d Steps" % environment.ssr_max_steps

			if environment.ssao_enabled:
				settings.text += "\nSSAO: On"
			if environment.ssil_enabled:
				settings.text += "\nSSIL: On"

			if environment.sdfgi_enabled:
				settings.text += "\nSDFGI: %d Cascades" % environment.sdfgi_cascades

			if environment.glow_enabled:
				settings.text += "\nGlow: On"

			if environment.volumetric_fog_enabled:
				settings.text += "\nVolumetric Fog: On"
	var antialiasing_2d_string := ""
	if viewport.msaa_2d >= Viewport.MSAA_2X:
		antialiasing_2d_string = "%d× MSAA" % pow(2, viewport.msaa_2d)

	if not antialiasing_2d_string.is_empty():
		settings.text += "\n2D Antialiasing: %s" % antialiasing_2d_string


## Update hardware/software information label (this never changes at runtime).
func update_information_label() -> void:
	var adapter_string := ""
	# Make "NVIDIA Corporation" and "NVIDIA" be considered identical (required when using OpenGL to avoid redundancy).
	if RenderingServer.get_video_adapter_vendor().trim_suffix(" Corporation") in RenderingServer.get_video_adapter_name():
		# Avoid repeating vendor name before adapter name.
		# Trim redundant suffix sometimes reported by NVIDIA graphics cards when using OpenGL.
		adapter_string = RenderingServer.get_video_adapter_name().trim_suffix("/PCIe/SSE2")
	else:
		adapter_string = RenderingServer.get_video_adapter_vendor() + " - " + RenderingServer.get_video_adapter_name().trim_suffix("/PCIe/SSE2")

	# Graphics driver version information isn't always availble.
	var driver_info := OS.get_video_adapter_driver_info()
	var driver_info_string := ""
	if driver_info.size() >= 2:
		driver_info_string = driver_info[1]
	else:
		driver_info_string = "(unknown)"

	var release_string := ""
	if OS.has_feature("editor"):
		# Editor build (implies `debug`).
		release_string = "editor"
	elif OS.has_feature("debug"):
		# Debug export template build.
		release_string = "debug"
	else:
		# Release export template build.
		release_string = "release"

	var graphics_api_string := ""
	if str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) != "gl_compatibility":
		graphics_api_string = "Vulkan"
	else:
		if OS.has_feature("web"):
			graphics_api_string = "WebGL"
		elif OS.has_feature("mobile"):
			graphics_api_string = "OpenGL ES"
		else:
			graphics_api_string = "OpenGL"

	information.text = (
			"%s, %d threads\n" % [OS.get_processor_name().replace("(R)", "").replace("(TM)", ""), OS.get_processor_count()]
			+ "%s %s (%s %s), %s %s\n" % [OS.get_name(), "64-bit" if OS.has_feature("64") else "32-bit", release_string, "double" if OS.has_feature("double") else "single", graphics_api_string, RenderingServer.get_video_adapter_api_version()]
			+ "%s, %s" % [adapter_string, driver_info_string]
	)


func _fps_graph_draw() -> void:
	var fps_polyline := PackedVector2Array()
	fps_polyline.resize(HISTORY_NUM_FRAMES)
	for fps_index in fps_history.size():
		fps_polyline[fps_index] = Vector2(
				remap(fps_index, 0, fps_history.size(), 0, GRAPH_SIZE.x),
				remap(clampf(fps_history[fps_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	fps_graph.draw_polyline(fps_polyline, frame_time_gradient.sample(remap(frames_per_second, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _total_graph_draw() -> void:
	var total_polyline := PackedVector2Array()
	total_polyline.resize(HISTORY_NUM_FRAMES)
	for total_index in frame_history_total.size():
		total_polyline[total_index] = Vector2(
				remap(total_index, 0, frame_history_total.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_total[total_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	total_graph.draw_polyline(total_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _cpu_graph_draw() -> void:
	var cpu_polyline := PackedVector2Array()
	cpu_polyline.resize(HISTORY_NUM_FRAMES)
	for cpu_index in frame_history_cpu.size():
		cpu_polyline[cpu_index] = Vector2(
				remap(cpu_index, 0, frame_history_cpu.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_cpu[cpu_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	cpu_graph.draw_polyline(cpu_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_cpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _gpu_graph_draw() -> void:
	var gpu_polyline := PackedVector2Array()
	gpu_polyline.resize(HISTORY_NUM_FRAMES)
	for gpu_index in frame_history_gpu.size():
		gpu_polyline[gpu_index] = Vector2(
				remap(gpu_index, 0, frame_history_gpu.size(), 0, GRAPH_SIZE.x),
				remap(clampf(frame_history_gpu[gpu_index], GRAPH_MIN_FPS, GRAPH_MAX_FPS), GRAPH_MIN_FPS, GRAPH_MAX_FPS, GRAPH_SIZE.y, 0.0)
		)
	# Don't use antialiasing to speed up line drawing, but use a width that scales with
	# viewport scale to keep the line easily readable on hiDPI displays.
	gpu_graph.draw_polyline(gpu_polyline, frame_time_gradient.sample(remap(1000.0 / frametime_gpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0)), 1.0)


func _process(_delta: float) -> void:
	if visible:
		fps_graph.queue_redraw()
		total_graph.queue_redraw()
		cpu_graph.queue_redraw()
		gpu_graph.queue_redraw()

		# Difference between the last two rendered frames in milliseconds.
		var frametime := (Time.get_ticks_usec() - last_tick) * 0.001

		frame_history_total.push_back(frametime)
		if frame_history_total.size() > HISTORY_NUM_FRAMES:
			frame_history_total.pop_front()

		# Frametimes are colored following FPS logic (red = 10 FPS, yellow = 60 FPS, green = 110 FPS, cyan = 160 FPS).
		# This makes the color gradient non-linear.
		frametime_avg = frame_history_total.reduce(sum_func) / frame_history_total.size()
		frame_history_total_avg.text = str(frametime_avg).pad_decimals(2)
		frame_history_total_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_min: float = frame_history_total.min()
		frame_history_total_min.text = str(frametime_min).pad_decimals(2)
		frame_history_total_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_max: float = frame_history_total.max()
		frame_history_total_max.text = str(frametime_max).pad_decimals(2)
		frame_history_total_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		frame_history_total_last.text = str(frametime).pad_decimals(2)
		frame_history_total_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var viewport_rid := get_viewport().get_viewport_rid()
		var frametime_cpu := RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
		frame_history_cpu.push_back(frametime_cpu)
		if frame_history_cpu.size() > HISTORY_NUM_FRAMES:
			frame_history_cpu.pop_front()

		frametime_cpu_avg = frame_history_cpu.reduce(sum_func) / frame_history_cpu.size()
		frame_history_cpu_avg.text = str(frametime_cpu_avg).pad_decimals(2)
		frame_history_cpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_cpu_min: float = frame_history_cpu.min()
		frame_history_cpu_min.text = str(frametime_cpu_min).pad_decimals(2)
		frame_history_cpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_cpu_max: float = frame_history_cpu.max()
		frame_history_cpu_max.text = str(frametime_cpu_max).pad_decimals(2)
		frame_history_cpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		frame_history_cpu_last.text = str(frametime_cpu).pad_decimals(2)
		frame_history_cpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_cpu, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		frame_history_gpu.push_back(frametime_gpu)
		if frame_history_gpu.size() > HISTORY_NUM_FRAMES:
			frame_history_gpu.pop_front()

		frametime_gpu_avg = frame_history_gpu.reduce(sum_func) / frame_history_gpu.size()
		frame_history_gpu_avg.text = str(frametime_gpu_avg).pad_decimals(2)
		frame_history_gpu_avg.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_avg, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_gpu_min: float = frame_history_gpu.min()
		frame_history_gpu_min.text = str(frametime_gpu_min).pad_decimals(2)
		frame_history_gpu_min.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_min, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		var frametime_gpu_max: float = frame_history_gpu.max()
		frame_history_gpu_max.text = str(frametime_gpu_max).pad_decimals(2)
		frame_history_gpu_max.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu_max, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		frame_history_gpu_last.text = str(frametime_gpu).pad_decimals(2)
		frame_history_gpu_last.modulate = frame_time_gradient.sample(remap(1000.0 / frametime_gpu, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))

		frames_per_second = 1000.0 / frametime_avg
		fps_history.push_back(frames_per_second)
		if fps_history.size() > HISTORY_NUM_FRAMES:
			fps_history.pop_front()

		fps.text = str(floor(frames_per_second)) + " FPS"
		var frame_time_color := frame_time_gradient.sample(remap(frames_per_second, GRAPH_MIN_FPS, GRAPH_MAX_FPS, 0.0, 1.0))
		fps.modulate = frame_time_color

		frame_time.text = str(frametime).pad_decimals(2) + " mspf"
		frame_time.modulate = frame_time_color

		var vsync_string := ""
		match DisplayServer.window_get_vsync_mode():
			DisplayServer.VSYNC_ENABLED:
				vsync_string = "V-Sync"
			DisplayServer.VSYNC_ADAPTIVE:
				vsync_string = "Adaptive V-Sync"
			DisplayServer.VSYNC_MAILBOX:
				vsync_string = "Mailbox V-Sync"

		if Engine.max_fps > 0 or OS.low_processor_usage_mode:
			# Display FPS cap determined by `Engine.max_fps` or low-processor usage mode sleep duration
			# (the lowest FPS cap is used).
			var low_processor_max_fps := roundi(1000000.0 / OS.low_processor_usage_mode_sleep_usec)
			var fps_cap := low_processor_max_fps
			if Engine.max_fps > 0:
				fps_cap = mini(Engine.max_fps, low_processor_max_fps)
			frame_time.text += " (cap: " + str(fps_cap) + " FPS"

			if not vsync_string.is_empty():
				frame_time.text += " + " + vsync_string

			frame_time.text += ")"
		else:
			if not vsync_string.is_empty():
				frame_time.text += " (" + vsync_string + ")"

		frame_number.text = "Frame: " + str(Engine.get_frames_drawn())

	last_tick = Time.get_ticks_usec()


func _on_visibility_changed() -> void:
	if visible:
		# Reset graphs to prevent them from looking strange before `HISTORY_NUM_FRAMES` frames
		# have been drawn.
		var frametime_last := (Time.get_ticks_usec() - last_tick) * 0.001
		fps_history.resize(HISTORY_NUM_FRAMES)
		fps_history.fill(1000.0 / frametime_last)
		frame_history_total.resize(HISTORY_NUM_FRAMES)
		frame_history_total.fill(frametime_last)
		frame_history_cpu.resize(HISTORY_NUM_FRAMES)
		var viewport_rid := get_viewport().get_viewport_rid()
		frame_history_cpu.fill(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu())
		frame_history_gpu.resize(HISTORY_NUM_FRAMES)
		frame_history_gpu.fill(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
RSRC                    PackedScene            ��������                                            7      VBoxContainer    FPS 
   FrameTime    FrameNumber    FrameTimeHistory 	   TotalAvg 	   TotalMin 	   TotalMax 
   TotalLast    CPUAvg    CPUMin    CPUMax    CPULast    GPUAvg    GPUMin    GPUMax    GPULast 	   FPSGraph    Graph    TotalGraph 	   CPUGraph 	   GPUGraph    Information 	   Settings    resource_local_to_scene    resource_name    content_margin_left    content_margin_top    content_margin_right    content_margin_bottom 	   bg_color    draw_center    skew    border_width_left    border_width_top    border_width_right    border_width_bottom    border_color    border_blend    corner_radius_top_left    corner_radius_top_right    corner_radius_bottom_right    corner_radius_bottom_left    corner_detail    expand_margin_left    expand_margin_top    expand_margin_right    expand_margin_bottom    shadow_color    shadow_size    shadow_offset    anti_aliasing    anti_aliasing_size    script 	   _bundled       Script &   res://addons/debug_menu/debug_menu.gd ��������      local://StyleBoxFlat_ki0n8 �         local://PackedScene_x2nm1 �         StyleBoxFlat                      s��>5         PackedScene    6      	         names "   \      CanvasLayer    layer 
   DebugMenu    custom_minimum_size    layout_mode    anchors_preset    anchor_left    anchor_right    offset_left    offset_top    offset_right    offset_bottom    grow_horizontal    size_flags_horizontal    size_flags_vertical    mouse_filter    script    fps    frame_time    frame_number    frame_history_total_avg    frame_history_total_min    frame_history_total_max    frame_history_total_last    frame_history_cpu_avg    frame_history_cpu_min    frame_history_cpu_max    frame_history_cpu_last    frame_history_gpu_avg    frame_history_gpu_min    frame_history_gpu_max    frame_history_gpu_last 
   fps_graph    total_graph 
   cpu_graph 
   gpu_graph    information 	   settings    Control    VBoxContainer $   theme_override_constants/separation    FPS 	   modulate )   theme_override_colors/font_outline_color &   theme_override_constants/outline_size &   theme_override_constants/line_spacing $   theme_override_font_sizes/font_size    text    horizontal_alignment    Label 
   FrameTime    FrameNumber    FrameTimeHistory &   theme_override_constants/h_separation &   theme_override_constants/v_separation    columns    GridContainer    Spacer 
   AvgHeader 
   MinHeader 
   MaxHeader    LastHeader    TotalHeader 	   TotalAvg 	   TotalMin 	   TotalMax 
   TotalLast 
   CPUHeader    CPUAvg    CPUMin    CPUMax    CPULast 
   GPUHeader    GPUAvg    GPUMin    GPUMax    GPULast 	   FPSGraph 
   alignment    HBoxContainer    Title    vertical_alignment    Graph    theme_override_styles/panel    Panel    TotalGraph 	   CPUGraph 	   GPUGraph    Information 	   Settings    _on_visibility_changed    visibility_changed    	   variants    D      �   
     �C  �C                 �?     ��      A     ��     �C                                                                                                                                                       	                
                                                                                                                                                                                                  ��     �C         �?      �?                 �?                  60 FPS          ,   16.67 mspf (cap: 123 FPS + Adaptive V-Sync)       Frame: 1234 
     pB    
     HB          Average       Best       Worst       Last       Total:       123.45       CPU:       12.34       GPU:       1.23 
         �A   	   FPS: ↑ 
     C  �A                Total: ↓    	   CPU: ↓    	   GPU: ↓      �?  �?  �?��@?   {   12th Gen Intel(R) Core(TM) i0-1234K
Windows 12 64-bit (double precision), Vulkan 1.2.34
NVIDIA GeForce RTX 1234, 123.45.67    ��L?=
W?  �?��@?     Project Version: 1.2.3
Rendering Method: Forward+
Window: 1234×567, Viewport: 1234×567
3D Scale (FSR 1.0): 100% = 1234×567
3D Antialiasing: TAA + 2× MSAA + FXAA
SSR: 123 Steps
SSAO: On
SSIL: On
SDFGI: 1 Cascades
Glow: On
Volumetric Fog: On
2D Antialiasing: 2× MSAA       node_count    )         nodes     s  ��������        ����                      &      ����#                                       	      
               	      
                       @     @     @     @     @     @     @     @     @     @     @     @     @     @     @      @   !  @   "  @   #  @    $  @!   %  @"              '   '   ����	                              #      $      	         (   	              1   )   ����   *   %         +   &   ,   '   -   	   .   (   /   )   0                 1   2   ����   *   %         +   &   ,      .   *   /   +   0                 1   3   ����         +   &   ,      .   *   /   ,   0                 8   4   ����            
         5   	   6   	   7   '              &   9   ����      -                          1   :   ����      .         +   &   ,      .   *   /   /   0                 1   ;   ����      .         +   &   ,      .   *   /   0   0                 1   <   ����      .         +   &   ,      .   *   /   1   0                 1   =   ����      .         +   &   ,      .   *   /   2   0                 1   >   ����      .         +   &   ,      .   *   /   3   0                 1   ?   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   @   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   A   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   B   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   C   ����      .         +   &   ,      .   *   /   5   0                 1   D   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   E   ����   *   %      .         +   &   ,      .   *   /   6   0                 1   F   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   G   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   H   ����      .         +   &   ,      .   *   /   7   0                 1   I   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   J   ����   *   %      .         +   &   ,      .   *   /   8   0                 1   K   ����   *   %      .         +   &   ,      .   *   /   4   0                 1   L   ����   *   %      .         +   &   ,      .   *   /   4   0                 O   M   ����               N                 1   P   ����      9            
   +   &   ,      .   *   /   :   Q                 T   R   ����      ;            	         S   <              O   U   ����               N                 1   P   ����      9            
   +   &   ,      .   *   /   =   Q                 T   R   ����      ;            	         S   <              O   V   ����               N          !       1   P   ����      9            
   +   &   ,      .   *   /   >   Q          !       T   R   ����      ;            	         S   <              O   W   ����               N          $       1   P   ����      9            
   +   &   ,      .   *   /   ?   Q          $       T   R   ����      ;            	         S   <              1   X   ����   *   @         +   &   ,      .   *   /   A   0                 1   Y   ����   *   B         +   &   ,      .   *   /   C   0                conn_count             conns              [   Z                    node_paths              editable_instances              version       5      RSRC          @tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("DebugMenu", "res://addons/debug_menu/debug_menu.tscn")

	# FIXME: This appears to do nothing.
#	if not ProjectSettings.has_setting("application/config/version"):
#		ProjectSettings.set_setting("application/config/version", "1.0.0")
#
#	ProjectSettings.set_initial_value("application/config/version", "1.0.0")
#	ProjectSettings.add_property_info({
#		name = "application/config/version",
#		type = TYPE_STRING,
#	})
#
#	if not InputMap.has_action("cycle_debug_menu"):
#		InputMap.add_action("cycle_debug_menu")
#		var event := InputEventKey.new()
#		event.keycode = KEY_F3
#		InputMap.action_add_event("cycle_debug_menu", event)
#
#	ProjectSettings.save()


func _exit_tree() -> void:
	remove_autoload_singleton("DebugMenu")
	# Don't remove the project setting's value and input map action,
	# as the plugin may be re-enabled in the future.
       GST2   �   �      ����               � �        ,  RIFF$  WEBPVP8L  /��,͘i�6�f����Ū��W�l�l$A���)�@���6��p��s Fm#I
����n?B��q�8�ۆ8����E�=4a�9����B�/�@�����H�p�@���ϑ�U�f�; d�� &S8�� ��2\�.��L^��F2'v�Qwǵ&bضmf���Zܶ�$�NMO����;�Kv�mk��RHV�p���033��ޠx�2S�`<��m�HR��{��7���Om�m�~���H2�CNS�۝��dfZ��o�\�E���(�\H�$�f���&�I-a��m��6����}b33̣3�:��f�0H�%G��ɶU۶m�S�s��m'��Bi3�^s8pI�\��u��9�m��27z#r���_�	��=x-x!��^�Rw}v��R�܋Í%Ƕ���X����	�ԉƭ��p�E��$I�D���;���/��ڶ������$���b������%�to� � �� ��ع�,���%��hD"(��&���x�w�����������w{���m۽  ���͍�oN�N�9�"F�P ���¡��7��A	c���6���À��� ��6�n���Yz�cZЏ�F�c�:wO��ήҲ�"��~ĳ��}t�;`�ѯ�w��v��B4��\��<;�E eyL˫�o7�-�n'��w7��rs�jP�~0����:)ZB�@� av��;�_^�{��޵��u��#F�t���-����"� �((�h����  Ԣw��������qgU}� }�wW�w�>}?����]DTUU�:R#���*Դ1�4�JD  BD�[5O_�<�ww*ԅ�o��ѹ��F��)�Ek4UT��EP
2���n���2i������E�=۾Y�Y���|��M���r�n�I5ESTF!�  PcD��Rmc�7��@�M����o<V��n��m�۶{�߶�g�`"��֭�Ѫh��RA@��Q��d�VU��V[[���^ue�C��۽�oǿ}��+�BG�F[E�����j҈:�zl���5At��^�f��uRT��FSEP,���iK������/�-���m�d��g��I5F[E� �h��H
 !Zrg��f��&�ad��e������)Ƌ� �V�/����,#�]Sk遌�MY���h�JA�Tm�� ����q`e�� ��D��R� ��C����{��4�( Q5UP@�h��@��i�yv���_�I�eUE���H1�r�-�{��u��E�(!A4��eFЉZ ��PD]T"�ԡ��`!�H�A@�hDf0J@!M;��4��N:ʸ:} ��G�(�nD���c$ ��� ����GCu����˭i#S.bV3s�1v��
���>����$'���6����"�-R�)؏�#Q8%�Bפ��Ժ`�U�jh���t�
 �,�˺����b���ր:�&B\iѷѾ'��ih�ݕOҴ6nNi9vǹ(Ӫ̷zZj�N� o'
\���<3R� iYg�u�B%��N������ẽ�
�*a��Ekס.��?ϗ�r�`^9����um5-ƶ��������T�r�w}�������8�8����*������{���A�D�$�����l��%S�v��SP8�aWկ���O���I��H��Y���KNL�Ϧ�*%��-���ieok.\�p�O�����&-���qTtf唯�E��ObB�&$:a�c�����X"�\l�]EW\8��\�g�"LF"K \lY,.#W��s�*:���ه˅$lM	W��HW>�\��;S�� ��� og[&\�ĕb��v��Ť��4[E��$}*��)K�l�S��B'Ϊ�,����~J
Q��nL�"u�;k�&�R�RL���\;=��ڥT$��nk��!�l�B�dG��!kQ3��?�%���i�k<�wޝ݀�I2�H��rCx"�@��[�^&gv8N+b�r�6wCӒ�G����_#d��n�;�p߃������b�e-�q��.ƹ����.�n�ҥ�'�Y���Y�J�*�[��F4�j�Z��U8A��6��Q5F$u^L�9Iq ��]�vi.P�Pj5d�1d ����o��5���j���*x��~77�+�mp�N�W� I�{��^��4j��õ�z[Q��=�����}۪��ر�ۻަ ހ(��}{�<��������R*O���lc{c�noݥD�W����ٽ}M	W�c����� ~u����"�R��9!h0Z;k�v�殻ת���p۠	Q����"j��j ���C�uom+t��(�M��y*iȀP���ۃ5Xc�
"	�:K&�W�t��?�"����#U?z��MH���bk��
N��m�&�]�ԑ&m����c[�W%*Pa��]�_}������n���Xg*�柮���?��s��1-P���������ٺL����i��]|n����rRgYT�-^4�����K/�xU�ANUw����K/����9�4&U�<��;��f/+���y�O��'˧{��w�f�B�.�"����UI<�d�w����w�('�y���s��W���������X�U��/8���?7wRX���%��UA�(y���6��KU`�˼���������]���������,x�ۿ�S�ݷ�f�z���|��I��M�&�<������j4�e��\|GLE�w���dP��s�~�}�a�|⛝~y溂/�ss�P�q�KO�}|�K�)wݛt�/!�i(a�i���O׸.�H6�����>1��<�-�g�P�Pj�m����S��w$��<������׿e�,��f��M�_m��Ӻ�>�����n���������^����F��΍�׷����ZW���b�U�?�_��o��G���ܸj�y��6�׾)8�ւ��uG����6�/��Q�;���/�_��u[n�������U���"�l���/��&\C4��5���꣪
�����}�%���S�����U�^U�tS��6���_3xR�fE���y�Ԉ��r�����X�W|ޝ�y1-���]�uo���6��'7�;����W�����>�=�N�y��݄m� B$ЭݽU�L��'�L^տ q���1�t�%L�!��7��}��˶_ֽ)J�^PG�L�G���}�lg|�}�g:d
hX��<ܽ˘��Nmm>e׸�{_Ҿ���Q�/�/Vy	��]��p,@����y)�l��F�=�qE�L�/�~��T���Cb  `�_����� Եx�F���Wm�(� �I��[�\kb8�_�
�0��'��Q�%G�گ~�?�A�����w����o�~D���\�����c|��UG�9�+�{���=4 �݆���-�e�G�WQG�#��>�k��Ϻou���?i\׹��֪]�{��7M^��gM^v�u�ߨ]���k���R~����pM�_�ݟ�sȪ��y5�|��(22`9�?�c]�S��OlLp��	�V��_��h� @�΍�_�q�Z��=.8��z�֌ 0Oy�� T;����(� ��eY_f�X�q�K2kyGݛԩ+[�{�w��RW�J9b>�����	w� �_�&u��\ ֳ,�%2���Z�ԑ�7�����72���b��)%����&���@�C��qADV�T�.�\k��Be�A�p��D��  Qn�a�!,*��-&�v�;�r��w�<��c�a��wnw嚗Rn��- �ڍWs�E�I��a���no/�����l�+K���V�W��o���s�رve���Cߛ�_����g����u^=B��ױ	�����*�y�U�C�:����_�w������[����_�~�u<���Rf��O����̮=������v���29��F�9����< ��S��/�����X��ޯ�������d;T�����;�Gs�o���������K�XC���&Vr���y5�r��;s{�_�,��~���W���{���ʵ���Ǉ��o������n���ܫ�o`؟X�?�n��ֻI���Z^r�ڭ�w�z��I �\�'�f`�\��ӾwW���/�����}�랿vqs�;�:�?���?����/?���o��Ľ��t3�O����m�����v���䉋G�����k|�{��������~���%�*�Q�/���|����=��o~�o|��W7��L�������~��w��/��7�/�nFZG����?���_��}������u����{�~g�n��3�Ѽ%��9�g�׏Ϋ�dy�����q�Ooy!��S��ڭ·�|�w������(��e�}�]���Y'�s{IO���m���n�A�C�=�������t~ [s{:��P	G�ɸ�m�wV�%�� ;8�+Y�u<}�}1��.����Օ�!*�eqD�HJ�����'6>Ը�p80��Y]��ϳ<;6�8U �uX_�M�m��+
A�37��G9��ʮfj�qH�cj*��B\s^�өs^��'��a0;��p��2��'�q�j��E}m�K����S�Ӵf�r��N �l�a�
�'�]��唣����w0�ǧq~!zNVj��s�}6���2��s^�����N�V�E���Q^}�1�����<��E��_s��D��F�~��ּޮ�u3=q���8��]��#�[����$^�ڢ	�xIR'EX���۰?�"i]��q;'���q�s���!LD�DDC4���׃R,�d|�{'����eϳ��e�R�e�;W�+7��͹�-�UI�Ȓ��&�X4�%�!����G���Gr��o��WT���t��~�qa��ki�*�ŉ���I�,9��ʡ�թ���/_�|��K� �� �����(�`���֔p��b;�ϖ�-+g&g�'�u�@X��x���$R�Đ�Ȓ����o?��G�ŵ8�JQ
�"X��r�8�m Ac��)���uG5��ܡ��2�p\\ܲî������/�{~��dQP�v�P�C�A@�lmA�����v����N��q���!��hw_�����OX���2#�dg~����<N�8�����)w�@��C���J��J����_2Ob�G�����)�$�}1Eʳmv`%�d9��f��$��!iILYx����я�{~�u����Mw`�,�B�G�P��s
E{���x��1V��@N���O�sR&9d�����?;3�ҤI��&�ݥIca�Uf���$S�u��.&��#Ym��e�c��"|�nf��NN�q8������T!�L@�U��R�λ3��>T�|�3�B'*G4�vnL2�|`y8�b@s�tDae��)X� �5_�M�IM��6���J C�s�Q�2��s�)O�x�V��@�$�LR:*��^�i�������J|��*KvO
 �ȑ�ϸ=�����0�����2y:*���R�@�8�0��'+c٧@����;={z<���ً��2�.��  �,��,�B� `���(��������(�Y�d.�0-� p�YI�����c�/���'�L�LX+}y-����?�u�VS����l5h�
8b%e]6��g��F�j��}�$2��|dI[}��d$2�Y��?� �T����i�/�)�2�2s�8���Ŕ��$��s�d*)So֚[�$ ��
[���\����=|E��o�����&�4QBj��D�
�_|� ����)[��O��_�7fg����4_�/���ï��  `��b�ba�bxcV�A]L]��]���{ ?����Ѓ��� 	ABd��.#$AB2�F�գ�i�z5P���= Y§��������~�(9[�w�ޞ�/?c��z c��^R��O�ų�=��5Y�]��)�y��ɢ.�|�/�?����8�M�8�$�5:3q3:� 5 ���N~�1�Q���n��#K��3�ČV�FΊ1#1�߇���7�g�𮖅`�E	(>�u�g~��H�+�͂��Wϻ�����=J_O_ϻ�]��ߏ
x�V_��a��;7ۋ�}�<ʿx�4?���Z�[�]�n���u�nc����u�-�l�B]k�7�ߨ� YD	�]�@	�t�p_K�L4�A��h���z;M��j����bꂺ����?�;���m<y��s?�{��a{�9bFΊF�jb�,����I4�R1d�����Ҕ�@��[]7�O���b���ҏ�9�G6l�ׯ�Λ��6~�g��_Ɵ�yaj�@Ge4bgm������[$g�� H&ģ	(G��lO��D(duv�@YRg�D͝G%X2~�Ҁ&�w-yV蜼e;P����jS~�dl�խg[��r�Zּ�eK��j�.����k1&iY@	Ӷ�\�R�D_����Yf�$��~��؆�iP	�u�uZ(g E�ڴi[�<��-�vf���#�(o���n�h�$��4BD*�e�6��s6�ԁ���n�`J�4<,q\�k߻�5P�<�
�ע��%(�g�2o}m�բ,��H��h���HK�����n"�A��V����ղ�".W�BԬC�5���0*�H���LD"C"�b!�=_&�����@�2!E`5�[M�47Z�&VX���h-{�a�����)!K�GKˏ�CI�v
���d��a0a	+\��JEi�ЖOd��
����'�4�gj�@G "� �;l�8��Ld����R�B���TX+`tIr9A� D&J�%:i��ɞ��˕�3��g�<&��P� ��- LA�(�*p���ŕ�D&2�� c��T�g�@iE��#4 �)���4SeG21���&4��H�H4� c�B�v���6*#F�N0�OLa�.F��*�"B1�[h�=1EӸՒ"��$R�(�?�yg�s�� D%no�T	73x0hH2�e��e���<������( �4'�#�Og�P{���vv�0}�Ť1j�ە@�S�( �r�Vo��
�ز�B^!�qc����6�Z5 ���"��l`y����t� ������h��U�*���������7�-�wN�ۭVŤQUQ�X��� rIr�9�*  ��v���j�5D Ŵ��R�:+<h�"?� Dۢ�--@4f�CDw��;��Vc��T�VQ�F�5������3�M�μr ��~���~k�<� b H��Q�$B�gg"�+s�U����յ|ߦ��A�3�r��s�}���"��IW_P��T)�pB��R	@J*�S����]�:bKW��� L�1إq�����l����c=DtDU�fQ��Ҏ J��*S:�T8!;�Gl���*��:�����������jk�����"�� �(���J��@�چ ������������G�5��pY�����k���]O��B��-��E�l��Z�o�W�x���������� _xՕ��kr�R̝�,# A��#��hK��ni��l�ktx�ч���k��!�-���fd�k*��~�̡"����ͱ���������`.���-}�����ɮ�'s�Ф�Mg�!�:d�� R�� la.��t�}�V��6m@e�u��߃�gڏ>l��k�����-�qh�n��w/fFЉF4�Q)��am�G�y:խ��+ `�e� �5��               [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://v7sotu71gwhu"
path="res://.godot/imported/3D Pipes 1.apple-touch-icon.png-4a0f147693c24b66b33c48887caf1790.ctex"
metadata={
"vram_texture": false
}
          GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /������!"2�H�$�n윦���z�x����դ�<����q����F��Z��?&,
ScI_L �;����In#Y��0�p~��Z��m[��N����R,��#"� )���d��mG�������ڶ�$�ʹ���۶�=���mϬm۶mc�9��z��T��7�m+�}�����v��ح�m�m������$$P�����එ#���=�]��SnA�VhE��*JG�
&����^x��&�+���2ε�L2�@��		��S�2A�/E���d"?���Dh�+Z�@:�Gk�FbWd�\�C�Ӷg�g�k��Vo��<c{��4�;M�,5��ٜ2�Ζ�yO�S����qZ0��s���r?I��ѷE{�4�Ζ�i� xK�U��F�Z�y�SL�)���旵�V[�-�1Z�-�1���z�Q�>�tH�0��:[RGň6�=KVv�X�6�L;�N\���J���/0u���_��U��]���ǫ)�9��������!�&�?W�VfY�2���༏��2kSi����1!��z+�F�j=�R�O�{�
ۇ�P-�������\����y;�[ ���lm�F2K�ޱ|��S��d)é�r�BTZ)e�� ��֩A�2�����X�X'�e1߬���p��-�-f�E�ˊU	^�����T�ZT�m�*a|	׫�:V���G�r+�/�T��@U�N׼�h�+	*�*sN1e�,e���nbJL<����"g=O��AL�WO!��߈Q���,ɉ'���lzJ���Q����t��9�F���A��g�B-����G�f|��x��5�'+��O��y��������F��2�����R�q�):VtI���/ʎ�UfěĲr'�g�g����5�t�ۛ�F���S�j1p�)�JD̻�ZR���Pq�r/jt�/sO�C�u����i�y�K�(Q��7őA�2���R�ͥ+lgzJ~��,eA��.���k�eQ�,l'Ɨ�2�,eaS��S�ԟe)��x��ood�d)����h��ZZ��`z�պ��;�Cr�rpi&��՜�Pf��+���:w��b�DUeZ��ڡ��iA>IN>���܋�b�O<�A���)�R�4��8+��k�Jpey��.���7ryc�!��M�a���v_��/�����'��t5`=��~	`�����p\�u����*>:|ٻ@�G�����wƝ�����K5�NZal������LH�]I'�^���+@q(�q2q+�g�}�o�����S߈:�R�݉C������?�1�.��
�ڈL�Fb%ħA ����Q���2�͍J]_�� A��Fb�����ݏ�4o��'2��F�  ڹ���W�L |����YK5�-�E�n�K�|�ɭvD=��p!V3gS��`�p|r�l	F�4�1{�V'&����|pj� ߫'ş�pdT�7`&�
�1g�����@D�˅ �x?)~83+	p �3W�w��j"�� '�J��CM�+ �Ĝ��"���4� ����nΟ	�0C���q'�&5.��z@�S1l5Z��]�~L�L"�"�VS��8w.����H�B|���K(�}
r%Vk$f�����8�ڹ���R�dϝx/@�_�k'�8���E���r��D���K�z3�^���Vw��ZEl%~�Vc���R� �Xk[�3��B��Ğ�Y��A`_��fa��D{������ @ ��dg�������Mƚ�R�`���s����>x=�����	`��s���H���/ū�R�U�g�r���/����n�;�SSup`�S��6��u���⟦;Z�AN3�|�oh�9f�Pg�����^��g�t����x��)Oq�Q�My55jF����t9����,�z�Z�����2��#�)���"�u���}'�*�>�����ǯ[����82һ�n���0�<v�ݑa}.+n��'����W:4TY�����P�ר���Cȫۿ�Ϗ��?����Ӣ�K�|y�@suyo�<�����{��x}~�����~�AN]�q�9ޝ�GG�����[�L}~�`�f%4�R!1�no���������v!�G����Qw��m���"F!9�vٿü�|j�����*��{Ew[Á��������u.+�<���awͮ�ӓ�Q �:�Vd�5*��p�ioaE��,�LjP��	a�/�˰!{g:���3`=`]�2��y`�"��N�N�p���� ��3�Z��䏔��9"�ʞ l�zP�G�ߙj��V�>���n�/��׷�G��[���\��T��Ͷh���ag?1��O��6{s{����!�1�Y�����91Qry��=����y=�ٮh;�����[�tDV5�chȃ��v�G ��T/'XX���~Q�7��+[�e��Ti@j��)��9��J�hJV�#�jk�A�1�^6���=<ԧg�B�*o�߯.��/�>W[M���I�o?V���s��|yu�xt��]�].��Yyx�w���`��C���pH��tu�w�J��#Ef�Y݆v�f5�e��8��=�٢�e��W��M9J�u�}]釧7k���:�o�����Ç����ս�r3W���7k���e�������ϛk��Ϳ�_��lu�۹�g�w��~�ߗ�/��ݩ�-�->�I�͒���A�	���ߥζ,�}�3�UbY?�Ӓ�7q�Db����>~8�]
� ^n׹�[�o���Z-�ǫ�N;U���E4=eȢ�vk��Z�Y�j���k�j1�/eȢK��J�9|�,UX65]W����lQ-�"`�C�.~8ek�{Xy���d��<��Gf�ō�E�Ӗ�T� �g��Y�*��.͊e��"�]�d������h��ڠ����c�qV�ǷN��6�z���kD�6�L;�N\���Y�����
�O�ʨ1*]a�SN�=	fH�JN�9%'�S<C:��:`�s��~��jKEU�#i����$�K�TQD���G0H�=�� �d�-Q�H�4�5��L�r?����}��B+��,Q�yO�H�jD�4d�����0*�]�	~�ӎ�.�"����%
��d$"5zxA:�U��H���H%jس{���kW��)�	8J��v�}�rK�F�@�t)FXu����G'.X�8�KH;���[             [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://cn0auuk3s6uwv"
path="res://.godot/imported/3D Pipes 1.icon.png-d422f9fd428c9d1cdb1a04fc2698c6a2.ctex"
metadata={
"vram_texture": false
}
     GST2      X     ����                X       �,  RIFF�,  WEBPVP8L�,  /Õ�mۆq�����1�Ve���G�N^6۶�'�����L �	���������'�G�n$�V����p����̿���H�9��L߃�E۶c��ۘhd�1�Nc��6���I܁���[�(�#�m�9��'�mۦL���f�����~�=��!i�f��&�"�	Y���,�A����z����I�mmN����#%)Ȩ��b��P
��l"��m'���U�,���FQ�S�m�$�pD��жm�m۶m#�0�F�m�6����$I�3���s�������oI�,I�l���Cn����Bm&�*&sӹEP���|[=Ij[�m۝m��m���l۶m��g{gK�jm���$�vۦ�W=n�  q��I$Ij�	�J�x����U��޽�� I�i[up�m۶m۶m۶m۶m�ټ�47�$)Ι�j�E�|�C?����/�����/�����/�����/�����/�����/�����/�����̸k*�u����j_R�.�ΗԳ�K+�%�=�A�V0#��������3��[ނs$�r�H�9xޱ�	T�:T��iiW��V�`������h@`��w�L�"\�����@|�
a2�T� ��8b����~�z��'`	$� KśϾ�OS��	���;$�^�L����α��b�R鷺�EI%��9  �7� ,0 @Nk�p�Uu��R�����Ω��5p7�T�'`/p����N�گ�
�F%V�9;!�9�)�9��D�h�zo���N`/<T�����֡cv��t�EIL���t  �qw�AX�q �a�VKq���JS��ֱ؁�0F�A�
�L��2�ѾK�I%�}\ �	�*�	1���i.'���e.�c�W��^�?�Hg���Tm�%�o�
oO-  x"6�& `��R^���WU��N��" �?���kG�-$#���B��#���ˋ�銀�z֊�˧(J�'��c  ��� vNmŅZX���OV�5X R�B%an	8b!		e���6�j��k0C�k�*-|�Z  ��I� \���v  ��Qi�+PG�F������E%����o&Ӎ��z���k��;	Uq�E>Yt�����D��z��Q����tɖA�kӥ���|���1:�
v�T��u/Z�����t)�e����[K㡯{1<�;[��xK���f�%���L�"�i�����S'��󔀛�D|<�� ��u�={�����L-ob{��be�s�V�]���"m!��*��,:ifc$T����u@8 	!B}� ���u�J�_  ��!B!�-� _�Y ��	��@�����NV]�̀����I��,|����`)0��p+$cAO�e5�sl������j�l0 vB�X��[a��,�r��ς���Z�,| % ȹ���?;9���N�29@%x�.
k�(B��Y��_  `fB{4��V�_?ZQ��@Z�_?�	,��� � ��2�gH8C9��@���;[�L�kY�W�
*B@� 8f=:;]*LQ��D
��T�f=�` T����t���ʕ�￀�p�f�m@��*.>��OU�rk1e�����5{�w��V!���I[����X3�Ip�~�����rE6�nq�ft��b��f_���J�����XY�+��JI�vo9��x3�x�d�R]�l�\�N��˂��d�'jj<����ne������8��$����p'��X�v����K���~ � �q�V������u/�&PQR�m����=��_�EQ�3���#����K���r  ��J	��qe��@5՗�/# l:�N�r0u���>��ׁd��ie2� ���G'& �`5���s����'����[%9���ۓ�Хމ�\15�ƀ�9C#A#8%��=%�Z%y��Bmy�#�$4�)dA�+��S��N}��Y�%�Q�a�W��?��$�3x $��6��pE<Z�Dq��8���p��$H�< �֡�h�cާ���u�  �"Hj$����E%�@z�@w+$�	��cQ��
1�)��������R9T��v�-  xG�1�?����PO�}Eq�i�p�iJ@Q�=@�ݹ:t�o��{�d`5�����/W^�m��g���B~ h�  ����l  נ�6rߙ�����^�?r���   ���⤖��  �!��#�3\?��/  �ݝRG��\�9;6���}P6������K>��V̒=l��n)��p	 ����0n䯂���}   ���S*	 ��t%ͤ+@�����T�~��s����oL)�J� 0>��W�-  �*N�%x=�8ikfV^���3�,�=�,}�<Z��T�+'��\�;x�Y���=���`}�y�>0����/'ـ�!z9�pQ��v/ֶ�Ǜ����㗬��9r���}��D���ל���	{�y����0&�Q����W��y ����l��.�LVZ��C���*W��v����r���cGk�
^�Ja%k��S���D"j���2���RW/������ض1 ����
.bVW&�gr��U\�+���!���m ;+۞�&�6]�4R�/��Y�L�Ά`"�sl,Y/��x��|&Dv�_
Q*� V�NWYu�%��-�&D�(&��"  Wc��ZS���(�x� ,�!����!�L�AM�E�]}X�!��wB�o��-  �-���16���i���ю�z��� ���B��oB�0������v]���ȓ�����3�� +S�χ�=Q_�����˨�d��|)D>��k ��uȣ���Y[9̂�����! ^�!��r���j0Y+i��΍e(�ț� ���x��
��{��<6 R���پ�b��Y
C����+���������;���a ���,�o��bC�{�?���1 �(��¤ �V�������;�=��I��� ���EI���Z��)D����t=S ��] X��9K�= �.~�K[��Ŋ��,2��� p}>w<n�g h�
�t���R�u�G�1k���!��x���������� �L���|>D�0�Ǣ(Qc�� ����= �ۊ�Z0�^��c �
|�����L�%�d��q���(�WB� ��(	���� �J��8D�0�~$�Dsy�Ѿ!������j�^ ��mOa�8.�qce��s|%Dq~,X�u�������=T	���Q�M�ȣm�Y�%Y+�[�0|"DΞ�j�u�L6�(Qe��qw�V�э���ǂ���!j�K � �:�wQ�dÛ������R�
��C���X�u�`����\"j讀Dq21� �F>B[��[������]@K-���C�e�q�tWP�:W�۞X�z��,��t�p���P��Se����T���{dG��
KA���w�t3t��[ܘ�4^>�5ŉ�^�n�Eq�U��Ӎ��α�v�O6C�
�F%�+8eů��M����hk��w�欹񔈓����C��y訫���J�Is�����Po|��{�Ѿ)+~�W��N,�ů��޽���O��J�_�w��N8����x�?�=X��t�R�BM�8���VSyI5=ݫ�	-�� �ֶ��oV�����G������3��D��aEI��ZI5�݋����t��b��j��G����U���΃�C�������ق�в����b���}s����xkn��`5�����>��M�Ev�-�͇\��|�=� '�<ތ�Ǜ���<O�LM�n.f>Z�,~��>��㷾�����x8���<x�����h}��#g�ж��������d�1xwp�yJO�v�	TV����گ�.�=��N����oK_={?-����@/�~�,��m ��9r.�6K_=�7#�SS����Ao�"�,TW+I��gt���F�;S���QW/�|�$�q#��W�Ƞ(�)H�W�}u�Ry�#���᎞�ͦ�˜QQ�R_��J}�O���w�����F[zjl�dn�`$� =�+cy��x3������U�d�d����v��,&FA&'kF�Y22�1z�W!�����1H�Y0&Ӎ W&^�O�NW�����U����-�|��|&HW������"�q����� ��#�R�$����?�~���� �z'F��I���w�'&����se���l�̂L�����-�P���s��fH�`�M��#H[�`,,s]��T����*Jqã��ł�� )-|yč��G�^J5]���e�hk�l;4�O��� ���[�������.��������������xm�p�w�չ�Y��(s�a�9[0Z�f&^��&�ks�w�s�_F^���2΂d��RU� �s��O0_\읅�,���2t�f�~�'t�p{$`6���WĽU.D"j�=�d��}��}���S["NB�_MxQCA[����\	�6}7Y����K���K6���{���Z۔s�2 �L�b�3��T��ݹ����&'ks����ܓ�ЛϾ�}f��,�Dq&������s��ϼ��{������&'k�����Qw窭�_i�+x�6ڥ��f�{j)���ퟎƍ3ou�R�Y����徙�k����X�Z
m.Y+=Z��m3�L47�j�3o�=�!J
5s���(��A ��t)���N�]68�u< Ƞ��_�im>d ��z(���(��⤶�� �&�ۥ� ��  Vc�8�'��qo9 �t��i�ρdn��Of���O�RQP���h'������P֡���n ���č����k�K@�>����pH>z)-|��B��j���!j:�+������˧��t�������1����.`v�M�k�q#�$���N:�����-M5a10y����(�T��� X5 \�:� ?+�7#�?�*Y+-,s� ~�|\)뀀ap �drn�g��RN�X�er ��@ĕ���;��z��8ɱ�����	�- �
�bKc����kt�U]�䎚���hgu���|�_J{ �`p��o�p�T�U��p���/���Hϑ�H�$X ܬm3���ŉ�U'��뻩t��G9�}�)O������p�΃g���JO���\9�׫�����ڳ�!k����/��9R���^�%��C����T���;ji<�>�KY����;�J��ƶm .P��pT��
@HA��r��98V���b�v���YwaZ>�$oւ?-փ��ʹ|0�.��3���b駁�c��;?8E;���V�B�؀����|%\\s��%����e{o��Z�i�������^���s�Jx������B jh�\ �h�<��V��sh@:���.�ІYl��˂�`3hE.,P�2^����J��+�����p��
�ЊJd��x�*�@�7R��� �"�G="!�� �p����u�o��wV�m�g���~F��?����/�����}~����sо7� ���\,,k�J�T�6������Z�y�rBZ[D�>v�HQ�R��mq�������DD�-6+�V`���J�E�����\� 9!ߑ�`��6���ml�~ZM�Z�ȎV���g���������3?*u3���ctW����YQa�Cb�P�,B5�p0�m�cͺEt�{,��>s9f�^��`OG��]����2�Fk�9_�G�vd��	��)��=�1^Ų�Wl3{�����1��H)�e������9�هZ�]}�b���)b�C��es}�cVi~x���e
Z�)܃��39������C�(�+R����!�j����F�n���<?�p��l�8a�4xOb��������c�8&�UA�|	/l�8�8���3t�6�͏���v���� ����סy�wU��`� =��|M�Y?�'�A��&�@*�c~!�/{��),�>�=xr"	�qlF:��L&���=<5t�h.�#ᣭ���O�z�!�&`A�F�yK=�c<\GZ�� 4HG�0i�F녠uB"���<��c�Jeۈ�3!����O��q萞PiZ&�$M[���(G��e���ؤ���ã��O���5����'�gH~�����=��g�F|8�+�X�4�u���G�2����'��.��5[�OlB��$f4���`��mS�L�,y�t&V�#P�3{ ��763�7N���"��P��I�X��BgV�n�a:$:�FZ���'�7����f������z!�����KA�G��D#������ˑ`ڶs���&� ݱ��4�j��n�� ݷ�~s��F�pD�LE�q+wX;t,�i�y��Y��A�۩`p�m#�x�kS�c��@bVL��w?��C�.|n{.gBP�Tr��v1�T�;"��v����XSS��(4�Ύ�-T�� (C�*>�-
�8��&�;��f;�[Փ���`,�Y�#{�lQ�!��Q��ّ�t9����b��5�#%<0)-%	��yhKx2+���V��Z� �j�˱RQF_�8M���{N]���8�m��ps���L���'��y�Ҍ}��$A`��i��O�r1p0�%��茮�:;�e���K A��qObQI,F�؟�o��A�\�V�����p�g"F���zy�0���9"� �8X�o�v����ߕڄ��E �5�3�J�ص�Ou�SbVis�I���ص�Z���ڒ�X��r�(��w��l��r"�`]�\�B���Ija:�O\���/�*]�þR������|���ʑ@�����W�8f�lA���Xl��촻�K<�dq1+x�*U�;�'�Vnl`"_L�3�B����u�����M���'�!-�<;S�F�܊�bSgq� ���Xt�肦�a��RZ�Y_ި��ZRSGA��-:8����yw_}XW�Z���-k�g.U��|�7P�
&���$˳��+��~?7�k�bQ���g������~�Z�e����H�-p�7S�� 
�w"XK�`K%?�`Tr|p���"��\�a�?�٧ ��'u�cv�&��<LM�Ud��T���Ak��������'+7��XR`��[\�-0���e�AiW]�Dk���$u���0[?�-���L����X�ĚSK-�.%�9=j�3t^���(c�yM-��/�ao����\%�?�б �~���b][
tٵ�<qF�)�
�J�'QZY�����*pB�I4�޸�,������.Т�1���/
t�1-1������E�*��Cl/Ю©f�<,0�S�bf�^���[8Z$��@���kw�M<?�[`��)3)1� �U����:��/pR��XV`XE,/0���d���1>ѫ��i�z��*o�}&R{���$f�JV=5͉Ύ��Rl�/�N4.�U~Cm�N~��HPRS�?G��g�-���qvT{�G _�[ua�;���kco�9�Kw����n����E{d�j��C���,q����Y���cwY<$#�ؤ�m+�LL-�z� �y<{/7���[��X�?�-6(cO ?�XZ�M�������sb�[
�.����j|;d�!0lCIqZ�z�&��~�|7�A���A~��á@�� 417��}t ��,� X�6��lS)6v�G
��I:�).~��8R���#'��߶;9�'���U�$1nC�L��찦3�+b黙u�NJ�����8���X�?5�0��^��[B/+�0�Ur(��J��+Xr�H�����HZm&�#�p	�Y ����*���hM]��m���b�ݢ����G����s��z-�x��������� �J�"���Ћ�g�Ҝ �Aа��?��?6��c�Zx�$�t��{s
-R�E�24�?�{�l�-��1�3S�EJ��v6X]L�B^ ��]N��R�yN��62�����'R�p-�����n2�d�?Th|�h��3X������Rc8&��_,��;T�8�� �hΗv�(7I;�3Obn;��O�!����Lߍ*�E~wU,���n�MN1���Z��Y̖��tY;5�^�<Z�Ǩ�T#�bt�xfA�n�cq����"9GD*�^JL��HJ���4���V�-�܉��4*��u]�[
���,"ҏ�i!�r~L��_�����8 ]j�?x���<k+%w��Bk��=�u�ڤ��>%2Bۃ�Y�n<jBo������Κ�0M~�t>�#b/jZ�}���B��Q��#���6R$v�����k�R$c/:�~���(V�7;)��ߊ[̣0?F��;.�*ݪd������{A`w>~�i=D�c��������Y2�X�q~�r2��8@v=f�?��X��S�"X�j?��@$?�����x�(�k���c7��\�����>A�=fpM?9d?�׻{���)f�.⪝���3�������f,N;"��,N���X��*�"V���"��C��?���(2=���A��1�Ul���h�8Ao(5X�B�X�>S�j��s�!
l����GgGp��>�v;c���V�N1���-��K�S�=6PiN�fNq������,
�3SWx�ei����f'�*�r�rʹ̙�e�7���b�o���>_i��M�_��V�p�r�9��X�$�����B���t5�4#�B(E���3�������`����I�M�e��b6_����{~�f/��@��B��Y����E�4��޲�d�O�$���M�����ݖv�P����TR�oj~��+}��#���"�]1Υ_���nR���œ����^pQ2�7첾b��3�ba�\��uu2�~O�G�����5�^>v������m��?���mC;$eT��C񎋋��V��8�:��
���ʱlt��~e]�cC7dl���.�i����\w����/..F�Q5���œ��`�o���E����E�͛�ٽ-�o�z�"n��/��[�����ͳI���S��Dڢ��V�6��!��esq��AC���ڻ���OMk�y��{7`c0�ٺ���5C5�yiw��`ps�OC��f�X�5oQ�\_*m�f�)稹"���a2$O;�]C�A�;V.���c��iޢ�R5�X��t%�s����ȸ�; 5�����)��X|?����9&��wĽjdn�{��7��/����q]3Ɲ�}�[��yF~�Q0����x��U�� ���˘?����a�;���/yޫ�����6.��C}���&L��9�_�ս�w�o���W�^�;�^u�xoݖ��Q8����4��kW��'����:9>����Xp5H��ONtL��=��_�&�0��H"Q��|H���4!���]�'�!޹Eܢ���}=soϢ~	K�$���`"!]j�+{'e�M��D]��=�>c��xS��Y����X��7�7+�Me̯/���u�Q����i���Eg�9�g�RU��#'��ޑW\r�aS�/3�"/v
IgX���}ٻ���ʏr�r���_��<�6�Gʋ&���z%�Pl^d����㑭v�ʎو�w�[���Q��k�K�����IWˈ��`/�Y�X��9J"��_��V{��je�i��6�<�ZS��� �t���W�Bg��@5���..��X�eʡ��*�HRgkD^>�y裝"�9�+wQ4ABR������^�k3�>2�����x�C�l���f:��#gщ�s� ��ߜ��ȁ���+���A��˾�g�1K9Cܹ��:���T"!I������Hs�;���ue��9@#ChE5&!��'�2�����w*a/Q��I	�E������I�w�����?��v })B��GQ�n�h"]0��]Z֑���.}�&~x2��
eĞsF�n�+�b�e�i����0Ix�y��Aѕ���
[1�B�R$$����:�4E疳��#�4���y���ӈ�6o1O�V'��7]�H�.)/)�OwW./�g�l��£���"$d���}[���t���U~�MQԲ�$��~��c��S�M�a���ш=��diH��(N�+U�D����f"V�"�����.ƈ�#Ͼ�eH:�x��d!k 6�J�f9�GW�4����Kp��T��3��~��G�؀��,�zZ��澰؋7����v#� &�r+O�@Ud7͐�$�\�D�O��W_�Ew�ͻ�7��oD����y��,��Ƣ�cƙd	���U�u�:�#�h6]�R
�U~	V�՟R�V������/�:r�F¬�k?|Ī�r\�<.�^9����?��]Aʻ�iT;vg�PpyM���1��},�dY\e8��I��2�wjM��S/�p�1�\^�6$4�F��(:�\nۢ�2�}�Pm�X�'.����U�3��bq�nXK�i_BD�_H}�r;Y^�t�<���o��#gw��2q_�|�^�<��E�h���O�����R�-Ɖ���S�	!��z�1�+iH�1G���+<����~�;|�F�{�}v�;s�j�Q;�٩�;&f�}�������tL ���#��Ъ>;��z���?U˽�~������e��{K%��/:F�/<�n�2k�8�x��S-�5�`��ԗ�H�{���R�y�S�(w��ѥe
�	0���w�޻�U1��7V-Q�̶ꪸ�g�X��3V&�T[+)b����2���(���B��,��z����9���B`��!��o�ע(�W�RZ���m��%/V�&��|g��f��*[_��nn��M�M`�%��)��Z�K$�����F�� ��$r^�k�K,	u;w������X���;�L�eoI�6��y%����~����)���0"�zc�BH�<�kW�E\.�b��R>mٺ��<����͑Թ���a=2X���=/��_;	Ρ�e&o.����]��2!�嫈�"I������j�höR��͒\L�0�e������,)ýf�; ��E��0��<%�Q�Aø�x8�� �]eQL�;|���꼬z�W2
�H�z�_��
/K`J�O�O�Y�~j���>����d�v��%�ެ7�4{%��٥7Z��>����|��5^�\ױ���:��Z^;��U��s�)��#�|�.̡���R2��j����şBб���*cMvD�W^{�������m�D��0�,������#���?O����
����?z�{ȓ'�|����/�����/�����/�����/�����/�����/�����/�����/|�           [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://ntmva8mwibdy"
path="res://.godot/imported/3D Pipes 1.png-194d804dc5353bafb295bf8760f4a8f2.ctex"
metadata={
"vram_texture": false
}
           GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /������!"2�H�$�n윦���z�x����դ�<����q����F��Z��?&,
ScI_L �;����In#Y��0�p~��Z��m[��N����R,��#"� )���d��mG�������ڶ�$�ʹ���۶�=���mϬm۶mc�9��z��T��7�m+�}�����v��ح�m�m������$$P�����එ#���=�]��SnA�VhE��*JG�
&����^x��&�+���2ε�L2�@��		��S�2A�/E���d"?���Dh�+Z�@:�Gk�FbWd�\�C�Ӷg�g�k��Vo��<c{��4�;M�,5��ٜ2�Ζ�yO�S����qZ0��s���r?I��ѷE{�4�Ζ�i� xK�U��F�Z�y�SL�)���旵�V[�-�1Z�-�1���z�Q�>�tH�0��:[RGň6�=KVv�X�6�L;�N\���J���/0u���_��U��]���ǫ)�9��������!�&�?W�VfY�2���༏��2kSi����1!��z+�F�j=�R�O�{�
ۇ�P-�������\����y;�[ ���lm�F2K�ޱ|��S��d)é�r�BTZ)e�� ��֩A�2�����X�X'�e1߬���p��-�-f�E�ˊU	^�����T�ZT�m�*a|	׫�:V���G�r+�/�T��@U�N׼�h�+	*�*sN1e�,e���nbJL<����"g=O��AL�WO!��߈Q���,ɉ'���lzJ���Q����t��9�F���A��g�B-����G�f|��x��5�'+��O��y��������F��2�����R�q�):VtI���/ʎ�UfěĲr'�g�g����5�t�ۛ�F���S�j1p�)�JD̻�ZR���Pq�r/jt�/sO�C�u����i�y�K�(Q��7őA�2���R�ͥ+lgzJ~��,eA��.���k�eQ�,l'Ɨ�2�,eaS��S�ԟe)��x��ood�d)����h��ZZ��`z�պ��;�Cr�rpi&��՜�Pf��+���:w��b�DUeZ��ڡ��iA>IN>���܋�b�O<�A���)�R�4��8+��k�Jpey��.���7ryc�!��M�a���v_��/�����'��t5`=��~	`�����p\�u����*>:|ٻ@�G�����wƝ�����K5�NZal������LH�]I'�^���+@q(�q2q+�g�}�o�����S߈:�R�݉C������?�1�.��
�ڈL�Fb%ħA ����Q���2�͍J]_�� A��Fb�����ݏ�4o��'2��F�  ڹ���W�L |����YK5�-�E�n�K�|�ɭvD=��p!V3gS��`�p|r�l	F�4�1{�V'&����|pj� ߫'ş�pdT�7`&�
�1g�����@D�˅ �x?)~83+	p �3W�w��j"�� '�J��CM�+ �Ĝ��"���4� ����nΟ	�0C���q'�&5.��z@�S1l5Z��]�~L�L"�"�VS��8w.����H�B|���K(�}
r%Vk$f�����8�ڹ���R�dϝx/@�_�k'�8���E���r��D���K�z3�^���Vw��ZEl%~�Vc���R� �Xk[�3��B��Ğ�Y��A`_��fa��D{������ @ ��dg�������Mƚ�R�`���s����>x=�����	`��s���H���/ū�R�U�g�r���/����n�;�SSup`�S��6��u���⟦;Z�AN3�|�oh�9f�Pg�����^��g�t����x��)Oq�Q�My55jF����t9����,�z�Z�����2��#�)���"�u���}'�*�>�����ǯ[����82һ�n���0�<v�ݑa}.+n��'����W:4TY�����P�ר���Cȫۿ�Ϗ��?����Ӣ�K�|y�@suyo�<�����{��x}~�����~�AN]�q�9ޝ�GG�����[�L}~�`�f%4�R!1�no���������v!�G����Qw��m���"F!9�vٿü�|j�����*��{Ew[Á��������u.+�<���awͮ�ӓ�Q �:�Vd�5*��p�ioaE��,�LjP��	a�/�˰!{g:���3`=`]�2��y`�"��N�N�p���� ��3�Z��䏔��9"�ʞ l�zP�G�ߙj��V�>���n�/��׷�G��[���\��T��Ͷh���ag?1��O��6{s{����!�1�Y�����91Qry��=����y=�ٮh;�����[�tDV5�chȃ��v�G ��T/'XX���~Q�7��+[�e��Ti@j��)��9��J�hJV�#�jk�A�1�^6���=<ԧg�B�*o�߯.��/�>W[M���I�o?V���s��|yu�xt��]�].��Yyx�w���`��C���pH��tu�w�J��#Ef�Y݆v�f5�e��8��=�٢�e��W��M9J�u�}]釧7k���:�o�����Ç����ս�r3W���7k���e�������ϛk��Ϳ�_��lu�۹�g�w��~�ߗ�/��ݩ�-�->�I�͒���A�	���ߥζ,�}�3�UbY?�Ӓ�7q�Db����>~8�]
� ^n׹�[�o���Z-�ǫ�N;U���E4=eȢ�vk��Z�Y�j���k�j1�/eȢK��J�9|�,UX65]W����lQ-�"`�C�.~8ek�{Xy���d��<��Gf�ō�E�Ӗ�T� �g��Y�*��.͊e��"�]�d������h��ڠ����c�qV�ǷN��6�z���kD�6�L;�N\���Y�����
�O�ʨ1*]a�SN�=	fH�JN�9%'�S<C:��:`�s��~��jKEU�#i����$�K�TQD���G0H�=�� �d�-Q�H�4�5��L�r?����}��B+��,Q�yO�H�jD�4d�����0*�]�	~�ӎ�.�"����%
��d$"5zxA:�U��H���H%jس{���kW��)�	8J��v�}�rK�F�@�t)FXu����G'.X�8�KH;���[             [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://dv8hc3mbxgthr"
path="res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"
metadata={
"vram_texture": false
}
                extends Node3D

@export var previousPipe:Node3D
@export var pipeVariants:Array[String]
@export var worldBounds:Vector3
@export var pipeMaterial:StandardMaterial3D
@export var pipeCountToTriggerColorChange:int
var recursionLimit:int = 10

var recursions:int = 0
var pipeCount = 0

func _ready():
	$Timer.start()
	
func _pipeStep():
	# Choose variant randomly & instantiate it
	var variantIndex = randi() % (pipeVariants.size()-1)
	# If we have >1 recursion (problem solving 'mode'), unlock the U-turn pipe
	if (recursions > 0):
		variantIndex = randi() % (pipeVariants.size())
		
	var variantScene = load("res://" + pipeVariants[variantIndex])
	var instanced_pipe = variantScene.instantiate()
	add_child(instanced_pipe)
	
	# Connect pipe inlet to previous pipe outlet (position + rotation)
	instanced_pipe.global_transform = previousPipe.global_transform * \
								previousPipe.get_node('PipeOutlet').transform *\
								instanced_pipe.get_node('PipeInlet').transform.affine_inverse()
	
	# Rotate randomly from 0-270deg in 90deg increments
	instanced_pipe.rotate_object_local(Vector3(0,1,0), (randi() % 4) * 90 * (PI/180))
	
	# Validation - can I place this here? Otherwise, try again
	if (instanced_pipe.get_node('PipeOutlet').global_transform.origin.x < worldBounds.x && instanced_pipe.get_node('PipeOutlet').global_transform.origin.x > -worldBounds.x) && (instanced_pipe.get_node('PipeOutlet').global_transform.origin.y < worldBounds.y && instanced_pipe.get_node('PipeOutlet').global_transform.origin.y > -worldBounds.y) && (instanced_pipe.get_node('PipeOutlet').global_transform.origin.z < worldBounds.z && instanced_pipe.get_node('PipeOutlet').global_transform.origin.z > -worldBounds.z):
		previousPipe = instanced_pipe
		print("Placed pipe!")
		# reset so each 'stuck' situation can try to recur 10 times
		recursions = 0
		pipeCount += 1
		
		if (pipeCount > pipeCountToTriggerColorChange):
			pipeMaterial.set_albedo(Color(randf(),randf(),randf()))
			pipeCount=0
		$Timer.start()
		return 
	elif recursions < recursionLimit:
		print("Self-solving boundary issue...")
		instanced_pipe.queue_free()
		recursions+= 1
		return _pipeStep()
	else:
		print("Limit reached - no more placements possible")
		
	
func _on_timer_timeout():
	_pipeStep()
   RSRC                    StandardMaterial3D            ��������                                            n      resource_local_to_scene    resource_name    render_priority 
   next_pass    transparency    blend_mode 
   cull_mode    depth_draw_mode    no_depth_test    shading_mode    diffuse_mode    specular_mode    disable_ambient_light    vertex_color_use_as_albedo    vertex_color_is_srgb    albedo_color    albedo_texture    albedo_texture_force_srgb    albedo_texture_msdf 	   metallic    metallic_specular    metallic_texture    metallic_texture_channel 
   roughness    roughness_texture    roughness_texture_channel    emission_enabled 	   emission    emission_energy_multiplier    emission_operator    emission_on_uv2    emission_texture    normal_enabled    normal_scale    normal_texture    rim_enabled    rim 	   rim_tint    rim_texture    clearcoat_enabled 
   clearcoat    clearcoat_roughness    clearcoat_texture    anisotropy_enabled    anisotropy    anisotropy_flowmap    ao_enabled    ao_light_affect    ao_texture 
   ao_on_uv2    ao_texture_channel    heightmap_enabled    heightmap_scale    heightmap_deep_parallax    heightmap_flip_tangent    heightmap_flip_binormal    heightmap_texture    heightmap_flip_texture    subsurf_scatter_enabled    subsurf_scatter_strength    subsurf_scatter_skin_mode    subsurf_scatter_texture &   subsurf_scatter_transmittance_enabled $   subsurf_scatter_transmittance_color &   subsurf_scatter_transmittance_texture $   subsurf_scatter_transmittance_depth $   subsurf_scatter_transmittance_boost    backlight_enabled 
   backlight    backlight_texture    refraction_enabled    refraction_scale    refraction_texture    refraction_texture_channel    detail_enabled    detail_mask    detail_blend_mode    detail_uv_layer    detail_albedo    detail_normal 
   uv1_scale    uv1_offset    uv1_triplanar    uv1_triplanar_sharpness    uv1_world_triplanar 
   uv2_scale    uv2_offset    uv2_triplanar    uv2_triplanar_sharpness    uv2_world_triplanar    texture_filter    texture_repeat    disable_receive_shadows    shadow_to_opacity    billboard_mode    billboard_keep_scale    grow    grow_amount    fixed_size    use_point_size    point_size    use_particle_trails    proximity_fade_enabled    proximity_fade_distance    msdf_pixel_range    msdf_outline_size    distance_fade_mode    distance_fade_min_distance    distance_fade_max_distance    script        !   local://StandardMaterial3D_1v1ba �	         StandardMaterial3D    m      RSRC            RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name    lightmap_size_hint 	   material    custom_aabb    flip_faces    add_uv2    uv2_padding    top_radius    bottom_radius    height    radial_segments    rings    cap_top    cap_bottom    script    radius    is_hemisphere 	   _bundled    	   Material    res://pipe_mat.tres � ��b1      local://CylinderMesh_pm3r1 :         local://SphereMesh_rr1uf W         local://PackedScene_ssxbc r         CylinderMesh             SphereMesh             PackedScene          	         names "   
      PipeSegment A 
   transform    Node3D 
   CSGMesh3D    material_override    mesh    PipeOutlet 
   PipeInlet    CSGMesh3D2    CSGMesh3D3    	   variants            �?              �?              �?      ��         �?              �?              �?      �?                             �?              �?              �?       @                  �?              �?              �? 6�   @gû      node_count             nodes     >   ��������       ����                            ����                                       ����                           ����                      ����                              	   ����                               conn_count              conns               node_paths              editable_instances              version             RSRC            RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name    lightmap_size_hint 	   material    custom_aabb    flip_faces    add_uv2    uv2_padding    top_radius    bottom_radius    height    radial_segments    rings    cap_top    cap_bottom    script    radius    is_hemisphere 	   _bundled    	   Material    res://pipe_mat.tres � ��b1      local://CylinderMesh_pm3r1 :         local://SphereMesh_svo5l W         local://PackedScene_tcowu r         CylinderMesh             SphereMesh             PackedScene          	         names "         PipeSegment B 
   transform    Node3D 
   CSGMesh3D    material_override    mesh    CSGMesh3D2    PipeOutlet 
   PipeInlet    CSGMesh3D3    CSGMesh3D4    CSGMesh3D5    	   variants    	        �?              �?              �?      �?         �?               ?              �?       �                           1�;�  �?      ��1�;�              �?  �?           1�;�  �?      ��1�;�              �?   @             �?              �?              �?      ��                  �?              �?              �?   @              node_count             nodes     Z   ��������       ����                            ����                                       ����                                       ����                           ����                        	   ����                              
   ����                                       ����                               conn_count              conns               node_paths              editable_instances              version             RSRC      RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name    lightmap_size_hint 	   material    custom_aabb    flip_faces    add_uv2    uv2_padding    top_radius    bottom_radius    height    radial_segments    rings    cap_top    cap_bottom    script    radius    is_hemisphere 	   _bundled    	   Material    res://pipe_mat.tres � ��b1      local://CylinderMesh_pm3r1 :         local://SphereMesh_svo5l W         local://PackedScene_h6a3n r         CylinderMesh             SphereMesh             PackedScene          	         names "         PipeSegment B 
   transform    Node3D 
   CSGMesh3D    material_override    mesh    CSGMesh3D2    PipeOutlet 
   PipeInlet    CSGMesh3D3    CSGMesh3D4    CSGMesh3D5    CSGMesh3D6    CSGMesh3D7    	   variants    
        �?              �?              �?      �?                           1�;�  �?      ��1�;�              �?  �?  �?       1�;�  �?      ��1�;�              �?   @  ��         �?              �?              �?      ��                  �?              �?              �?   @             �?              �?              �?   @  �?         �?              �?              �?   @  ��          node_count    
         nodes     t   ��������       ����                            ����                                 ����                                       ����                           ����                        	   ����                                     
   ����                                       ����                                       ����      	                                 ����                               conn_count              conns               node_paths              editable_instances              version             RSRC            RSRC                    PackedScene            ��������                                                  PipeSegment A    resource_local_to_scene    resource_name 	   _bundled    script       Script    res://PipeSpawner.gd ��������	   Material    res://pipe_mat.tres � ��b1   PackedScene    res://pipe_segment_a.tscn ��Yq4Oh      local://PackedScene_ywj33 �         PackedScene          	         names "         World    script    previousPipe    pipeVariants    worldBounds    pipeMaterial    pipeCountToTriggerColorChange    Node3D    PipeSegment A    Timer    DirectionalLight3D 
   transform 	   Camera3D    _on_timer_timeout    timeout    	   variants    	                                   pipe_segment_a.tscn       pipe_segment_b.tscn       pipe_segment_c.tscn      �A  �A  �A            
                 �?               ?г]?    г]�   ?       A       *`?    �F�>      �?    �F��    *`?k+PA���?G�A      node_count             nodes     3   ��������       ����            @                                       ���                      	   	   ����                
   
   ����                           ����                   conn_count             conns                                      node_paths              editable_instances              version             RSRC   [remap]

path="res://.godot/exported/133200997/export-cf14e99bcd5cad797259b72ffd500df4-debug_menu.scn"
         [remap]

path="res://.godot/exported/133200997/export-7316f22d4e5e85c1b9ff65ef14bbb845-pipe_mat.res"
           [remap]

path="res://.godot/exported/133200997/export-9fc0d38e18a3e78ec305be26f33cb2b5-pipe_segment_a.scn"
     [remap]

path="res://.godot/exported/133200997/export-fd6044a12b650e8a41d372e75221ce59-pipe_segment_b.scn"
     [remap]

path="res://.godot/exported/133200997/export-1d41d32d38c479d92e53a333e24b136e-pipe_segment_c.scn"
     [remap]

path="res://.godot/exported/133200997/export-73d50b7f59085c9a9ce28353ee849bb1-World.scn"
              list=Array[Dictionary]([])
     <svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="124" height="124" rx="14" fill="#363d52" stroke="#212532" stroke-width="4"/><g transform="scale(.101) translate(122 122)"><g fill="#fff"><path d="M105 673v33q407 354 814 0v-33z"/><path fill="#478cbf" d="m105 673 152 14q12 1 15 14l4 67 132 10 8-61q2-11 15-15h162q13 4 15 15l8 61 132-10 4-67q3-13 15-14l152-14V427q30-39 56-81-35-59-83-108-43 20-82 47-40-37-88-64 7-51 8-102-59-28-123-42-26 43-46 89-49-7-98 0-20-46-46-89-64 14-123 42 1 51 8 102-48 27-88 64-39-27-82-47-48 49-83 108 26 42 56 81zm0 33v39c0 276 813 276 813 0v-39l-134 12-5 69q-2 10-14 13l-162 11q-12 0-16-11l-10-65H447l-10 65q-4 11-16 11l-162-11q-12-3-14-13l-5-69z"/><path d="M483 600c3 34 55 34 58 0v-86c-3-34-55-34-58 0z"/><circle cx="725" cy="526" r="90"/><circle cx="299" cy="526" r="90"/></g><g fill="#414042"><circle cx="307" cy="532" r="60"/><circle cx="717" cy="532" r="60"/></g></g></svg>
          
   ���k '   res://addons/debug_menu/debug_menu.tscn������x   res://icon.svg� ��b1   res://pipe_mat.tres��Yq4Oh   res://pipe_segment_a.tscn4��W�C   res://pipe_segment_b.tscn���X?�    res://pipe_segment_c.tscn����J"   res://World.tscn��W:ݶ�O   res://3D Pipes 1.icon.png��4�>c%   res://3D Pipes 1.apple-touch-icon.pngb����7   res://3D Pipes 1.png               ECFG      application/config/name         3D Pipes   application/run/main_scene         res://World.tscn   application/config/features(   "         4.1    GL Compatibility       application/config/icon         res://icon.svg     autoload/DebugMenu0      (   *res://addons/debug_menu/debug_menu.tscn   editor_plugins/enabled0   "      #   res://addons/debug_menu/plugin.cfg  #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility        