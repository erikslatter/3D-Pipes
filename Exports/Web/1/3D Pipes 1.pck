GDPC                �                                                                         \   res://.godot/exported/133200997/export-1d41d32d38c479d92e53a333e24b136e-pipe_segment_c.scn  `�      �      ږ��������5�՜    T   res://.godot/exported/133200997/export-7316f22d4e5e85c1b9ff65ef14bbb845-pipe_mat.res �      $
      �r�і|��'�ÈJ�5    T   res://.godot/exported/133200997/export-73d50b7f59085c9a9ce28353ee849bb1-World.scn    �      }      �ge�5��jJ��    \   res://.godot/exported/133200997/export-9fc0d38e18a3e78ec305be26f33cb2b5-pipe_segment_a.scn  P�            �)t����*e�    X   res://.godot/exported/133200997/export-cf14e99bcd5cad797259b72ffd500df4-debug_menu.scn  �O      &       �A��]���+d��d�    \   res://.godot/exported/133200997/export-fd6044a12b650e8a41d372e75221ce59-pipe_segment_b.scn  `�      �      O!�a$Փ�7��>m    ,   res://.godot/global_script_class_cache.cfg  @�             ��Р�8���8~$}P�    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex�s      �      �̛�*$q�*�́        res://.godot/uid_cache.bin   �      �       ���3s���qX"��[��       res://PipeSpawner.gdP�      �      u�k=zE�K�-")��       res://World.tscn.remap  а      b       cI��'��O|+��@Ω    (   res://addons/debug_menu/debug_menu.gd           �O      ��!�z���@\��y�    0   res://addons/debug_menu/debug_menu.tscn.remap   ��      g       �!�'b�2/��d�K    $   res://addons/debug_menu/plugin.gd    p      �      �pp�i]��M5����       res://icon.svg  `�      �      C��=U���^Qu��U3       res://icon.svg.import   ��      �       )5���n�������o�       res://pipe_mat.tres.remap   �      e       *��q�N������         res://pipe_segment_a.tscn.remap ��      k       �1��d���p�мEl        res://pipe_segment_b.tscn.remap �      k       #�wZ!�K>�
��o
        res://pipe_segment_c.tscn.remap `�      k       A����[��g��B�       res://project.binary �            �i}��,�����M+        extends Control

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
       GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /������!"2�H�$�n윦���z�x����դ�<����q����F��Z��?&,
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
             ���k '   res://addons/debug_menu/debug_menu.tscn������x   res://icon.svg� ��b1   res://pipe_mat.tres��Yq4Oh   res://pipe_segment_a.tscn4��W�C   res://pipe_segment_b.tscn���X?�    res://pipe_segment_c.tscn����J"   res://World.tscn     ECFG      application/config/name         3D Pipes   application/run/main_scene         res://World.tscn   application/config/features(   "         4.1    GL Compatibility       application/config/icon         res://icon.svg     autoload/DebugMenu0      (   *res://addons/debug_menu/debug_menu.tscn   editor_plugins/enabled0   "      #   res://addons/debug_menu/plugin.cfg  #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility        